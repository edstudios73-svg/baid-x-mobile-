import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:baid_x_mobile/core/constants/app_routes.dart';
import 'package:baid_x_mobile/features/account_type/domain/account_type.dart';
import 'package:baid_x_mobile/features/auth/domain/auth_repository.dart';
import 'package:baid_x_mobile/features/auth/domain/auth_user.dart';
import 'package:baid_x_mobile/features/billing/presentation/billing_providers.dart';
import 'package:baid_x_mobile/features/dashboard/domain/role_dashboard.dart';
import 'package:baid_x_mobile/features/dashboard/presentation/dashboard_providers.dart';
import 'package:baid_x_mobile/features/dashboard/presentation/role_dashboard_screen.dart';
import 'package:baid_x_mobile/features/messaging/presentation/messaging_providers.dart';
import 'package:baid_x_mobile/features/settings/presentation/settings_screen.dart';
import 'package:baid_x_mobile/shared/providers/app_providers.dart';

void main() {
  testWidgets('worker dashboard shows an empty state', (tester) async {
    await tester.pumpWidget(_dash(const RoleDashboard(name: 'Ama', location: '', headline: '', completionPercent: 20)));
    await tester.pumpAndSettle();
    expect(find.text('No jobs yet'), findsOneWidget);
    expect(find.text('Marketplace'), findsOneWidget);
    expect(find.text('Verified'), findsNothing);
  });

  testWidgets('the notification bell shows an unread count', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workerDashboardProvider.overrideWith((ref) async => const RoleDashboard(name: 'Ama', location: '', headline: '', completionPercent: 20)),
          unreadNotificationCountProvider.overrideWith((ref) async => 2),
        ],
        child: const MaterialApp(home: RoleDashboardScreen(type: AccountType.worker)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('dashboard shows a loader while data is loading', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workerDashboardProvider.overrideWith((ref) async {
            await Completer<void>().future;
            return const RoleDashboard(name: '', location: '', headline: '', completionPercent: 0);
          }),
        ],
        child: const MaterialApp(home: RoleDashboardScreen(type: AccountType.worker)),
      ),
    );
    await tester.pump();
    expect(find.text('Loading your dashboard'), findsOneWidget);
  });

  testWidgets('dashboard error hides the raw database message', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workerDashboardProvider.overrideWith((ref) => Future<RoleDashboard>.error(Exception('relation secret does not exist'))),
        ],
        child: const MaterialApp(home: RoleDashboardScreen(type: AccountType.worker)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Unable to load your dashboard'), findsOneWidget);
    expect(find.textContaining('secret'), findsNothing);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('settings signs out to the marketplace', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final auth = _FakeAuth();
    final router = GoRouter(
      initialLocation: AppRoutes.settings,
      routes: [
        GoRoute(path: AppRoutes.settings, builder: (_, _) => const SettingsScreen()),
        GoRoute(path: AppRoutes.marketplace, builder: (_, _) => const Text('Marketplace')),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          authStateProvider.overrideWith((ref) => Stream.value(const AuthUser(id: 'u', email: 'a@b.co', emailConfirmed: true))),
          reviewerFlagProvider.overrideWith((ref) async => false),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(auth.signedOut, isTrue);
    expect(find.text('Marketplace'), findsOneWidget);
  });
}

Widget _dash(RoleDashboard data) {
  return ProviderScope(
    overrides: [
      workerDashboardProvider.overrideWith((ref) async => data),
    ],
    child: const MaterialApp(home: RoleDashboardScreen(type: AccountType.worker)),
  );
}

class _FakeAuth implements AuthRepository {
  var signedOut = false;

  @override
  Future<void> signOut() async {
    signedOut = true;
  }

  @override
  AuthUser? get currentUser => null;

  @override
  Stream<AuthUser?> authStateChanges() => const Stream.empty();

  @override
  Future<AccountProfile?> loadProfile() async => null;

  @override
  Future<AuthUser?> refreshUser() async => null;

  @override
  Future<void> resendVerification(String email) async {}

  @override
  Future<void> sendPasswordReset(String email) async {}

  @override
  Future<void> setAccountType(String dbValue) async {}

  @override
  Future<AuthUser?> signIn({required String email, required String password}) async => null;

  @override
  Future<AuthUser?> signUp({
    required String displayName,
    required String email,
    required String password,
  }) async => null;

  @override
  Future<void> updatePassword(String password) async {}
}
