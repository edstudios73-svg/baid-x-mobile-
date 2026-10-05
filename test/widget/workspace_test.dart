import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:baid_x_mobile/features/auth/domain/auth_repository.dart';
import 'package:baid_x_mobile/features/auth/domain/auth_user.dart';
import 'package:baid_x_mobile/features/tabs/data/tabs_data.dart';
import 'package:baid_x_mobile/features/workspace/data/workspace_data.dart';
import 'package:baid_x_mobile/features/workspace/presentation/invites_approvals.dart';
import 'package:baid_x_mobile/features/workspace/presentation/workspace_screen.dart';
import 'package:baid_x_mobile/shared/providers/app_providers.dart';

Widget _wrap(Widget child, List overrides, {String type = 'company'}) => ProviderScope(
      retry: (_, _) => null,
      overrides: [
        authStateProvider.overrideWith((ref) => Stream.value(const AuthUser(id: 'u', email: 'a@b.co', emailConfirmed: true))),
        accountProfileProvider.overrideWith((ref) async => AccountProfile(id: 'u', displayName: 'Ama', accountType: type)),
        projectsTabProvider.overrideWith((ref) async => <Json>[]),
        ...overrides.cast(),
      ],
      child: MaterialApp(home: child),
    );

Json _ov(String role) => {
      'id': 'p1', 'name': 'East Legon duplex', 'public_code': 'PRJ-7K2', 'status': 'active', 'my_role': role, 'progress_pct': 40,
      'team_active': 3, 'tasks_done': 2, 'tasks_total': 5, 'tasks_overdue': 1, 'awaiting_approval': 2, 'worker_addition_mode': 'automatic',
      'company': {'name': 'Ama Builders'}, 'pm': null, 'project_type': 'building', 'city_town': 'Accra', 'region': 'Greater Accra',
    };

void main() {
  testWidgets('a company sees every workspace tab, the overview and approval settings', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 2400));
    await tester.pumpWidget(_wrap(const WorkspaceScreen(projectId: 'p1'), [
      projectOverviewProvider('p1').overrideWith((ref) async => _ov('company')),
      projectTeamProvider('p1').overrideWith((ref) async => {'members': [], 'invitations': []}),
      completionNoteProvider('p1').overrideWith((ref) async => <String, dynamic>{}),
    ]));
    await tester.pumpAndSettle();
    expect(find.text('East Legon duplex'), findsOneWidget);
    for (final t in ['Overview', 'Team', 'Tasks', 'Reports', 'Finance', 'Milestones', 'Activity']) {
      expect(find.text(t), findsWidgets);
    }
    expect(find.text('2/5'), findsOneWidget);
    expect(find.text('2 items waiting for you'), findsOneWidget);
    expect(find.text('Adding workers'), findsOneWidget);
    expect(find.text('Mark as completed'), findsOneWidget); // no PM yet
  });

  testWidgets('a worker sees only their tabs and can accept an assigned task', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 2400));
    await tester.pumpWidget(_wrap(const WorkspaceScreen(projectId: 'p1', tab: 'mytasks'), [
      projectOverviewProvider('p1').overrideWith((ref) async => _ov('worker')),
      projectTasksProvider('p1').overrideWith((ref) async => [
            {'id': 't1', 'title': 'Wire the second floor', 'status': 'todo', 'priority': 'high', 'assignee_worker_id': 'u', 'accepted_at': null},
            {'id': 't2', 'title': 'Someone else\'s task', 'status': 'todo', 'priority': 'low', 'assignee_worker_id': 'x'},
          ]),
    ], type: 'worker'));
    await tester.pumpAndSettle();
    expect(find.text('Finance'), findsNothing);
    expect(find.text('My Tasks'), findsOneWidget);
    expect(find.text('Wire the second floor'), findsOneWidget);
    expect(find.text('Someone else\'s task'), findsNothing);
    expect(find.text('Accept'), findsOneWidget);
    expect(find.text('Start work'), findsOneWidget);
  });

  testWidgets('a team with an invitation that needs approval offers approve, reject and ask', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 2400));
    await tester.pumpWidget(_wrap(const WorkspaceScreen(projectId: 'p1', tab: 'team'), [
      projectOverviewProvider('p1').overrideWith((ref) async => _ov('company')),
      projectTeamProvider('p1').overrideWith((ref) async => {
            'members': [
              {'profile_id': 'u', 'name': 'Ama Builders', 'role_type': 'company', 'project_role': 'Owner'},
            ],
            'invitations': [
              {'id': 'i1', 'name': 'Kofi Mensah', 'status': 'pending_company_approval', 'trade_label': 'Electrician', 'invited_by_name': 'Yaw', 'reasons': ['exceeds_headcount']},
            ],
          }),
    ]));
    await tester.pumpAndSettle();
    expect(find.text('+ Invite project manager'), findsOneWidget);
    expect(find.text('Kofi Mensah'), findsOneWidget);
    expect(find.text('Over the planned team size'), findsOneWidget);
    expect(find.text('Approve'), findsOneWidget);
    expect(find.text('Ask PM'), findsOneWidget);
  });

  testWidgets('Invitations list a project with accept, decline and ask', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1600));
    await tester.pumpWidget(_wrap(const InvitesScreen(), [
      invitationsProvider.overrideWith((ref) async => [
            {'id': 'i1', 'project_id': 'p1', 'project_name': 'Tema warehouse', 'public_code': 'PRJ-9Q', 'company_name': 'Ama Builders', 'invite_role': 'worker', 'trade_label': 'Mason', 'rate_ghs': 150, 'rate_unit': 'day', 'status': 'sent'},
          ]),
    ], type: 'worker'));
    await tester.pumpAndSettle();
    expect(find.text('Tema warehouse'), findsOneWidget);
    expect(find.text('Mason'), findsOneWidget);
    expect(find.text('GH₵150.00 per day'), findsOneWidget);
    expect(find.text('Accept'), findsOneWidget);
    expect(find.text('Ask a question'), findsOneWidget);
  });

  testWidgets('Approvals groups what the company must decide', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 2400));
    await tester.pumpWidget(_wrap(const ApprovalsScreen(), [
      approvalsProvider.overrideWith((ref) async => {
            'requests': [
              {'id': 'r1', 'project_name': 'Tema warehouse', 'title': 'Cement, 40 bags', 'amount_ghs': 3200, 'kind': 'material', 'requester_name': 'Yaw'},
            ],
            'payments': [],
            'workers': [],
            'reports': [],
            'completions': [],
          }),
    ]));
    await tester.pumpAndSettle();
    expect(find.text('Cement, 40 bags'), findsOneWidget);
    expect(find.text('GH₵3,200.00'), findsOneWidget);
    expect(find.text('Approve'), findsOneWidget);
    expect(find.text('Reject'), findsOneWidget);
  });

  testWidgets('nothing waiting shows the empty state', (tester) async {
    await tester.pumpWidget(_wrap(const ApprovalsScreen(), [approvalsProvider.overrideWith((ref) async => <String, dynamic>{})]));
    await tester.pumpAndSettle();
    expect(find.text('Nothing waiting'), findsOneWidget);
  });
}
