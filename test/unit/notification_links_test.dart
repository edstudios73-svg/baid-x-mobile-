import 'package:flutter_test/flutter_test.dart';

import 'package:baid_x_mobile/core/constants/app_routes.dart';
import 'package:baid_x_mobile/features/account/presentation/extra_screens.dart';
import 'package:baid_x_mobile/features/account/presentation/profile_pages_b.dart';

void main() {
  test('website notification links open the matching app screen', () {
    expect(appPathFor('#/chat/abc'), '${AppRoutes.messages}/abc');
    expect(appPathFor('#/order/o1'), '${AppRoutes.orders}/o1');
    expect(appPathFor('#/wallet'), AppRoutes.wallet);
    expect(appPathFor('#/ws/team'), AppRoutes.projects);
    expect(appPathFor('https://example.com'), isNull);
    expect(appPathFor(null), isNull);
  });

  test('plan prices print like the website', () {
    expect(cedi(9900), 'GH₵99');
    expect(cedi(1234550), 'GH₵12,345.50');
  });
}
