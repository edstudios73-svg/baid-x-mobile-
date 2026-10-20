import 'package:flutter_test/flutter_test.dart';

import 'package:baid_x_mobile/core/config/app_config.dart';
import 'package:baid_x_mobile/core/router/route_guards.dart';
import 'package:baid_x_mobile/core/utils/validators.dart';
import 'package:baid_x_mobile/features/account/presentation/profile_pages_b.dart' show accessPlanText;
import 'package:baid_x_mobile/features/account_type/domain/account_type.dart';
import 'package:baid_x_mobile/features/account_type/domain/role_categories.dart';
import 'package:baid_x_mobile/features/directory/data/directory_repository.dart';
import 'package:baid_x_mobile/features/tabs/data/tabs_data.dart' show featureBoostedJobs;

void main() {
  test('the app uses the same backend as the website', () {
    expect(AppConfig.supabaseUrl, 'https://igfmmprlrybxsdzehwid.supabase.co');
    expect(
      AppConfig.supabasePublishableKey.startsWith('sb_publishable_'),
      isTrue,
    );
    expect(AppConfig.supabasePublishableKey.contains('secret'), isFalse);
  });

  test('account types map to the website roles and tables', () {
    expect(
      AccountType.fromDatabase('project-manager'),
      AccountType.projectManager,
    );
    expect(
      AccountType.fromDatabase('individual-employer'),
      AccountType.employer,
    );
    expect(
      AccountType.fromDatabase('project_manager'),
      AccountType.projectManager,
    );
    expect(AccountType.worker.table, 'worker_profiles');
    expect(AccountType.business.label, 'Supplier');
    expect(AccountType.employer.label, 'Client');
  });

  test('professional trades use real job category ids', () {
    expect(jobCategories.length, 50);
    expect(
      jobCategories.any(
        (c) =>
            c.name == 'Electrician' &&
            c.id == 'bb7f934f-fffa-46c3-b031-4dd6408b11ba',
      ),
      isTrue,
    );
    expect(
      supplyCategories.isNotEmpty &&
          industries.isNotEmpty &&
          specializations.isNotEmpty &&
          clientNeeds.isNotEmpty,
      isTrue,
    );
  });

  test('phone and password rules match the website', () {
    expect(Validators.ghanaPhone('024 123 4567'), isNull);
    expect(Validators.ghanaPhone('+233241234567'), isNull);
    expect(Validators.ghanaPhone('12345'), isNotNull);
    for (final typed in [
      '0206071106',
      '020 607 1106',
      '20 607 1106',
      '+233 20 607 1106',
      '233206071106',
      '00233206071106',
      '+233 020 607 1106',
    ]) {
      expect(Validators.ghanaE164(typed), '+233206071106', reason: typed);
    }
    for (final bad in ['0206071', '02060711066', '0806071106', '']) {
      expect(Validators.ghanaE164(bad), isNull, reason: bad);
    }
    expect(Validators.strongPassword('Bx#2026pass'), isNull);
    expect(Validators.strongPassword('password1'), isNotNull);
    expect(Validators.strongPassword('Password1'), isNotNull, reason: 'Supabase Auth also wants a symbol; it refused this at sign-up');
    expect(Validators.strongPassword('PASSWORD1!'), isNotNull, reason: 'and a small letter');
    expect(Validators.strongPassword('Password1!'), isNull);
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

  test('free Access plan wording matches the database limits and the website', () {
    expect(accessPlanText('worker'), contains('5 job applications a month'));
    expect(accessPlanText('company'), contains('1 open job post at a time'));
    expect(accessPlanText('individual-employer'), contains('1 open job post at a time'));
    expect(accessPlanText('business'), isNot(contains('job')));
  });

  test('Discover ranks boosted, then paid plans, then verified, then earliest (website rankMembers)', () {
    DirectoryMember m(String id, {String? badge, int day = 1}) => DirectoryMember(
          group: 'professionals', kind: 'worker', id: id, name: id, tag: '', place: 'Accra', desc: '', stats: const [], badge: badge, joined: DateTime(2026, 1, day));
    final list = [m('old', day: 1), m('verified', badge: 'verified', day: 2), m('pro', day: 3), m('premium', day: 4), m('boosted', day: 5)];
    final promo = {
      'members': [
        {'id': 'pro', 'tier': 'pro'},
        {'id': 'premium', 'tier': 'premium'},
      ],
      'boosts': [
        {'type': 'worker_profile', 'id': 'boosted'},
        {'type': 'job', 'id': 'old'}, // a job boost never lifts a profile
      ],
    };
    final ranked = rankMembers(list, promo);
    expect(ranked.map((x) => x.id), ['boosted', 'premium', 'pro', 'verified', 'old']);
    expect(ranked.firstWhere((x) => x.id == 'pro').planLabel, 'Pro');
    expect(ranked.firstWhere((x) => x.id == 'old').planLabel, isNull);
    expect(rankMembers(list, const {}).map((x) => x.id), ['verified', 'old', 'pro', 'premium', 'boosted']);
  });

  test('boosted jobs come first and are marked (website jobsView)', () {
    final jobs = [
      {'id': 'a', 'title': 'Newest'},
      {'id': 'b', 'title': 'Wall Tilling'},
      {'id': 'c', 'title': 'Older'},
    ];
    final out = featureBoostedJobs(jobs, {
      'boosts': [
        {'type': 'job', 'id': 'b'},
      ],
    });
    expect(out.map((j) => j['id']), ['b', 'a', 'c']);
    expect(out.first['boosted'], isTrue);
    expect(out[1]['boosted'], isFalse);
  });
}
