import 'package:flutter_test/flutter_test.dart';

import 'package:baid_x_mobile/core/config/app_config.dart';
import 'package:baid_x_mobile/features/billing/domain/billing_rules.dart';

void main() {
  test('the Paystack key in the app is the test public key', () {
    expect(AppConfig.paystackPublicKey.startsWith('pk_test_'), isTrue);
    expect(AppConfig.paystackPublicKey.startsWith('sk_'), isFalse);
  });

  test('money is shown from minor units and a supplied symbol', () {
    expect(formatMinorAmount(3000, symbol: 'GH₵'), 'GH₵30.00');
    expect(formatMinorAmount(200, symbol: 'GH₵'), 'GH₵2.00');
    expect(formatMinorAmount(10000, symbol: 'GH₵'), 'GH₵100.00');
  });

  test('a plan price comes from the offer, including founding price', () {
    const plan = PlanOffer(
      id: 'plan-1',
      tier: 'pro',
      monthlyAmount: 3000,
      annualAmount: 28800,
      foundingMonthlyAmount: 2000,
      foundingAnnualAmount: 19200,
      currencyCode: 'GHS',
      symbol: 'GH₵',
      entitlements: {'can_boost': true},
    );
    expect(formatMinorAmount(plan.foundingMonthlyAmount!, symbol: plan.symbol), 'GH₵20.00');
    expect(plan.entitlements['can_boost'], isTrue);
  });
}
