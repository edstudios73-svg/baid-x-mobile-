import 'package:flutter_test/flutter_test.dart';

import 'package:baid_x_mobile/core/constants/app_routes.dart';
import 'package:baid_x_mobile/core/router/route_guards.dart';
import 'package:baid_x_mobile/features/projects/domain/project_rules.dart';

void main() {
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

  test('only a project manager can request company access', () {
    expect(canRequestCompanyAccess('project_manager'), isTrue);
    expect(canRequestCompanyAccess('company'), isFalse);
    expect(canRequestCompanyAccess('worker'), isFalse);
  });

  test('only a company account can review access requests', () {
    expect(canReviewCompanyAccess('company'), isTrue);
    expect(canReviewCompanyAccess('project_manager'), isFalse);
  });

  test('a new project is owned by the caller and stays private', () {
    final row = newProjectRow(userId: 'user-1', title: ' Site works ', summary: 'Foundations');
    expect(row['owner_profile_id'], 'user-1');
    expect(row['is_public'], isFalse);
    expect(row['status'], 'draft');
    expect(row['title'], 'Site works');
  });

  test('project members are never assigned the lead role from the form', () {
    final row = projectMemberRow(projectId: 'p1', profileId: 'u2', role: 'lead');
    expect(row['member_role'], 'worker');
    expect(projectMemberRow(projectId: 'p1', profileId: 'u2', role: 'project_manager')['member_role'], 'project_manager');
  });

  test('expense amounts must be zero or more', () {
    expect(validateExpenseAmount('-1'), isNotNull);
    expect(validateExpenseAmount('12.5'), isNull);
  });
}
