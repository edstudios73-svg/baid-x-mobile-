import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:baid_x_mobile/features/auth/domain/auth_repository.dart';
import 'package:baid_x_mobile/features/auth/domain/auth_user.dart';
import 'package:baid_x_mobile/features/tabs/data/tabs_data.dart';
import 'package:baid_x_mobile/features/tabs/presentation/chat_screens.dart';
import 'package:baid_x_mobile/features/tabs/presentation/tab_screens.dart';
import 'package:baid_x_mobile/shared/providers/app_providers.dart';

Widget _wrap(Widget child, List overrides) => ProviderScope(
      retry: (_, _) => null,
      overrides: [
        authStateProvider.overrideWith((ref) => Stream.value(const AuthUser(id: 'u', email: 'a@b.co', emailConfirmed: true))),
        accountProfileProvider.overrideWith((ref) async => const AccountProfile(id: 'u', displayName: 'Ama', accountType: 'company')),
        ...overrides.cast(),
      ],
      child: MaterialApp(home: child),
    );

void main() {
  testWidgets('Chats lists conversations from my_conversations', (tester) async {
    await tester.pumpWidget(_wrap(const ChatsTabScreen(), [
      conversationsProvider.overrideWith((ref) async => [
            {'id': 'c1', 'peer_name': 'BAID X Admin', 'peer_admin': true, 'preview': 'Welcome to BAID X', 'unread': 2, 'last_message_at': DateTime.now().toIso8601String()},
            {'id': 'c2', 'peer_name': 'Kwame', 'preview': '{"v":1,"ct":"abc"}'},
          ]),
    ]));
    await tester.pumpAndSettle();
    expect(find.text('BAID X Admin'), findsOneWidget);
    expect(find.text('OFFICIAL'), findsOneWidget);
    expect(find.text('Welcome to BAID X'), findsOneWidget);
    expect(find.text('Encrypted message'), findsOneWidget); // never shows ciphertext
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('a failed tab shows a retry, never an endless spinner', (tester) async {
    await tester.pumpWidget(_wrap(const ProjectsTabScreen(), [
      projectsTabProvider.overrideWith((ref) async => throw StateError('offline')),
    ]));
    await tester.pumpAndSettle();
    expect(find.text('Couldn\'t load this'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('Projects shows the website rows and the empty state', (tester) async {
    await tester.pumpWidget(_wrap(const ProjectsTabScreen(), [
      projectsTabProvider.overrideWith((ref) async => [
            {'id': 'p1', 'name': 'East Legon duplex', 'public_code': 'PRJ-7K2', 'status': 'active', 'progress_pct': 40, 'city_town': 'Accra', 'my_role': 'company'},
          ]),
    ]));
    await tester.pumpAndSettle();
    expect(find.text('East Legon duplex'), findsOneWidget);
    expect(find.text('Active'), findsWidgets);
    await tester.tap(find.text('Completed').first);
    await tester.pumpAndSettle();
    expect(find.text('No projects yet'), findsOneWidget);
  });

  testWidgets('Hires for a company reads as Job posts', (tester) async {
    await tester.pumpWidget(_wrap(const HiresTabScreen(), [hiresTabProvider.overrideWith((ref) async => <Json>[])]));
    await tester.pumpAndSettle();
    expect(find.text('Job posts'), findsOneWidget);
    expect(find.text('No jobs yet'), findsOneWidget);
  });

  test('money and ago match the website', () {
    expect(money(1234.5), 'GH₵1,234.50');
    expect(money(null), 'GH₵0.00');
    expect(ago(DateTime.now().subtract(const Duration(minutes: 5)).toIso8601String()), '5m ago');
  });
}
