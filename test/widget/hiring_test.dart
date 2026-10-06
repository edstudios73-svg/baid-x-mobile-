import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:baid_x_mobile/features/auth/domain/auth_repository.dart';
import 'package:baid_x_mobile/features/auth/domain/auth_user.dart';
import 'package:baid_x_mobile/features/hiring/build_screen.dart';
import 'package:baid_x_mobile/features/hiring/hiring_screens.dart';
import 'package:baid_x_mobile/features/hiring/house_screen.dart';
import 'package:baid_x_mobile/features/account/data/profile_data.dart' show supplierCatalogProvider;
import 'package:baid_x_mobile/features/account/presentation/profile_pages_b.dart' show SupplierScreen;
import 'package:baid_x_mobile/features/hiring/job_card_screen.dart';
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
      child: MaterialApp(builder: (c, w) => MediaQuery(data: MediaQuery.of(c).copyWith(disableAnimations: true), child: w!), home: child),
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
    expect(find.text('View job card'), findsOneWidget);
  });

  Json card(String party, {String status = 'active', List<Json> signoffs = const []}) => {
        'id': 'e1', 'card_no': 10482, 'public_id': 'BXD-ENG-42', 'title': 'Electrical installation', 'status': status, 'my_party': party,
        'needs_pm': true, 'project': 'East Legon villa', 'worker_name': 'Kwame Asante', 'client_name': 'ABC Construction', 'pm_name': 'Nana Osei',
        'location': 'East Legon, Greater Accra', 'amount': 4500, 'paid': 0, 'held': 4500, 'progress': 72, 'locked': signoffs.any((x) => x['party'] == 'worker'),
        'items': [
          {'id': 'i1', 'title': 'DB installation', 'total': 1, 'done': 1, 'mine': false},
          {'id': 'i2', 'title': 'Sockets', 'total': 12, 'done': 8, 'mine': true},
        ],
        'materials': [
          {'id': 'm1', 'name': '2.5 mm cable', 'unit': 'm', 'required': 100, 'used': 74, 'mine': false},
        ],
        'photos': <Json>[],
        'signoffs': signoffs,
      };

  testWidgets('the job card shows scope, materials, evidence, payments and sign-off for the worker', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 3200));
    await tester.pumpWidget(_wrap(const JobCardScreen(id: 'e1'), [
      jobCardProvider('e1').overrideWith((ref) async => card('worker', signoffs: [{'party': 'client', 'signed_at': '2026-10-06T09:00:00Z'}])),
    ], type: 'worker'));
    await tester.pumpAndSettle();
    expect(find.text('JOB #BX-10482'), findsOneWidget);
    expect(find.text('72%'), findsOneWidget);
    expect(find.text('8 of 12 done'), findsOneWidget);
    expect(find.text('67%'), findsOneWidget);
    expect(find.textContaining('used of 100 m', findRichText: true), findsOneWidget);
    for (final s in ['SCOPE', 'MATERIALS', 'EVIDENCE', 'PAYMENTS', 'COMPLETION']) {
      expect(find.text(s), findsOneWidget);
    }
    expect(find.text('No before photos'), findsOneWidget);
    expect(find.text('GH₵4,500.00'), findsNWidgets(2));
    expect(find.text('Tap an item to record how much is done.'), findsOneWidget);
    expect(find.text('Add scope item'), findsOneWidget);
    expect(find.text('Sign off: work complete'), findsOneWidget);
    expect(find.text('Report a problem'), findsOneWidget);
    expect(find.text('Decline job'), findsNothing, reason: 'someone has already signed off');
  });

  testWidgets('after the worker signs off the card locks and the client signs', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 3200));
    await tester.pumpWidget(_wrap(const JobCardScreen(id: 'e1'), [
      jobCardProvider('e1').overrideWith((ref) async => card('client', status: 'submitted', signoffs: [{'party': 'worker', 'signed_at': '2026-10-06T09:00:00Z'}])),
    ]));
    await tester.pumpAndSettle();
    expect(find.text('Awaiting sign-off'), findsOneWidget);
    expect(find.text('Add scope item'), findsNothing);
    expect(find.text('Add material'), findsNothing);
    expect(find.text('Sign off'), findsOneWidget, reason: 'the PM still has to sign, so this does not say release');
    expect(find.text('Waiting'), findsNWidgets(2));
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

  testWidgets('My build sums the job cards: spent of budget, escrow, waiting sign-offs and jobs', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 2400));
    await tester.pumpWidget(_wrap(const BuildScreen(), [
      myBuildProvider.overrideWith((ref) async => <String, dynamic>{
            'build': {'name': '4-bedroom house', 'location': 'Abuakwa, Kumasi', 'budget_ghs': 450000, 'due_on': '2027-03-31'},
            'paid': 264000, 'held': 48000, 'progress': 62,
            'waiting': [{'id': 'e1', 'card_no': 10490, 'title': 'Roof trusses', 'worker': 'Kofi Mensah', 'amount': 22000}],
            'jobs': [{'id': 'e1', 'card_no': 10490, 'title': 'Roof trusses', 'worker': 'Kofi Mensah', 'status': 'submitted', 'progress': 100, 'amount': 22000}],
            'photos': <Json>[],
          }),
    ]));
    await tester.pumpAndSettle();
    expect(find.text('4-bedroom house'), findsOneWidget);
    expect(find.text('GH₵264,000 of GH₵450,000'), findsOneWidget);
    expect(find.text('62%'), findsOneWidget);
    expect(find.text('GH₵312,000'), findsOneWidget, reason: 'committed = paid + held');
    expect(find.text('GH₵138,000'), findsOneWidget, reason: 'left in budget');
    expect(find.text('GH₵48,000'), findsOneWidget);
    expect(find.text('31 Mar 2027'), findsOneWidget);
    expect(find.text('Sign off: Roof trusses'), findsOneWidget);
    expect(find.text('JOBS IN THIS BUILD'), findsOneWidget);
    expect(find.text('Latest from site'.toUpperCase()), findsOneWidget);
  });

  testWidgets('My build without a build offers to set one up', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1600));
    await tester.pumpWidget(_wrap(const BuildScreen(), [
      myBuildProvider.overrideWith((ref) async => <String, dynamic>{'build': null, 'paid': 0, 'held': 0, 'progress': 0, 'waiting': <Json>[], 'jobs': <Json>[], 'photos': <Json>[]}),
    ]));
    await tester.pumpAndSettle();
    expect(find.text('Set up my build'), findsOneWidget);
    expect(find.text('Not set'), findsOneWidget);
    expect(find.text('No jobs yet'), findsOneWidget);
  });

  testWidgets('House logbook lists who did what, reminders with due labels, and the trusted team', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 2400));
    await tester.pumpWidget(_wrap(const HouseScreen(), [
      myHouseProvider.overrideWith((ref) async => <String, dynamic>{
            'history': [{'id': 'e1', 'card_no': 10495, 'title': 'Wiring and distribution board', 'worker': 'Kwame Asante', 'trade': 'Electrician', 'done_on': '2026-09-12T10:00:00Z'}],
            'reminders': [
              {'id': 'r1', 'title': 'Service the AC units', 'due_on': '2026-10-15', 'repeat_months': 6, 'worker_id': 'w3', 'worker': 'Kobby Frimpong', 'days': 9},
              {'id': 'r2', 'title': 'Clean the water tank', 'due_on': '2026-10-01', 'days': -5},
            ],
            'team': [{'worker_id': 'w1', 'name': 'Kwame Asante', 'trade': 'Electrician', 'jobs': 2, 'rating': 5}],
          }),
    ]));
    await tester.pumpAndSettle();
    expect(find.text('WHO DID WHAT'), findsOneWidget);
    expect(find.text('Kwame Asante · Electrician · Sep 2026'), findsOneWidget);
    expect(find.text('Due 15 Oct 2026 · every 6 months · with Kobby Frimpong'), findsOneWidget);
    expect(find.text('9 days'), findsOneWidget);
    expect(find.text('Overdue'), findsOneWidget);
    expect(find.text('Add reminder'), findsOneWidget);
    expect(find.text('Electrician · 2 jobs · you rated 5.0'), findsOneWidget);
    expect(find.text('Message'), findsOneWidget);
  });

  testWidgets('the marketplace shows listings as photo cards, filters by category and opens a gallery', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 2000));
    await tester.pumpWidget(_wrap(const SupplierScreen(kind: 'equipment'), [
      supplierCatalogProvider('equipment').overrideWith((ref) async => [
            {'id': 'a', 'business_id': 'b1', 'business': 'Asafo Plant Hire', 'verified': true, 'town': 'Kumasi', 'name': 'CAT 320 excavator', 'category': 'Excavators', 'daily_rate': 2800, 'condition': 'good', 'description': '20-tonne tracked excavator with operator.', 'images': <String>[]},
            {'id': 'b', 'business_id': 'b2', 'business': 'Tema Mixers', 'town': 'Tema', 'name': 'Concrete mixer', 'category': 'Mixers', 'daily_rate': 350, 'images': <String>[]},
          ]),
    ], type: 'worker'));
    await tester.pumpAndSettle();
    expect(find.text('CAT 320 excavator'), findsOneWidget);
    expect(find.text('Concrete mixer'), findsOneWidget);
    expect(find.text('Verified'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Mixers'));
    await tester.pumpAndSettle();
    expect(find.text('CAT 320 excavator'), findsNothing);
    await tester.tap(find.widgetWithText(ChoiceChip, 'All'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CAT 320 excavator'));
    await tester.pumpAndSettle();
    expect(find.text('No photos yet'), findsOneWidget);
    expect(find.text('20-tonne tracked excavator with operator.'), findsOneWidget);
    expect(find.text('Good condition'), findsOneWidget);
    expect(find.text('Message supplier'), findsOneWidget);
    expect(find.text('Rent'), findsOneWidget, reason: 'only the price label; workers get no Rent button because ordering through escrow is for companies and clients');
    expect(find.textContaining('Ordering through escrow is for company and client accounts'), findsOneWidget);
  });

  testWidgets('companies get Rent on a listing', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 2000));
    await tester.pumpWidget(_wrap(const SupplierScreen(kind: 'equipment'), [
      supplierCatalogProvider('equipment').overrideWith((ref) async => [
            {'id': 'a', 'business_id': 'b1', 'business': 'Asafo Plant Hire', 'name': 'CAT 320 excavator', 'daily_rate': 2800, 'images': <String>[]},
          ]),
    ], type: 'company'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CAT 320 excavator'));
    await tester.pumpAndSettle();
    expect(find.text('Rent'), findsNWidgets(2), reason: 'price label and the Rent button');
    expect(find.textContaining('Ordering through escrow'), findsNothing);
  });
}
