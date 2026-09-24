import 'package:flutter_test/flutter_test.dart';

import 'package:baid_x_mobile/core/utils/validators.dart';

void main() {
  test('email rejects a missing domain', () {
    expect(Validators.email('ada'), 'Enter a valid email.');
    expect(Validators.email('ada@baidx.app'), isNull);
  });

  test('password requires 8 characters', () {
    expect(Validators.password('short'), isNotNull);
    expect(Validators.password('longenough'), isNull);
  });

  test('contact requires a phone number', () {
    expect(Validators.contact('123'), isNotNull);
    expect(Validators.contact('0244000000'), isNull);
  });
}
