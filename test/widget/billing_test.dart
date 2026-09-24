import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:baid_x_mobile/features/auth/domain/auth_repository.dart';
import 'package:baid_x_mobile/features/auth/domain/auth_user.dart';
import 'package:baid_x_mobile/features/billing/domain/billing_rules.dart';
import 'package:baid_x_mobile/features/billing/presentation/billing_providers.dart';
import 'package:baid_x_mobile/features/billing/presentation/billing_screen.dart';
import 'package:baid_x_mobile/shared/providers/app_providers.dart';

void main() {
  testWidgets('billing shows the database plan price and does not claim verification', (tester) async {
    const plan = PlanOffer(
      id: 'plan-1',
      tier: 'pro',
      monthlyAmount: 3000,
      annualAmount: 28800,
      foundingMonthlyAmount: 2000,
      foundingAnnualAmount: 19200,
      currencyCode: 'GHS',
      symbol: 'GH₵',
      entitlements: {},
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(const AuthUser(id: 'user-1', email: 'a@baidx.test', emailConfirmed: true))),
          accountProfileProvider.overrideWith((ref) async => const AccountProfile(id: 'user-1', displayName: 'Ama', accountType: 'worker')),
          billingSnapshotProvider.overrideWith((ref) async => BillingSnapshot(
            accountType: 'worker',
            subscription: null,
            entitlements: const {},
            foundingEligible: true,
            protectedPaymentsEnabled: false,
            refundDeadline: DateTime.utc(2026, 1, 8),
          )),
          rolePlansProvider.overrideWith((ref) async => [plan]),
          paymentHistoryProvider.overrideWith((ref) async => const []),
        ],
        child: const MaterialApp(home: BillingScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('GH₵20.00'), findsOneWidget);
    expect(find.text('A paid plan does not verify this account.'), findsOneWidget);
    expect(find.text('No payments yet'), findsOneWidget);
    expect(find.textContaining('Refund window ends'), findsOneWidget);
  });
}
