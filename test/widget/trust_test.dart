import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:baid_x_mobile/features/auth/domain/auth_repository.dart';
import 'package:baid_x_mobile/features/auth/domain/auth_user.dart';
import 'package:baid_x_mobile/features/billing/presentation/billing_providers.dart';
import 'package:baid_x_mobile/features/trust/presentation/trust_screens.dart';
import 'package:baid_x_mobile/shared/providers/app_providers.dart';

void main() {
  const user = AuthUser(id: 'user-1', email: 'a@baidx.test', emailConfirmed: true);
  const profile = AccountProfile(id: 'user-1', displayName: 'Ama', accountType: 'worker');
  const products = [
    {'label': 'Identity', 'product_code': 'identity', 'verification_kind': 'identity', 'amount_minor': 1000, 'currency_code': 'GHS'},
  ];

  Future<void> show(WidgetTester tester, List<Map<String, dynamic>> records) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(user)),
          accountProfileProvider.overrideWith((ref) async => profile),
          verificationProductsProvider.overrideWith((ref) async => products),
          myVerificationsProvider.overrideWith((ref) async => records),
        ],
        child: const MaterialApp(home: VerificationScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('a worker who has not applied sees the purchase price', (tester) async {
    await show(tester, const []);
    expect(find.textContaining('10.00 GHS'), findsOneWidget);
    expect(find.text('Purchase'), findsOneWidget);
    expect(find.textContaining('does not mark the account verified'), findsOneWidget);
  });

  testWidgets('pending is not shown as verified', (tester) async {
    await show(tester, const [
      {'verification_kind': 'identity', 'status': 'pending'},
    ]);
    expect(find.textContaining('Under review'), findsOneWidget);
    expect(find.text('Purchase'), findsNothing);
    expect(find.text('Verified'), findsNothing);
  });

  testWidgets('verified uses the database status', (tester) async {
    await show(tester, const [
      {'verification_kind': 'identity', 'status': 'verified'},
    ]);
    expect(find.textContaining('Verified'), findsOneWidget);
    expect(find.text('Purchase'), findsNothing);
  });

  testWidgets('rejected uses the database status', (tester) async {
    await show(tester, const [
      {'verification_kind': 'identity', 'status': 'rejected'},
    ]);
    expect(find.textContaining('Rejected'), findsOneWidget);
    expect(find.text('Purchase'), findsOneWidget);
  });
}
