import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:baid_x_mobile/features/account/data/profile_data.dart';
import 'package:baid_x_mobile/features/account/presentation/billing_screen.dart';
import 'package:baid_x_mobile/features/auth/domain/auth_repository.dart';
import 'package:baid_x_mobile/features/auth/domain/auth_user.dart';
import 'package:baid_x_mobile/shared/providers/app_providers.dart';

const _plans = [
  {'id': 'p1', 'role': 'worker', 'tier': 'pro', 'billing_interval': 'monthly', 'is_founding': false, 'price_minor': 20000, 'currency': 'GHS', 'capacity_limits': {}, 'metadata': {'best_for': 'Members who use BAID X every week and want no limits.', 'benefits': [{'t': 'Unlimited job applications', 'd': 'Apply to as many jobs as you want. Access includes 5 a month.'}, {'t': 'Pro mark on your profile', 'd': 'Shown beside your name on your card and profile.'}]}},
  {'id': 'p2', 'role': 'worker', 'tier': 'pro', 'billing_interval': 'annual', 'is_founding': false, 'price_minor': 200000, 'currency': 'GHS', 'capacity_limits': {}, 'metadata': {}},
  {'id': 'p3', 'role': 'worker', 'tier': 'premium', 'billing_interval': 'monthly', 'is_founding': false, 'price_minor': 35000, 'currency': 'GHS', 'capacity_limits': {}, 'metadata': {'benefits': [{'t': 'Listed above Pro members'}]}},
];
const _services = [
  {'id': 's1', 'kind': 'boost', 'code': 'profile_24h', 'role': 'worker', 'label': 'Profile boost, 24 hours', 'price_minor': 1500, 'currency': 'GHS', 'duration_hours': 24, 'metadata': {'target': 'worker_profile'}},
  {'id': 's2', 'kind': 'boost', 'code': 'profile_7d', 'role': 'worker', 'label': 'Profile boost, 7 days', 'price_minor': 8000, 'currency': 'GHS', 'duration_hours': 168, 'metadata': {'target': 'worker_profile'}},
  {'id': 's3', 'kind': 'verification', 'code': 'identity', 'role': 'worker', 'label': 'Identity verification', 'price_minor': 5000, 'currency': 'GHS', 'duration_hours': null, 'metadata': {}},
];

Widget _wrap() => ProviderScope(
      retry: (_, _) => null,
      overrides: [
        authStateProvider.overrideWith((ref) => Stream.value(const AuthUser(id: 'u', email: 'a@b.co', emailConfirmed: true))),
        accountProfileProvider.overrideWith((ref) async => const AccountProfile(id: 'u', displayName: 'Ama', accountType: 'worker')),
        billingProvider.overrideWith((ref) async => const BillingData(
              plans: _plans,
              slots: null,
              summary: {'subscribed': false},
              payments: [
                {'what': 'Profile boost, 7 days', 'purpose': 'boost', 'status': 'successful', 'amount_minor': 8000, 'currency': 'GHS', 'reference': 'BXP-AAAAAAAAAAAAAAAA', 'created_at': '2026-10-12T22:42:20Z'},
              ],
              services: _services,
              role: 'worker',
            )),
      ],
      child: MaterialApp(theme: ThemeData(brightness: Brightness.dark, fontFamily: 'Inter'), builder: (c, w) => MediaQuery(data: MediaQuery.of(c).copyWith(disableAnimations: true), child: w!), home: const PlansBillingScreen()),
    );

void main() {
  test('compare table and services follow the account type (website compareRows, BOOST_FOR)', () {
    final w = billingCompareRows('worker', ['pro', 'premium']);
    expect(w.first.$1, 'Job applications');
    expect(w.first.$2, ['5 a month', 'Unlimited', 'Unlimited']);
    expect(billingCompareRows('company', ['pro', 'premium', 'enterprise']).last.$2, [false, false, false, true]);
    expect(billingBoostFor('company'), 'job');
    expect(billingBoostFor('worker'), 'profile');
    final all = [
      {'kind': 'boost', 'role': null, 'metadata': {'target': 'job'}},
      {'kind': 'boost', 'role': 'worker', 'metadata': {'target': 'worker_profile'}},
      {'kind': 'verification', 'role': 'worker', 'metadata': {}},
    ];
    expect(billingServicesFor('worker', all).length, 2, reason: 'a worker never sees a job boost');
    expect(billingServicesFor('company', all).length, 1, reason: 'a company only sees the job boost');
    expect(boostDuration(24), '1 day');
    expect(boostDuration(168), '7 days');
  });

  testWidgets('Plans & billing: plans, services and payments read like the website', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 2400));
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();
    expect(find.text('YOUR PLAN'), findsOneWidget);
    expect(find.text('GH₵200'), findsOneWidget);
    expect(find.text('Unlimited job applications'), findsOneWidget);
    expect(find.text('Compare plans'), findsOneWidget);
    expect(find.text('Choose Pro'), findsOneWidget);

    await tester.tap(find.text('Yearly'));
    await tester.pumpAndSettle();
    expect(find.text('GH₵2,000'), findsOneWidget);

    await tester.tap(find.text('Services'));
    await tester.pumpAndSettle();
    expect(find.text('Be seen first'), findsOneWidget);
    expect(find.text('Boost for GH₵80'), findsOneWidget, reason: '7 days is picked first');
    await tester.tap(find.text('1 day'));
    await tester.pumpAndSettle();
    expect(find.text('Boost for GH₵15'), findsOneWidget);

    await tester.tap(find.text('Verification'));
    await tester.pumpAndSettle();
    expect(find.text('Request review · GH₵50'), findsOneWidget);

    await tester.tap(find.text('Payments'));
    await tester.pumpAndSettle();
    expect(find.text('Profile boost, 7 days'), findsOneWidget);
    expect(find.text('Paid'), findsOneWidget);
  });
}
