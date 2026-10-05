import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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

    // visitors land on the member directory with the website's guest tabs
    expect(find.text('Chats'), findsWidgets);
    expect(find.text('Profile'), findsWidgets);
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
