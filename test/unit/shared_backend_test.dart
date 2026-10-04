import 'package:flutter_test/flutter_test.dart';

import 'package:baid_x_mobile/core/config/app_config.dart';
import 'package:baid_x_mobile/core/router/route_guards.dart';
import 'package:baid_x_mobile/core/utils/validators.dart';
import 'package:baid_x_mobile/features/account_type/domain/account_type.dart';
import 'package:baid_x_mobile/features/account_type/domain/role_categories.dart';

void main() {
  test('the app uses the same backend as the website', () {
    expect(AppConfig.supabaseUrl, 'https://igfmmprlrybxsdzehwid.supabase.co');
    expect(AppConfig.supabasePublishableKey.startsWith('sb_publishable_'), isTrue);
    expect(AppConfig.supabasePublishableKey.contains('secret'), isFalse);
  });

  test('account types map to the website roles and tables', () {
    expect(AccountType.fromDatabase('project-manager'), AccountType.projectManager);
    expect(AccountType.fromDatabase('individual-employer'), AccountType.employer);
    expect(AccountType.fromDatabase('project_manager'), AccountType.projectManager);
    expect(AccountType.worker.table, 'worker_profiles');
    expect(AccountType.business.label, 'Supplier');
    expect(AccountType.employer.label, 'Client');
  });

  test('professional trades use real job category ids', () {
    expect(jobCategories.length, 50);
    expect(jobCategories.any((c) => c.name == 'Electrician' && c.id == 'bb7f934f-fffa-46c3-b031-4dd6408b11ba'), isTrue);
    expect(supplyCategories.isNotEmpty && industries.isNotEmpty && specializations.isNotEmpty && clientNeeds.isNotEmpty, isTrue);
  });

  test('phone and password rules match the website', () {
    expect(Validators.ghanaPhone('024 123 4567'), isNull);
    expect(Validators.ghanaPhone('+233241234567'), isNull);
    expect(Validators.ghanaPhone('12345'), isNotNull);
    expect(Validators.strongPassword('Bx#2026pass'), isNull);
    expect(Validators.strongPassword('password1'), isNotNull);
    expect(Validators.code('482915'), isNull);
    expect(Validators.code('48a'), isNotNull);
  });

  test('a signed-in member without a profile can reach account setup', () {
    String? go(String path, String? type) => guardRedirect(
          authLoading: false,
          gate: SessionGate.verified,
          profileLoading: false,
          accountType: type,
          path: path,
        );
    expect(go('/setup/worker', null), isNull);
    expect(go('/role/worker', null), '/account-type');
    expect(go('/setup/worker', 'worker'), '/role/worker');
  });
}
