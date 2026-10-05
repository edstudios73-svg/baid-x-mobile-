import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:baid_x_mobile/features/account/presentation/checklist_screens.dart';
import 'package:baid_x_mobile/features/auth/domain/auth_repository.dart';
import 'package:baid_x_mobile/features/auth/domain/auth_user.dart';
import 'package:baid_x_mobile/features/profile/presentation/profile_screen.dart';
import 'package:baid_x_mobile/shared/providers/app_providers.dart';

void main() {
  testWidgets('worker profile leaves loading and shows actions', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(const AuthUser(id: 'u', email: 'a@b.co', emailConfirmed: true))),
          accountProfileProvider.overrideWith((ref) async => const AccountProfile(id: 'u', displayName: 'Ama', accountType: 'worker')),
        ],
        child: MaterialApp(builder: (c, w) => MediaQuery(data: MediaQuery.of(c).copyWith(disableAnimations: true), child: w!), home: const ProfileScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ama'), findsOneWidget);
    // website account screen: the checklist card counts the worker's steps
    expect(find.text('Verification checklist'), findsOneWidget);
    expect(find.text('0/11'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Log out'), 300);
    expect(find.text('Log out'), findsOneWidget);
    expect(find.text('Unable to load your profile.'), findsNothing);
  });

  testWidgets('checklist lists the website steps with done and pending', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(const AuthUser(id: 'u', email: 'a@b.co', emailConfirmed: true))),
          accountProfileProvider.overrideWith((ref) async => const AccountProfile(id: 'u', displayName: 'Ama', accountType: 'worker', row: {'phone_number': '233201234567', 'full_name': 'Ama'})),
        ],
        child: MaterialApp(builder: (c, w) => MediaQuery(data: MediaQuery.of(c).copyWith(disableAnimations: true), child: w!), home: const ChecklistScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('BAID X verification'), findsOneWidget);
    expect(find.text('1 of 11 completed'), findsOneWidget);
    expect(find.text('Phone number'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
  });
}
