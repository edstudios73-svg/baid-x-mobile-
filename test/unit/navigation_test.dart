import 'package:flutter_test/flutter_test.dart';

import 'package:baid_x_mobile/core/constants/app_routes.dart';
import 'package:baid_x_mobile/core/router/route_guards.dart';
import 'package:baid_x_mobile/core/utils/validators.dart';
import 'package:baid_x_mobile/features/account_type/domain/account_type.dart';

void main() {
  test('a visitor can open the marketplace', () {
    expect(
      guardRedirect(
        authLoading: false,
        gate: SessionGate.signedOut,
        profileLoading: false,
        accountType: null,
        path: AppRoutes.marketplace,
      ),
      isNull,
    );
  });

  test('billing, review, and projects stay behind sign-in', () {
    for (final path in [
      AppRoutes.billing,
      AppRoutes.companyBilling,
      AppRoutes.verificationReview,
      AppRoutes.projects,
    ]) {
      expect(
        guardRedirect(
          authLoading: false,
          gate: SessionGate.signedOut,
          profileLoading: false,
          accountType: null,
          path: path,
        ),
        AppRoutes.signIn,
      );
    }
  });

  test('a visitor sees the guest Profile and Chats tabs, like the website', () {
    for (final path in [AppRoutes.profile, AppRoutes.messages]) {
      expect(
        guardRedirect(
          authLoading: false,
          gate: SessionGate.signedOut,
          profileLoading: false,
          accountType: null,
          path: path,
        ),
        isNull,
      );
    }
    expect(
      guardRedirect(authLoading: false, gate: SessionGate.signedOut, profileLoading: false, accountType: null, path: AppRoutes.settings),
      AppRoutes.signIn,
    );
  });

  test('an unverified user stays on the marketplace', () {
    expect(
      guardRedirect(
        authLoading: false,
        gate: SessionGate.unverified,
        profileLoading: false,
        accountType: null,
        path: AppRoutes.marketplace,
      ),
      isNull,
    );
  });

  test('an unverified user cannot open messages', () {
    expect(
      guardRedirect(
        authLoading: false,
        gate: SessionGate.unverified,
        profileLoading: false,
        accountType: null,
        path: AppRoutes.messages,
      ),
      AppRoutes.emailVerification,
    );
  });

  test('splash continues to the member directory', () {
    expect(
      guardRedirect(
        authLoading: false,
        gate: SessionGate.signedOut,
        profileLoading: false,
        accountType: null,
        path: AppRoutes.splash,
      ),
      AppRoutes.discover,
    );
  });

  test('password confirmation must match', () {
    expect(Validators.confirmPassword('different', 'longenough'), 'Passwords do not match.');
    expect(Validators.confirmPassword('longenough', 'longenough'), isNull);
  });

  test('a verified user without a type opens account selection', () {
    expect(
      guardRedirect(
        authLoading: false,
        gate: SessionGate.verified,
        profileLoading: false,
        accountType: null,
        path: AppRoutes.splash,
      ),
      AppRoutes.accountType,
    );
  });

  test('a returning worker skips account selection', () {
    expect(
      guardRedirect(
        authLoading: false,
        gate: SessionGate.verified,
        profileLoading: false,
        accountType: 'worker',
        path: AppRoutes.accountType,
      ),
      '/role/worker',
    );
  });

  test('each account type opens its own home', () {
    for (final type in ['worker', 'employer', 'business', 'project_manager', 'company']) {
      expect(
        guardRedirect(
          authLoading: false,
          gate: SessionGate.verified,
          profileLoading: false,
          accountType: type,
          path: AppRoutes.splash,
        ),
        '/role/$type',
      );
    }
  });

  test('a signed-out user cannot open a role home', () {
    expect(
      guardRedirect(
        authLoading: false,
        gate: SessionGate.signedOut,
        profileLoading: false,
        accountType: null,
        path: '/role/worker',
      ),
      AppRoutes.signIn,
    );
  });

  test('a worker cannot open another role setup', () {
    expect(
      guardRedirect(
        authLoading: false,
        gate: SessionGate.verified,
        profileLoading: false,
        accountType: 'worker',
        path: '/setup/business',
      ),
      '/role/worker',
    );
  });

  test('worker and business navigation stay different', () {
    final worker = destinationsFor(AccountType.worker).map((item) => item.label);
    final business = destinationsFor(AccountType.business).map((item) => item.label);
    // same tabs as the website
    expect(worker, ['Home', 'Jobs', 'Work', 'Chats', 'Profile']);
    expect(business, ['Home', 'Discover', 'Catalog', 'Inquiries', 'Profile']);
    expect(destinationsFor(AccountType.employer).map((item) => item.label), ['Home', 'Discover', 'Hires', 'Chats', 'Profile']);
    expect(destinationsFor(AccountType.projectManager).map((item) => item.label), ['Home', 'Discover', 'Projects', 'Chats', 'Profile']);
    expect(destinationsFor(AccountType.company).map((item) => item.label), ['Home', 'Workforce', 'Projects', 'Chats', 'Profile']);
    expect(destinationsFor(null).map((item) => item.label), ['Home', 'Chats', 'Profile']);
    for (final type in AccountType.values) {
      expect(destinationsFor(type).length, lessThanOrEqualTo(5));
    }
  });

  test('a profile that fails to load never opens role selection', () {
    expect(
      guardRedirect(authLoading: false, gate: SessionGate.verified, profileLoading: false, accountType: null, path: AppRoutes.splash, profileFailed: true),
      AppRoutes.discover,
    );
    expect(
      guardRedirect(authLoading: false, gate: SessionGate.verified, profileLoading: false, accountType: null, path: AppRoutes.discover, profileFailed: true),
      isNull,
    );
  });
}
