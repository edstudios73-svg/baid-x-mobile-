import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';
import '../../../core/errors/app_exception.dart';
import '../domain/message_rules.dart';

abstract class NotificationRepository {
  Future<List<NotificationRecord>> list(String userId);
  Future<int> unreadCount(String userId);
  Future<void> markRead({required String notificationId, required String userId});
  Stream<NotificationRecord> watchNew(String userId);
}

class SupabaseNotificationRepository implements NotificationRepository {
  SupabaseClient get _client {
    final client = SupabaseConfig.client;
    if (client == null) {
      throw const ConfigurationException('BAID X is not connected yet. Add the Supabase URL and publishable key to .env.');
    }
    return client;
  }

  @override
  Future<List<NotificationRecord>> list(String userId) async {
    final rows = await _client.from('notifications').select('id, recipient_profile_id, kind, title, body, context_type, context_id, read_at, created_at').eq('recipient_profile_id', userId).order('created_at', ascending: false).limit(30);
    return [for (final row in rows as List) _notice(Map<String, dynamic>.from(row as Map))];
  }

  @override
  Future<int> unreadCount(String userId) async {
    final rows = await _client.from('notifications').select('id').eq('recipient_profile_id', userId).isFilter('read_at', null).limit(20);
    return (rows as List).length;
  }

  @override
  Future<void> markRead({required String notificationId, required String userId}) {
    return _client.from('notifications').update({'read_at': DateTime.now().toUtc().toIso8601String()}).eq('id', notificationId).eq('recipient_profile_id', userId);
  }

  @override
  Stream<NotificationRecord> watchNew(String userId) {
    final controller = StreamController<NotificationRecord>();
    final channel = _client.channel('notifications-$userId');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'notifications',
      filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'recipient_profile_id', value: userId),
      callback: (payload) => controller.add(_notice(payload.newRecord)),
    ).subscribe();
    controller.onCancel = () => _client.removeChannel(channel);
    return controller.stream;
  }

  NotificationRecord _notice(Map<String, dynamic> row) {
    return NotificationRecord(
      id: '${row['id']}',
      recipientProfileId: '${row['recipient_profile_id']}',
      kind: '${row['kind']}',
      title: '${row['title'] ?? ''}',
      body: '${row['body'] ?? ''}',
      contextType: '${row['context_type']}',
      contextId: '${row['context_id']}',
      createdAt: DateTime.tryParse('${row['created_at']}') ?? DateTime.now().toUtc(),
      readAt: DateTime.tryParse('${row['read_at'] ?? ''}'),
    );
  }
}
