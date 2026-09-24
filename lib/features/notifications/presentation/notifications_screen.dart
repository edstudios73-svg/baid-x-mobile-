import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/errors/error_handler.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/providers/app_providers.dart';
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
            return const AppEmptyState(title: 'No notifications', message: "You're all caught up.");
          }
          return ListView(
            children: [
              for (final notice in rows)
                ListTile(
                  title: Text(notice.title, style: notice.isUnread ? AppTextStyles.label : AppTextStyles.body),
                  subtitle: Text('${notice.body}\n${formatMessageTime(notice.createdAt)}'),
                  isThreeLine: true,
                  onTap: () => _open(context, ref, notice),
                ),
            ],
          );
        },
      ),
    );
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
