import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/supabase_config.dart';
import '../../../core/errors/app_exception.dart';
import '../../../shared/providers/app_providers.dart';
import '../data/messaging_repository.dart';
import '../data/notification_repository.dart';
import '../domain/message_rules.dart';

final messagingRepositoryProvider = Provider<MessagingRepository>((ref) => SupabaseMessagingRepository());
final notificationRepositoryProvider = Provider<NotificationRepository>((ref) => SupabaseNotificationRepository());

final conversationListProvider = FutureProvider.autoDispose<List<ConversationSummary>>((ref) async {
  final user = ref.watch(authStateProvider).asData?.value;
  if (user == null) throw const AuthFlowException('Sign in again to see your messages.');
  return ref.watch(messagingRepositoryProvider).conversations(user.id);
});

final conversationMessagesProvider = FutureProvider.autoDispose.family<List<MessageRecord>, String>((ref, id) {
  return ref.watch(messagingRepositoryProvider).messages(id);
});

final notificationListProvider = FutureProvider.autoDispose<List<NotificationRecord>>((ref) async {
  final user = ref.watch(authStateProvider).asData?.value;
  if (user == null) throw const AuthFlowException('Sign in again to see your notifications.');
  return ref.watch(notificationRepositoryProvider).list(user.id);
});

final unreadNotificationCountProvider = FutureProvider<int>((ref) async {
  final user = ref.watch(authStateProvider).asData?.value;
  if (user == null || SupabaseConfig.client == null) return 0;
  return ref.watch(notificationRepositoryProvider).unreadCount(user.id);
});

final notificationRealtimeProvider = Provider<void>((ref) {
  final user = ref.watch(authStateProvider).asData?.value;
  if (user == null || SupabaseConfig.client == null) return;
  final subscription = ref.watch(notificationRepositoryProvider).watchNew(user.id).listen((_) {
    ref.invalidate(unreadNotificationCountProvider);
    ref.invalidate(notificationListProvider);
  });
  ref.onDispose(subscription.cancel);
});
