import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/errors/error_handler.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_error_view.dart';
import '../../../shared/widgets/app_loader.dart';
import '../../messaging/domain/message_rules.dart';
import '../../messaging/presentation/messaging_providers.dart';
import '../../messaging/presentation/messaging_screens.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(notificationRealtimeProvider);
    final notices = ref.watch(notificationListProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: notices.when(
        loading: () => const AppLoader(message: 'Loading notifications'),
        error: (error, _) => AppErrorView(
          message: ErrorHandler.toAppException(error).message,
          onRetry: () => ref.invalidate(notificationListProvider),
        ),
        data: (rows) {
          if (rows.isEmpty) {
            return const AppEmptyState(icon: Icons.notifications_none, title: 'No notifications', message: "You're all caught up.");
          }
          return ListView.separated(
            itemCount: rows.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final notice = rows[index];
              final palette = context.palette;
              return Material(
                color: notice.isUnread ? palette.infoBg : Colors.transparent,
                child: InkWell(
                  onTap: () => _open(context, ref, notice),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppAvatar.icon(_iconFor(notice.kind), size: 40),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                notice.title,
                                style: (notice.isUnread ? AppTextStyles.label : AppTextStyles.body).copyWith(color: palette.text),
                              ),
                              if (notice.body.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  notice.body,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.caption.copyWith(color: palette.textMuted),
                                ),
                              ],
                              const SizedBox(height: AppSpacing.xxs),
                              Text(formatMessageTime(notice.createdAt), style: AppTextStyles.caption.copyWith(color: palette.textMuted, fontSize: 11)),
                            ],
                          ),
                        ),
                        if (notice.isUnread)
                          Padding(
                            padding: const EdgeInsets.only(left: AppSpacing.xs, top: 6),
                            child: Icon(Icons.circle, size: 10, color: palette.link, semanticLabel: 'Unread'),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  IconData _iconFor(String kind) {
    if (kind.startsWith('company_access')) return Icons.key_outlined;
    if (kind.startsWith('project')) return Icons.account_tree_outlined;
    if (kind.contains('application') || kind.contains('job')) return Icons.work_outline;
    if (kind.contains('message')) return Icons.chat_bubble_outline;
    if (kind.contains('verif')) return Icons.verified_user_outlined;
    return Icons.notifications_none;
  }

  Future<void> _open(BuildContext context, WidgetRef ref, NotificationRecord notice) async {
    final user = ref.read(authStateProvider).asData?.value;
    if (user != null && notice.isUnread) {
      await ref.read(notificationRepositoryProvider).markRead(notificationId: notice.id, userId: user.id);
      ref.invalidate(notificationListProvider);
      ref.invalidate(unreadNotificationCountProvider);
    }
    if (!context.mounted) return;
    final type = ref.read(accountProfileProvider).asData?.value?.accountType;
    if (notice.kind == 'project_member_added') {
      context.push('/projects/${notice.contextId}');
      return;
    }
    if (notice.kind == 'company_access_requested' || notice.kind == 'company_access_approved' || notice.kind == 'company_access_rejected') {
      context.go(type == 'company' ? AppRoutes.team : AppRoutes.companyAccess);
      return;
    }
    await openContextConversation(ref, context, contextType: notice.contextType, contextId: notice.contextId);
  }
}
