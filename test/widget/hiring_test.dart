import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:baid_x_mobile/features/auth/domain/auth_repository.dart';
import 'package:baid_x_mobile/features/auth/domain/auth_user.dart';
import 'package:baid_x_mobile/features/hiring/hiring_screens.dart';
import 'package:baid_x_mobile/features/tabs/data/tabs_data.dart';
import 'package:baid_x_mobile/features/tabs/presentation/tab_screens.dart';
import 'package:baid_x_mobile/shared/providers/app_providers.dart';

Widget _wrap(Widget child, List overrides, {String type = 'individual-employer'}) => ProviderScope(
      retry: (_, _) => null,
      overrides: [
        authStateProvider.overrideWith((ref) => Stream.value(const AuthUser(id: 'u', email: 'a@b.co', emailConfirmed: true))),
        accountProfileProvider.overrideWith((ref) async => AccountProfile(id: 'u', displayName: 'Ama', accountType: type)),
        ...overrides.cast(),
      ],
      child: MaterialApp(home: child),
    );

void main() {
  testWidgets('Applicants list who applied with Message and Hire', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1800));
    await tester.pumpWidget(_wrap(const ApplicantsScreen(jobId: 'j1'), [
      jobApplicantsProvider('j1').overrideWith((ref) async => const ApplicantsData(
            {'id': 'j1', 'title': 'Electrician for a 3-bedroom house', 'status': 'open', 'daily_rate_ghs': 250, 'workers_needed': 1, 'city_town': 'Accra'},
            [
              {'application_id': 'a1', 'worker_id': 'w1', 'name': 'Kwame Mensah', 'trade': 'Electrician', 'verified': true, 'status': 'submitted', 'proposed_rate': 300, 'trust': 4.6, 'applied_at': '2026-10-01T10:00:00Z'},
              {'application_id': 'a2', 'worker_id': 'w2', 'name': 'Esi Owusu', 'trade': 'Electrician', 'status': 'accepted', 'engagement_id': 'e1', 'applied_at': '2026-10-01T10:00:00Z'},
            ],
          )),
    ]));
    await tester.pumpAndSettle();
    expect(find.text('Electrician for a 3-bedroom house'), findsOneWidget);
    expect(find.text('Kwame Mensah'), findsOneWidget);
    expect(find.text('GH₵300.00/day'), findsOneWidget);
    expect(find.text('4.6'), findsOneWidget);
    expect(find.text('Hire'), findsOneWidget);
    expect(find.text('View engagement'), findsOneWidget);
  });

  testWidgets('an engagement in progress shows escrow, steps and the payer actions', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 2000));
    await tester.pumpWidget(_wrap(const EngagementScreen(id: 'e1'), [
      myEngagementsProvider.overrideWith((ref) async => [
            {'id': 'e1', 'role': 'payer', 'title': 'Electrician for a 3-bedroom house', 'status': 'submitted', 'counterpart': 'Kwame Mensah', 'amount_ghs': 900, 'rate_ghs': 300, 'days': 3, 'public_id': 'ENG-42', 'submit_note': 'All sockets done.'},
          ]),
    ]));
    await tester.pumpAndSettle();
    expect(find.text('GH₵900.00'), findsOneWidget);
    expect(find.text('GH₵300.00 × 3 days'), findsOneWidget);
    expect(find.text('Awaiting approval'), findsOneWidget);
    expect(find.text('Approve and release payment'), findsOneWidget);
    expect(find.text('All sockets done.'), findsOneWidget);
    expect(find.text('Ref ENG-42'), findsOneWidget);
  });

  testWidgets('Hires lists hired professionals under the jobs', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1600));
    await tester.pumpWidget(_wrap(const HiresTabScreen(), [
      hiresTabProvider.overrideWith((ref) async => <Json>[]),
      myEngagementsProvider.overrideWith((ref) async => [
            {'id': 'e1', 'role': 'payer', 'title': 'Paint the fence', 'status': 'active', 'counterpart': 'Kofi', 'amount_ghs': 200, 'days': 1},
          ]),
    ]));
    await tester.pumpAndSettle();
    expect(find.text('HIRED PROFESSIONALS'), findsOneWidget);
    expect(find.text('Paint the fence'), findsOneWidget);
    expect(find.text('In progress'), findsOneWidget);
  });
}
