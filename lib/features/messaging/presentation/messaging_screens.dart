import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/error_handler.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_error_view.dart';
import '../../../shared/widgets/app_loader.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../domain/message_rules.dart';
import 'messaging_providers.dart';

class InboxScreen extends ConsumerWidget {
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversations = ref.watch(conversationListProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: conversations.when(
        loading: () => const AppLoader(message: 'Loading messages'),
        error: (error, _) => AppErrorView(
          message: ErrorHandler.toAppException(error).message,
          onRetry: () => ref.invalidate(conversationListProvider),
        ),
        data: (rows) {
          if (rows.isEmpty) {
            return const AppEmptyState(title: 'No messages yet', message: 'Conversations for your jobs, projects, and company will appear here.');
          }
          return ListView(
            children: [
              for (final conversation in rows)
                ListTile(
                  title: Text(conversation.title),
                  subtitle: Text(conversation.latestBody.isEmpty ? conversation.contextType.replaceAll('_', ' ') : conversation.latestBody),
                  trailing: conversation.unread ? const Icon(Icons.circle, size: 12, color: AppColors.blue) : Text(conversation.latestAt == null ? '' : formatMessageTime(conversation.latestAt!)),
                  onTap: () => context.push('/messages/${conversation.id}'),
                ),
            ],
          );
        },
      ),
    );
  }
}

class ConversationScreen extends ConsumerStatefulWidget {
  const ConversationScreen({required this.id, super.key});

  final String id;

  @override
  ConsumerState<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends ConsumerState<ConversationScreen> {
  final _body = TextEditingController();
  final _scroll = ScrollController();
  final _seen = <String>{};
  var _messages = <MessageRecord>[];
  var _loading = true;
  var _sending = false;
  String? _error;
  StreamSubscription<MessageRecord>? _live;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  @override
  void dispose() {
    _live?.cancel();
    _body.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final user = ref.read(authStateProvider).asData?.value;
    try {
      final rows = await ref.read(messagingRepositoryProvider).messages(widget.id);
      if (user != null) {
        await ref.read(messagingRepositoryProvider).markRead(conversationId: widget.id, userId: user.id);
        ref.invalidate(conversationListProvider);
      }
      _live ??= ref.read(messagingRepositoryProvider).watchMessages(widget.id).listen(_add);
      if (!mounted) return;
      setState(() {
        _messages = rows;
        _seen.addAll(rows.map((message) => message.id));
        _loading = false;
      });
      _jump();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = ErrorHandler.toAppException(error).message;
      });
    }
  }

  void _add(MessageRecord message) {
    if (!_seen.add(message.id)) return;
    setState(() => _messages = [..._messages, message]);
    _jump();
  }

  void _jump() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(authStateProvider).asData?.value?.id;
    return Scaffold(
      appBar: AppBar(title: const Text('Conversation')),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const AppLoader(message: 'Loading conversation')
                : _error != null
                    ? AppErrorView(message: _error!, onRetry: () {
                        setState(() {
                          _loading = true;
                          _error = null;
                        });
                        _load();
                      })
                    : _messages.isEmpty
                        ? const AppEmptyState(title: 'No messages yet', message: 'Send the first message about this work.')
                        : ListView(
                            controller: _scroll,
                            padding: const EdgeInsets.all(AppSpacing.md),
                            children: [
                              for (final message in _messages)
                                Align(
                                  alignment: message.senderProfileId == userId ? Alignment.centerRight : Alignment.centerLeft,
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                                    padding: const EdgeInsets.all(AppSpacing.sm),
                                    constraints: const BoxConstraints(maxWidth: 280),
                                    color: message.senderProfileId == userId ? AppColors.yellow : AppColors.blue.withValues(alpha: 0.08),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(message.senderProfileId == userId ? 'You' : (message.senderName.isEmpty ? 'Participant' : message.senderName), style: AppTextStyles.label),
                                        Text(message.body),
                                        Text(formatMessageTime(message.createdAt), style: AppTextStyles.bodyMuted),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Expanded(child: AppTextField(label: 'Message', controller: _body)),
                const SizedBox(width: AppSpacing.sm),
                AppButton(label: 'Send', isLoading: _sending, onPressed: _send),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _send() async {
    final problem = validateMessageBody(_body.text);
    if (problem != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(problem)));
      return;
    }
    final user = ref.read(authStateProvider).asData?.value;
    if (user == null) return;
    setState(() => _sending = true);
    try {
      await ref.read(messagingRepositoryProvider).send(conversationId: widget.id, userId: user.id, body: _body.text);
      _body.clear();
      ref.invalidate(conversationListProvider);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ErrorHandler.toAppException(error).message)));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }
}

Future<void> openContextConversation(WidgetRef ref, BuildContext context, {required String contextType, required String contextId}) async {
  try {
    final id = await ref.read(messagingRepositoryProvider).open(contextType: contextType, contextId: contextId);
    ref.invalidate(conversationListProvider);
    if (context.mounted) context.push('/messages/$id');
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ErrorHandler.toAppException(error).message)));
    }
  }
}
