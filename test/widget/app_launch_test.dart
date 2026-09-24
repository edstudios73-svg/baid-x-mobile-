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
    await tester.pumpAndSettle();

    expect(find.text('Marketplace'), findsWidgets);
  });

  testWidgets('listing a product asks a visitor to sign in', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
        ],
        child: const BaidXApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('List a product'));
    await tester.pumpAndSettle();

    expect(find.text('Sign in'), findsWidgets);
  });

  test('theme uses orange for primary actions', () {
    final theme = AppTheme.light;
    expect(
      theme.filledButtonTheme.style?.backgroundColor?.resolve({}),
      AppColors.orange,
    );
    expect(
      AppTheme.dark.filledButtonTheme.style?.backgroundColor?.resolve({}),
      AppColors.orange,
    );
  });
}
