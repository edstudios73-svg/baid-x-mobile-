import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:baid_x_mobile/features/directory/data/directory_repository.dart';
import 'package:baid_x_mobile/features/directory/presentation/directory_screen.dart';
import 'package:baid_x_mobile/shared/providers/app_providers.dart';
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

  testWidgets('member card: cover, kind, three fact tiles and the join date', (t) async {
    final m = DirectoryMember(group: 'professionals', kind: 'worker', id: 'w1', name: 'Ama Owusu', tag: 'Painter', place: 'Kumasi, Ashanti', desc: 'Painter and finisher.', stats: const [('GH₵220', 'Daily rate'), ('3 5', 'Experience')], cover: 'https://example.invalid/c.jpg', joined: DateTime(2026, 9, 3));
    await t.pumpWidget(ProviderScope(
      overrides: [accountProfileProvider.overrideWith((ref) async => null)],
      child: MaterialApp(home: Scaffold(body: SingleChildScrollView(child: MemberCard(member: m, signedIn: false)))),
    ));
    await t.pump();
    expect(find.text('PROFESSIONAL'), findsOneWidget);
    expect(find.text('Joined Sep 2026'), findsOneWidget);
    expect(find.text('Kumasi'), findsOneWidget);
    expect(find.text('Based in'), findsOneWidget);
    expect(find.text('3–5'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget, reason: 'the cover photo is shown');
  });
}
