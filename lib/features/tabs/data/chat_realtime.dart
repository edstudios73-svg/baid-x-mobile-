import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';
import '../../../shared/providers/app_providers.dart';
import '../../account/presentation/extra_screens.dart' show notificationsProvider;
import 'secure_chat.dart';
import 'tabs_data.dart';

/// True while the realtime channel is connected; the open thread polls only when it is not.
final chatRealtimeUp = ValueNotifier<bool>(false);

/// One realtime channel per signed-in member, for every role (website js/chat.js
/// startRealtime): a new message refreshes the chat list and that conversation
/// within a second; a new notification refreshes the bell. Row-level security
/// limits the stream to conversations the member is part of. Also makes sure
/// the member has a chat key, so messages to them are always encrypted.
final chatRealtimeProvider = Provider<void>((ref) {
  final user = ref.watch(authStateProvider).asData?.value;
  final client = SupabaseConfig.client;
  if (user == null || client == null) return;
  SecureChat.instance.ensureKeysQuietly().catchError((Object _) {}); // a key is retried on the next sign-in or chat open
  final channel = client
      .channel('app-rt-${user.id}')
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'messages',
        callback: (p) {
          ref.invalidate(conversationsProvider);
          final conv = p.newRecord['conversation_id'];
          if (conv is String) ref.invalidate(chatThreadProvider(conv));
        },
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'notifications',
        filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'user_id', value: user.id),
        callback: (_) => ref.invalidate(notificationsProvider),
      )
      .subscribe((status, _) => chatRealtimeUp.value = status == RealtimeSubscribeStatus.subscribed);
  ref.onDispose(() {
    chatRealtimeUp.value = false;
    client.removeChannel(channel);
  });
});
