import 'package:flutter_test/flutter_test.dart';

import 'package:baid_x_mobile/core/constants/app_routes.dart';
import 'package:baid_x_mobile/core/router/route_guards.dart';

/// Guard rules for job, listing and project pages, kept from the old feature
/// tests when those screens moved to the website's data.
void main() {
  test('a visitor cannot open their applications', () {
    expect(
      guardRedirect(
        authLoading: false,
        gate: SessionGate.signedOut,
        profileLoading: false,
        accountType: null,
        path: AppRoutes.applications,
      ),
      AppRoutes.signIn,
    );
  });
  test('a worker can open jobs and applications, and cannot open another role home', () {
    expect(
      guardRedirect(
        authLoading: false,
        gate: SessionGate.verified,
        profileLoading: false,
        accountType: 'worker',
        path: AppRoutes.work,
      ),
      isNull,
    );
    expect(
      guardRedirect(
        authLoading: false,
        gate: SessionGate.verified,
        profileLoading: false,
        accountType: 'worker',
        path: AppRoutes.applications,
      ),
      isNull,
    );
    expect(
      guardRedirect(
        authLoading: false,
        gate: SessionGate.verified,
        profileLoading: false,
        accountType: 'worker',
        path: '/role/company',
      ),
      '/role/worker',
    );
  });
  test('a visitor can browse open jobs', () {
    expect(
      guardRedirect(
        authLoading: false,
        gate: SessionGate.signedOut,
        profileLoading: false,
        accountType: null,
        path: AppRoutes.work,
      ),
      isNull,
    );
  });
  test('a visitor cannot apply or post a job', () {
    expect(
      guardRedirect(
        authLoading: false,
        gate: SessionGate.signedOut,
        profileLoading: false,
        accountType: null,
        path: '/jobs/1/apply',
      ),
      AppRoutes.discover,
    );
    expect(
      guardRedirect(
        authLoading: false,
        gate: SessionGate.signedOut,
        profileLoading: false,
        accountType: null,
        path: AppRoutes.postJob,
      ),
      AppRoutes.signIn,
    );
  });
  test('a visitor cannot open projects', () {
    expect(
      guardRedirect(
        authLoading: false,
        gate: SessionGate.signedOut,
        profileLoading: false,
        accountType: null,
        path: AppRoutes.projects,
      ),
      AppRoutes.signIn,
    );
  });
}
