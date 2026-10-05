import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/error_handler.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_error_view.dart';
import '../../../shared/widgets/app_list.dart';
import '../../../shared/widgets/app_loader.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/status_badge.dart';
import '../domain/message_rules.dart';
import 'messaging_providers.dart';
import '../../../shared/widgets/guest_views.dart';

class InboxScreen extends ConsumerWidget {
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(authStateProvider).asData?.value == null) return const GuestChatsView();
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
            return const AppEmptyState(icon: Icons.chat_bubble_outline, title: 'No messages yet', message: 'Conversations for your jobs, projects, and company will appear here.');
          }
          return ListView.separated(
            itemCount: rows.length,
            separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
            itemBuilder: (context, index) {
              final conversation = rows[index];
              final palette = context.palette;
              return AppListRow(
                leading: AppAvatar(name: conversation.title),
                title: conversation.title,
                subtitle: conversation.latestBody.isEmpty ? statusLabel(conversation.contextType) : conversation.latestBody,
                trailing: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (conversation.latestAt != null)
                      Text(formatMessageTime(conversation.latestAt!), style: AppTextStyles.caption.copyWith(color: palette.textMuted)),
                    if (conversation.unread) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Icon(Icons.circle, size: 10, color: palette.link, semanticLabel: 'Unread'),
                    ],
                  ],
                ),
                onTap: () => context.push('/messages/${conversation.id}'),
              );
            },
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
                            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                            padding: const EdgeInsets.all(AppSpacing.md),
                            children: [
                              for (final message in _messages)
                                _Bubble(message: message, mine: message.senderProfileId == userId),
                            ],
                          ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: context.palette.surface,
              border: Border(top: BorderSide(color: context.palette.line)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(child: AppTextField(label: 'Message', controller: _body, textInputAction: TextInputAction.send)),
                    const SizedBox(width: AppSpacing.xs),
                    FilledButton(
                      style: FilledButton.styleFrom(minimumSize: const Size(72, AppSpacing.buttonHeight)),
                      onPressed: _sending ? null : _send,
                      child: _sending
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4))
                          : const Text('Send'),
                    ),
                  ],
                ),
              ),
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

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.mine});

  final MessageRecord message;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    const radius = Radius.circular(AppSpacing.radiusLg);
    const tail = Radius.circular(4);
    final fg = mine ? AppColors.ink : palette.text;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.xs),
        padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.xs, AppSpacing.sm, AppSpacing.xs),
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
        decoration: BoxDecoration(
          color: mine ? AppColors.yellow : palette.surface,
          border: mine ? null : Border.all(color: palette.line),
          borderRadius: BorderRadius.only(
            topLeft: radius,
            topRight: radius,
            bottomLeft: mine ? radius : tail,
            bottomRight: mine ? tail : radius,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!mine)
              Text(
                message.senderName.isEmpty ? 'Participant' : message.senderName,
                style: AppTextStyles.caption.copyWith(color: palette.link, fontWeight: FontWeight.w700),
              ),
            Text(message.body, style: AppTextStyles.body.copyWith(color: fg)),
            const SizedBox(height: 2),
            Text(
              formatMessageTime(message.createdAt),
              style: AppTextStyles.caption.copyWith(color: mine ? AppColors.ink.withValues(alpha: 0.65) : palette.textMuted, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
