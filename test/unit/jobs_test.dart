import 'package:flutter_test/flutter_test.dart';

import 'package:baid_x_mobile/core/constants/app_routes.dart';
import 'package:baid_x_mobile/core/router/route_guards.dart';
import 'package:baid_x_mobile/features/jobs/domain/job_rules.dart';

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

  test('a worker can apply to an open job they do not own', () {
    expect(
      decideApply(signedIn: true, accountType: 'worker', jobStatus: 'open', isOwner: false, alreadyApplied: false),
      ApplyDecision.allowed,
    );
  });

  test('a closed job and a duplicate application are blocked', () {
    expect(
      decideApply(signedIn: true, accountType: 'worker', jobStatus: 'closed', isOwner: false, alreadyApplied: false),
      ApplyDecision.closed,
    );
    expect(
      decideApply(signedIn: true, accountType: 'worker', jobStatus: 'open', isOwner: false, alreadyApplied: true),
      ApplyDecision.alreadyApplied,
    );
  });

  test('an employer cannot apply and an owner manages the job', () {
    expect(
      decideApply(signedIn: true, accountType: 'employer', jobStatus: 'open', isOwner: false, alreadyApplied: false),
      ApplyDecision.notWorker,
    );
    expect(
      decideApply(signedIn: true, accountType: 'worker', jobStatus: 'open', isOwner: true, alreadyApplied: false),
      ApplyDecision.ownJob,
    );
  });

  test('a signed-out person is asked to sign in before applying', () {
    expect(
      decideApply(signedIn: false, accountType: null, jobStatus: 'open', isOwner: false, alreadyApplied: false),
      ApplyDecision.needsSignIn,
    );
  });

  test('job posting requires a title and limited length', () {
    expect(validateJobDraft(title: ' ', description: '', location: ''), 'Add a job title.');
    expect(validateJobDraft(title: 'Mason', description: '', location: 'Accra'), isNull);
    expect(validateJobDraft(title: 'x' * 121, description: '', location: ''), 'Keep the title under 120 characters.');
  });
}
