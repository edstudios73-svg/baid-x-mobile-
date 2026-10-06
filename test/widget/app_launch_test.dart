import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:baid_x_mobile/features/account_type/domain/account_type.dart';

import 'package:baid_x_mobile/app.dart';
import 'package:baid_x_mobile/core/services/storage_service.dart';
import 'package:baid_x_mobile/core/theme/app_colors.dart';
import 'package:baid_x_mobile/core/theme/app_theme.dart';
import 'package:baid_x_mobile/shared/providers/app_providers.dart';

void main() {
  testWidgets('launch screen offers continue', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
        ],
        child: const BaidXApp(),
      ),
    );
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(seconds: 1));

    // visitors land on the entry: one panel per account type, each with sign in and create
    expect(find.text('Welcome to BAID X'), findsOneWidget);
    for (final t in AccountType.pickerOrder) {
      expect(find.text(t.label), findsOneWidget);
    }
    expect(find.text('Sign in'), findsNWidgets(5));
    expect(find.text('Create account'), findsNWidgets(5));

    // professional sign-in goes straight to the password step
    await tester.tap(find.text('Sign in').first);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('create account on a panel goes straight to the phone step', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
        ],
        child: const BaidXApp(),
      ),
    );
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(seconds: 1));
    await tester.ensureVisible(find.text('Create account').last);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Create account').last); // the Client panel
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Phone number'), findsOneWidget);
  });

  testWidgets('the guest profile offers both sign-in options', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
        ],
        child: const BaidXApp(),
      ),
    );
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(seconds: 1));
    await tester.ensureVisible(find.text('Explore BAID X first'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Explore BAID X first'));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Profile').last);
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('I\'m a professional'), findsOneWidget);
    expect(find.text('I\'m hiring'), findsOneWidget);
  });

  test('theme matches the website: black canvas, white actions, Inter', () {
    final theme = AppTheme.website;
    expect(theme.filledButtonTheme.style?.backgroundColor?.resolve({}), Colors.white);
    expect(theme.filledButtonTheme.style?.foregroundColor?.resolve({}), Colors.black);
    expect(AppColors.bg, const Color(0xFF050505));
    expect(theme.brightness, Brightness.dark);
  });
}
