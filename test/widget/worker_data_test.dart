import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:baid_x_mobile/features/account_type/domain/account_type.dart';
import 'package:baid_x_mobile/features/auth/domain/auth_repository.dart';
import 'package:baid_x_mobile/features/auth/domain/auth_user.dart';
import 'package:baid_x_mobile/features/billing/data/billing_repository.dart';
import 'package:baid_x_mobile/features/billing/domain/billing_rules.dart';
import 'package:baid_x_mobile/features/billing/presentation/billing_providers.dart';
import 'package:baid_x_mobile/features/dashboard/domain/role_dashboard.dart';
import 'package:baid_x_mobile/features/dashboard/presentation/dashboard_providers.dart';
import 'package:baid_x_mobile/features/dashboard/presentation/role_dashboard_screen.dart';
import 'package:baid_x_mobile/features/jobs/domain/job_rules.dart';
import 'package:baid_x_mobile/features/jobs/presentation/job_providers.dart';
import 'package:baid_x_mobile/features/jobs/presentation/job_screens.dart';
import 'package:baid_x_mobile/features/profile/presentation/profile_screen.dart';
import 'package:baid_x_mobile/shared/providers/app_providers.dart';

void main() {
  testWidgets('worker dashboard leaves loading for data', (tester) async {
    await tester.pumpWidget(_dashboard(const RoleDashboard(name: 'Ama', location: 'Adenta', headline: '', completionPercent: 40)));
    await tester.pumpAndSettle();
    expect(find.text('Ama'), findsOneWidget);
    expect(find.text('Loading your dashboard'), findsNothing);
  });

  testWidgets('worker dashboard leaves loading for an error', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workerDashboardProvider.overrideWith((ref) async => throw StateError('policy')),
        ],
        child: const MaterialApp(home: RoleDashboardScreen(type: AccountType.worker)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Something went wrong. Unable to load your dashboard.'), findsOneWidget);
    expect(find.text('Loading your dashboard'), findsNothing);
  });

  testWidgets('worker profile leaves loading and shows actions', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(const AuthUser(id: 'u', email: 'a@b.co', emailConfirmed: true))),
          accountProfileProvider.overrideWith((ref) async => const AccountProfile(id: 'u', displayName: 'Ama', accountType: 'worker')),
          workerDashboardProvider.overrideWith((ref) async => const RoleDashboard(name: 'Ama', location: 'Adenta', headline: '', completionPercent: 40)),
          billingRepositoryProvider.overrideWithValue(_EmptyBilling()),
        ],
        child: const MaterialApp(home: ProfileScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ama'), findsOneWidget);
    expect(find.text('Verification'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
    expect(find.text('Loading your profile'), findsNothing);
    expect(find.text('Unable to load your profile.'), findsNothing);
  });

  testWidgets('jobs leave loading for data', (tester) async {
    await tester.pumpWidget(_jobs(const [
      JobRecord(id: '1', title: 'Blockwork in Adenta', description: 'Demo', locationLabel: 'Adenta', status: 'open', isPublic: true, ownerId: 'owner'),
    ]));
    await tester.pumpAndSettle();
    expect(find.text('Blockwork in Adenta'), findsOneWidget);
    expect(find.text('Loading jobs'), findsNothing);
  });

  testWidgets('jobs leave loading for an empty result', (tester) async {
    await tester.pumpWidget(_jobs(const []));
    await tester.pumpAndSettle();
    expect(find.text('No jobs available right now.'), findsOneWidget);
    expect(find.text('Loading jobs'), findsNothing);
  });

  testWidgets('jobs leave loading for an error', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          openJobsProvider.overrideWith((ref, query) async => throw StateError('policy')),
        ],
        child: const MaterialApp(home: JobsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Something went wrong. Check your connection and try again.'), findsOneWidget);
    expect(find.text('Loading jobs'), findsNothing);
  });

  testWidgets('applications leave loading for an empty result', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          myApplicationsProvider.overrideWith((ref) async => const []),
        ],
        child: const MaterialApp(home: ApplicationsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text("You haven't applied to any jobs yet."), findsOneWidget);
    expect(find.text('Loading applications'), findsNothing);
  });

  testWidgets('applications leave loading for an error', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          myApplicationsProvider.overrideWith((ref) async => throw StateError('policy')),
        ],
        child: const MaterialApp(home: ApplicationsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Something went wrong. Check your connection and try again.'), findsOneWidget);
    expect(find.text('Loading applications'), findsNothing);
  });
}

Widget _dashboard(RoleDashboard data) {
  return ProviderScope(
    overrides: [
      workerDashboardProvider.overrideWith((ref) async => data),
    ],
    child: const MaterialApp(home: RoleDashboardScreen(type: AccountType.worker)),
  );
}

Widget _jobs(List<JobRecord> rows) {
  return ProviderScope(
    overrides: [
      openJobsProvider.overrideWith((ref, query) async => rows),
    ],
    child: const MaterialApp(home: JobsScreen()),
  );
}

class _EmptyBilling implements BillingRepository {
  @override
  Future<bool> amReviewer() async => false;

  @override
  Future<Map<String, dynamic>?> activePromotion() async => null;

  @override
  Future<Map<String, dynamic>> beginPaystack(String reference) => throw UnimplementedError();

  @override
  Future<List<Map<String, dynamic>>> boostsFor(String targetId) async => const [];

  @override
  Future<List<Map<String, dynamic>>> catalog(String table, String accountType) async => const [];

  @override
  Future<Map<String, dynamic>> companyBilling() => throw UnimplementedError();

  @override
  Future<void> decideVerification(String id, String decision) => throw UnimplementedError();

  @override
  Future<BillingSnapshot> mine() => throw UnimplementedError();

  @override
  Future<List<Map<String, dynamic>>> myListings() async => const [];

  @override
  Future<List<Map<String, dynamic>>> myVerifications() async => const [];

  @override
  Future<List<Map<String, dynamic>>> myXid() async => const [];

  @override
  Future<List<Map<String, dynamic>>> payments() async => const [];

  @override
  Future<List<Map<String, dynamic>>> pendingReviews() async => const [];

  @override
  Future<List<PlanOffer>> plansFor(String accountType) async => const [];

  @override
  Future<void> requestCancellation() => throw UnimplementedError();

  @override
  Future<void> scheduleDowngrade(String planId) => throw UnimplementedError();

  @override
  Future<Map<String, dynamic>> startCheckout(Map<String, dynamic> args) => throw UnimplementedError();

  @override
  Future<void> startTrial() => throw UnimplementedError();
}
