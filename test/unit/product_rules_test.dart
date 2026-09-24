import 'package:flutter_test/flutter_test.dart';

import 'package:baid_x_mobile/features/billing/domain/product_rules.dart';

void main() {
  test('a pending or verified check cannot be purchased again', () {
    expect(canPurchaseVerification(null), isTrue);
    expect(canPurchaseVerification('rejected'), isTrue);
    expect(canPurchaseVerification('pending'), isFalse);
    expect(canPurchaseVerification('verified'), isFalse);
    expect(verificationStateLabel('pending'), 'Under review');
  });

  test('a promotion cannot exceed the package listing limit', () {
    expect(listingSelectionError(selected: 0, limit: 3), isNotNull);
    expect(listingSelectionError(selected: 4, limit: 3), isNotNull);
    expect(listingSelectionError(selected: 3, limit: 3), isNull);
  });

  test('XID eligibility follows the account', () {
    expect(xidAllowed('worker', 'professional'), isTrue);
    expect(xidAllowed('business', 'business'), isTrue);
    expect(xidAllowed('worker', 'company'), isFalse);
    expect(xidAllowed('company', 'digital_card'), isFalse);
    expect(xidAllowed('project_manager', 'professional'), isTrue);
  });

  test('profile boosts follow the account and capacity comes from entitlements', () {
    expect(profileBoostTarget('worker'), 'worker_profile');
    expect(profileBoostTarget('project_manager'), 'project_manager_profile');
    expect(profileBoostTarget('employer'), isNull);
    expect(capacityLines({'organization_capacity': 250, 'project_capacity': 100}), [
      'Organization members: 250',
      'Active projects: 100',
    ]);
    expect(capacityLines({}), isEmpty);
  });
}