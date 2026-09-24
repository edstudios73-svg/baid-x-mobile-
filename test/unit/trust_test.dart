import 'package:flutter_test/flutter_test.dart';

import 'package:baid_x_mobile/features/trust/domain/trust_rules.dart';

void main() {
  test('verification follows the account and cannot be chosen as verified', () {
    expect(verificationKindFor('worker'), 'identity');
    expect(verificationKindFor('business'), 'business');
    expect(verificationKindFor('company'), 'company');
    expect(verificationKindFor('employer'), isNull);
    expect(verificationStatuses, ['pending', 'verified', 'rejected']);
  });

  test('a review needs words and a rating from 1 to 5', () {
    expect(validateReview(body: '   ', rating: '5'), isNotNull);
    expect(validateReview(body: 'Solid work', rating: '0'), isNotNull);
    expect(validateReview(body: 'Solid work', rating: '4'), isNull);
  });
}
