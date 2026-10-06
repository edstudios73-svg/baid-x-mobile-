import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:baid_x_mobile/features/directory/presentation/guest_home_hero.dart';

Widget _stage(double p) => MaterialApp(
  home: Scaffold(
    body: SizedBox(
      height: GuestTrustStage.height,
      child: GuestTrustStage(p: p, progress: p),
    ),
  ),
);

void main() {
  testWidgets('guest home: trust stack starts spread with the checks unticked', (t) async {
    await t.pumpWidget(_stage(0));
    expect(find.text('How a badge is earned'), findsOneWidget);
    expect(find.text('Profile reviewed'), findsNWidgets(2)); // the check and its glass layer
    final ticked = find.byWidgetPredicate((w) => w is AnimatedOpacity && w.opacity == 1);
    expect(ticked, findsNothing, reason: 'no check is ticked before scrolling');
    expect(find.text('Run the whole job'), findsNothing, reason: 'the old intro panel is gone');
  });

  testWidgets('guest home: scrolled through, one card and four ticked checks', (t) async {
    await t.pumpWidget(_stage(1));
    await t.pumpAndSettle();
    expect(find.text('Verified by BAID X'), findsOneWidget);
    expect(find.text('Profile reviewed'), findsOneWidget, reason: 'the layers under the card have faded out');
    expect(find.byWidgetPredicate((w) => w is AnimatedOpacity && w.opacity == 1), findsNWidgets(4));
    expect(find.byType(StatsPill), findsOneWidget);
  });
}
