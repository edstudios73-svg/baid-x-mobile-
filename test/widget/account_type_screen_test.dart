import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:baid_x_mobile/core/theme/app_theme.dart';
import 'package:baid_x_mobile/features/account_type/presentation/account_type_screen.dart';

void main() {
  testWidgets('one account type is confirmed before it is saved', (tester) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          home: const AccountTypeScreen(),
        ),
      ),
    );

    expect(find.text('Continue'), findsOneWidget);
    final continueButton = tester.widget<FilledButton>(
      find.ancestor(of: find.text('Continue'), matching: find.byType(FilledButton)),
    );
    expect(continueButton.onPressed, isNull);

    await tester.tap(find.text('Professional'));
    await tester.pump();
    await tester.tap(find.text('Supplier'));
    await tester.pump();
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pump();

    expect(find.text('You selected Supplier.'), findsOneWidget);
    expect(find.text('You selected Professional.'), findsNothing);

    await tester.tap(find.text('Back'));
    await tester.pump();
    expect(find.text('How will you use BAID X?'), findsOneWidget);
  });
}
