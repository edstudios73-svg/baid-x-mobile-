import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:baid_x_mobile/features/auth/domain/auth_user.dart';
import 'package:baid_x_mobile/features/messaging/data/messaging_repository.dart';
import 'package:baid_x_mobile/features/messaging/data/notification_repository.dart';
import 'package:baid_x_mobile/features/messaging/domain/message_rules.dart';
import 'package:baid_x_mobile/features/messaging/presentation/messaging_providers.dart';
import 'package:baid_x_mobile/features/messaging/presentation/messaging_screens.dart';
import 'package:baid_x_mobile/features/notifications/presentation/notifications_screen.dart';
import 'package:baid_x_mobile/shared/providers/app_providers.dart';

class _Messages implements MessagingRepository {
  _Messages(this.thread);

  final List<MessageRecord> thread;
  String? sent;

  @override
  Future<List<ConversationSummary>> conversations(String userId) async => const [];

  @override
  Future<List<MessageRecord>> messages(String conversationId) async => thread;

  @override
  Future<String> open({required String contextType, required String contextId}) async => 'conversation-1';

  @override
  Future<void> send({required String conversationId, required String userId, required String body}) async {
    sent = body.trim();
  }

  @override
  Future<void> markRead({required String conversationId, required String userId}) async {}

  @override
  Stream<MessageRecord> watchMessages(String conversationId) => const Stream.empty();
}

class _Notices implements NotificationRepository {
  @override
  Future<List<NotificationRecord>> list(String userId) async => const [];

  @override
  Future<int> unreadCount(String userId) async => 0;

  @override
  Future<void> markRead({required String notificationId, required String userId}) async {}

  @override
  Stream<NotificationRecord> watchNew(String userId) => const Stream.empty();
}

void main() {
  const user = AuthUser(id: 'user-1', email: 'a@baidx.test', emailConfirmed: true);

  Widget frame({required Widget child, required List<dynamic> overrides}) {
    return ProviderScope(
      overrides: [
        authStateProvider.overrideWith((ref) => Stream.value(user)),
        for (final override in overrides) override,
      ],
      child: MaterialApp(home: child),
    );
  }

  testWidgets('inbox explains when there are no conversations', (tester) async {
    await tester.pumpWidget(frame(
      child: const InboxScreen(),
      overrides: [conversationListProvider.overrideWith((ref) async => const [])],
    ));
    await tester.pumpAndSettle();
    expect(find.text('No messages yet'), findsOneWidget);
  });

  testWidgets('inbox shows a real conversation', (tester) async {
    await tester.pumpWidget(frame(
      child: const InboxScreen(),
      overrides: [
        conversationListProvider.overrideWith((ref) async => [
          ConversationSummary(
            id: 'c1',
            contextType: 'project',
            contextId: 'p1',
            createdAt: DateTime.utc(2026, 1, 1),
            title: 'Site works',
            latestBody: 'Cement arrived',
            unread: true,
          ),
        ]),
      ],
    ));
    await tester.pumpAndSettle();
    expect(find.text('Site works'), findsOneWidget);
    expect(find.text('Cement arrived'), findsOneWidget);
  });

  testWidgets('a conversation can be empty', (tester) async {
    await tester.pumpWidget(frame(
      child: const ConversationScreen(id: 'c1'),
      overrides: [messagingRepositoryProvider.overrideWithValue(_Messages(const []))],
    ));
    await tester.pumpAndSettle();
    expect(find.text('No messages yet'), findsOneWidget);
  });

  testWidgets('a conversation shows messages and rejects a blank send', (tester) async {
    final repo = _Messages([
      MessageRecord(id: 'm1', conversationId: 'c1', senderProfileId: 'other', body: 'Hello', createdAt: DateTime.utc(2026, 1, 2, 8)),
    ]);
    await tester.pumpWidget(frame(
      child: const ConversationScreen(id: 'c1'),
      overrides: [messagingRepositoryProvider.overrideWithValue(repo)],
    ));
    await tester.pumpAndSettle();
    expect(find.text('Hello'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), '   ');
    await tester.tap(find.text('Send'));
    await tester.pump();
    expect(find.text('Write a message first.'), findsOneWidget);
    expect(repo.sent, isNull);
  });

  testWidgets('notifications list an unread notice', (tester) async {
    final notice = NotificationRecord(
      id: 'n1',
      recipientProfileId: 'user-1',
      kind: 'new_message',
      title: 'New message',
      body: 'Cement arrived',
      contextType: 'project',
      contextId: 'p1',
      createdAt: DateTime.utc(2026, 1, 2),
    );
    await tester.pumpWidget(frame(
      child: const NotificationsScreen(),
      overrides: [
        notificationRepositoryProvider.overrideWithValue(_Notices()),
        notificationListProvider.overrideWith((ref) async => [notice]),
      ],
    ));
    await tester.pumpAndSettle();
    expect(find.text('New message'), findsOneWidget);
    expect(find.textContaining('Cement arrived'), findsOneWidget);
  });

  testWidgets('inbox shows a loader', (tester) async {
    await tester.pumpWidget(frame(
      child: const InboxScreen(),
      overrides: [conversationListProvider.overrideWith((ref) => Completer<List<ConversationSummary>>().future)],
    ));
    await tester.pump();
    expect(find.text('Loading messages'), findsOneWidget);
  });

}
