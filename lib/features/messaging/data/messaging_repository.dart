import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';
import '../../../core/errors/app_exception.dart';
import '../domain/message_rules.dart';

abstract class MessagingRepository {
  Future<List<ConversationSummary>> conversations(String userId);
  Future<List<MessageRecord>> messages(String conversationId);
  Future<String> open({required String contextType, required String contextId});
  Future<void> send({required String conversationId, required String userId, required String body});
  Future<void> markRead({required String conversationId, required String userId});
  Stream<MessageRecord> watchMessages(String conversationId);
}

class SupabaseMessagingRepository implements MessagingRepository {
  SupabaseClient get _client {
    final client = SupabaseConfig.client;
    if (client == null) {
      throw const ConfigurationException('BAID X is not connected yet. Add the Supabase URL and publishable key to .env.');
    }
    return client;
  }

  @override
  Future<List<ConversationSummary>> conversations(String userId) async {
    final rows = await _client.from('conversations').select('id, context_type, context_id, created_at').order('created_at', ascending: false).limit(20);
    final conversations = [for (final row in rows as List) Map<String, dynamic>.from(row as Map)];
    if (conversations.isEmpty) return const [];
    final ids = [for (final row in conversations) '${row['id']}'];
    final memberRows = await _client.from('conversation_members').select('conversation_id, profile_id, last_read_at').inFilter('conversation_id', ids);
    final messageRows = await _client.from('messages').select('id, conversation_id, sender_profile_id, body, created_at').inFilter('conversation_id', ids).order('created_at', ascending: false).limit(100);
    final titles = await _titles(conversations);
    final myRead = <String, DateTime?>{};
    for (final row in memberRows as List) {
      final map = Map<String, dynamic>.from(row as Map);
      if ('${map['profile_id']}' != userId) continue;
      myRead['${map['conversation_id']}'] = DateTime.tryParse('${map['last_read_at'] ?? ''}');
    }
    final latest = <String, Map<String, dynamic>>{};
    for (final row in messageRows as List) {
      final map = Map<String, dynamic>.from(row as Map);
      latest.putIfAbsent('${map['conversation_id']}', () => map);
    }
    return [
      for (final row in conversations)
        ConversationSummary(
          id: '${row['id']}',
          contextType: '${row['context_type']}',
          contextId: '${row['context_id']}',
          createdAt: DateTime.tryParse('${row['created_at']}') ?? DateTime.now().toUtc(),
          title: conversationTitle('${row['context_type']}', titles['${row['context_type']}:${row['context_id']}']),
          latestBody: '${latest['${row['id']}']?['body'] ?? ''}',
          latestAt: DateTime.tryParse('${latest['${row['id']}']?['created_at'] ?? ''}'),
          unread: isConversationUnread(
            latestSenderId: latest['${row['id']}'] == null ? null : '${latest['${row['id']}']!['sender_profile_id']}',
            latestAt: DateTime.tryParse('${latest['${row['id']}']?['created_at'] ?? ''}'),
            lastReadAt: myRead['${row['id']}'],
            userId: userId,
          ),
        ),
    ];
  }

  Future<Map<String, String>> _titles(List<Map<String, dynamic>> conversations) async {
    final titles = <String, String>{};
    Future<void> load(String context, String table, String column) async {
      final ids = [for (final row in conversations) if ('${row['context_type']}' == context) '${row['context_id']}'];
      if (ids.isEmpty) return;
      try {
        final rows = await _client.from(table).select('id, $column').inFilter('id', ids);
        for (final row in rows as List) {
          final map = Map<String, dynamic>.from(row as Map);
          titles['$context:${map['id']}'] = '${map[column] ?? ''}';
        }
      } catch (_) {}
    }

    await load('project', 'projects', 'title');
    await load('company', 'companies', 'name');
    final applicationIds = [for (final row in conversations) if ('${row['context_type']}' == 'job_application') '${row['context_id']}'];
    if (applicationIds.isEmpty) return titles;
    try {
      final rows = await _client.from('job_applications').select('id, jobs(title)').inFilter('id', applicationIds);
      for (final row in rows as List) {
        final map = Map<String, dynamic>.from(row as Map);
        final job = map['jobs'];
        titles['job_application:${map['id']}'] = job is Map ? '${job['title'] ?? ''}' : '';
      }
    } catch (_) {}
    return titles;
  }

  @override
  Future<List<MessageRecord>> messages(String conversationId) async {
    final rows = await _client.from('messages').select('id, conversation_id, sender_profile_id, body, created_at').eq('conversation_id', conversationId).order('created_at').limit(50);
    final messages = [for (final row in rows as List) _message(Map<String, dynamic>.from(row as Map))];
    if (messages.isEmpty) return messages;
    final names = <String, String>{};
    try {
      final profiles = await _client.from('profiles').select('id, display_name').inFilter('id', {for (final message in messages) message.senderProfileId}.toList());
      for (final row in profiles as List) {
        final map = Map<String, dynamic>.from(row as Map);
        names['${map['id']}'] = '${map['display_name'] ?? ''}';
      }
    } catch (_) {}
    return [for (final message in messages) message.named(names[message.senderProfileId] ?? '')];
  }

  @override
  Future<String> open({required String contextType, required String contextId}) async {
    final call = openConversationCall(contextType);
    if (call == null) throw const AuthFlowException("You don't have access to this conversation.");
    return '${await _client.rpc(call.rpc, params: {call.parameter: contextId})}';
  }

  @override
  Future<void> send({required String conversationId, required String userId, required String body}) {
    final problem = validateMessageBody(body);
    if (problem != null) throw AuthFlowException(problem);
    return _client.from('messages').insert({'conversation_id': conversationId, 'sender_profile_id': userId, 'body': body.trim()});
  }

  @override
  Future<void> markRead({required String conversationId, required String userId}) {
    return _client.from('conversation_members').update({'last_read_at': DateTime.now().toUtc().toIso8601String()}).eq('conversation_id', conversationId).eq('profile_id', userId);
  }

  @override
  Stream<MessageRecord> watchMessages(String conversationId) {
    final controller = StreamController<MessageRecord>();
    final channel = _client.channel('messages-$conversationId');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'messages',
      filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'conversation_id', value: conversationId),
      callback: (payload) => controller.add(_message(payload.newRecord)),
    ).subscribe();
    controller.onCancel = () => _client.removeChannel(channel);
    return controller.stream;
  }

  MessageRecord _message(Map<String, dynamic> row) {
    return MessageRecord(
      id: '${row['id']}',
      conversationId: '${row['conversation_id']}',
      senderProfileId: '${row['sender_profile_id']}',
      body: '${row['body'] ?? ''}',
      createdAt: DateTime.tryParse('${row['created_at']}') ?? DateTime.now().toUtc(),
    );
  }
}
