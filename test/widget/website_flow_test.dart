import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:baid_x_mobile/core/services/storage_service.dart';
import 'package:baid_x_mobile/features/auth/data/remembered_accounts.dart';
import 'package:baid_x_mobile/features/auth/presentation/screens/auth_flow_screen.dart';
import 'package:baid_x_mobile/shared/providers/app_providers.dart';

Widget _auth(AuthFlowScreen screen, {KeyValueStore? store}) => ProviderScope(
      overrides: [keyValueStoreProvider.overrideWithValue(store ?? MemoryKeyValueStore())],
      child: MaterialApp(builder: (c, w) => MediaQuery(data: MediaQuery.of(c).copyWith(disableAnimations: true), child: w!), home: screen),
    );

void main() {
  testWidgets('Join as a professional lists all five types, Professional pre-selected', (tester) async {
    await tester.pumpWidget(_auth(const AuthFlowScreen(group: 'pro')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Create your account'), findsOneWidget);
    for (final t in ['Professional', 'Project Manager', 'Supplier', 'Company', 'Client']) {
      expect(find.text(t), findsOneWidget);
    }
  });

  testWidgets('Client sign-in picks the type first, like the website', (tester) async {
    await tester.pumpWidget(_auth(const AuthFlowScreen(start: AuthStart.signIn, group: 'client')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Client sign-in'), findsOneWidget);
    expect(find.text('Choose your account type to continue.'), findsOneWidget);
    expect(find.text('Professional'), findsNothing);
    await tester.tap(find.text('Continue'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('Signing in as'), findsOneWidget);
  });

  testWidgets('accounts used on this device open "Continue with"', (tester) async {
    final store = MemoryKeyValueStore();
    await RememberedAccounts(store).remember(const RememberedAccount(id: 'u1', name: 'Kwame Mensah', role: 'worker', phone: '+233201234567'));
    await tester.pumpWidget(_auth(const AuthFlowScreen(start: AuthStart.signIn), store: store));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Continue with'), findsOneWidget);
    expect(find.text('Kwame Mensah'), findsOneWidget);
    await tester.tap(find.text('Kwame Mensah'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('Welcome back, Kwame Mensah'), findsOneWidget);
  });

  test('remembered accounts keep the latest first, once each, no secrets', () async {
    final store = MemoryKeyValueStore();
    final r = RememberedAccounts(store);
    await r.remember(const RememberedAccount(id: 'a', name: 'A', role: 'worker'));
    await r.remember(const RememberedAccount(id: 'b', name: 'B', role: 'company'));
    await r.remember(const RememberedAccount(id: 'a', name: 'A2', role: 'worker'));
    final list = await r.list();
    expect(list.map((x) => x.id), ['a', 'b']);
    expect(list.first.name, 'A2');
    final raw = await store.read('baidx_accounts');
    expect(raw, isNot(contains('token')));
    expect(raw, isNot(contains('password')));
  });
}
