import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:baid_x_mobile/features/directory/data/directory_repository.dart';
import 'package:baid_x_mobile/features/directory/presentation/directory_screen.dart';
import 'package:baid_x_mobile/features/directory/presentation/people_console.dart';
import 'package:baid_x_mobile/features/directory/presentation/baid_bot.dart';
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

  testWidgets('people console: no member numbers, verified share and filter taps', (t) async {
    DirectoryMember m(String g, String id, {String? badge}) => DirectoryMember(group: g, kind: 'worker', id: id, name: id, tag: '', place: 'Accra', desc: '', stats: const [], badge: badge);
    final members = [m('professionals', 'a', badge: 'verified'), m('professionals', 'b'), m('companies', 'c', badge: 'verified'), m('businesses', 'd')];
    String? picked;
    await t.pumpWidget(MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: PeopleConsole(members: members, filter: 'all', onFilter: (k) => picked = k, search: TextEditingController(), onSearch: (_) {}))),
    ));
    await t.pump(const Duration(seconds: 2)); // the live dot pulses forever, so wait out the meter instead of settling
    expect(find.textContaining('member'), findsNothing, reason: 'visitors never see how many people are on BAID X');
    for (final n in ['1', '2', '3', '4']) {
      expect(find.text(n), findsNothing);
    }
    expect(find.text('50%'), findsOneWidget, reason: 'two of four are verified');
    await t.tap(find.text('Suppliers'));
    expect(picked, 'businesses');
  });

  test('visitors see up to 4 verified members per type, each with a photo and a cover', () {
    DirectoryMember m(String g, String id, {String? badge = 'verified', String? image = 'p', String? cover = 'c', String desc = 'A careful, licensed electrician.'}) =>
        DirectoryMember(group: g, kind: 'worker', id: id, name: id, tag: '', place: 'Accra', desc: desc, stats: const [], badge: badge, image: image, cover: cover);
    final list = [
      m('professionals', 'short', desc: 'Pro.'),
      for (var i = 0; i < 5; i++) m('professionals', 'p$i'),
      m('professionals', 'unverified', badge: null),
      m('professionals', 'no-photo', image: null),
      m('companies', 'no-cover', cover: ''),
      m('companies', 'c0'),
    ];
    final shown = guestShowcase(list).map((e) => e.id).toList();
    expect(shown, ['p0', 'p1', 'p2', 'p3', 'c0'], reason: 'members with a written description come first; at most 4 per type');
  });

  test('price guide: middle rate and range per trade, by region; badge check by name', () {
    DirectoryMember w(String id, String trade, double? rate, String region) =>
        DirectoryMember(group: 'professionals', kind: 'worker', id: id, name: id, tag: trade, place: region, desc: '', stats: const [], rate: rate, region: region);
    final all = [w('Ama Owusu', 'Electrician', 200, 'Ashanti'), w('Kofi', 'Electrician', 300, 'Greater Accra'), w('Yaw', 'Electrician', 250, 'Greater Accra'), w('Esi', 'Mason', 150, 'Greater Accra'), w('Abena', 'Mason', null, 'Volta')];
    final ghana = tradeRates(all);
    expect(ghana.map((r) => r.trade), ['Electrician', 'Mason']);
    expect([ghana.first.median, ghana.first.low, ghana.first.high], [250, 200, 300]);
    final accra = tradeRates(all, region: 'Greater Accra');
    expect(accra.first.median, 275);
    expect(rateRegions(all), ['Ashanti', 'Greater Accra'], reason: 'only regions with a rate');
    expect(checkMembers(all, 'a').map((m) => m.id), isEmpty, reason: 'two letters or more');
    expect(checkMembers(all, 'ow').map((m) => m.id), ['Ama Owusu']);
  });

  testWidgets('BAID Bot: opens from the button, sends a suggested question, shows the answer', (t) async {
    List<Map<String, String>>? sent;
    await t.pumpWidget(ProviderScope(
      overrides: [
        baidBotAskProvider.overrideWithValue((messages) async {
          sent = messages;
          return 'Joining is free for every account type.';
        }),
      ],
      child: const MaterialApp(home: Scaffold(body: Center(child: BaidBotButton()))),
    ));
    await t.tap(find.byType(BaidBotButton));
    await t.pumpAndSettle();
    expect(find.text('BAID Bot'), findsOneWidget);
    await t.tap(find.text('Is BAID X free?'));
    await t.pumpAndSettle();
    expect(sent, [{'role': 'user', 'content': 'Is BAID X free?'}]);
    expect(find.text('Joining is free for every account type.'), findsOneWidget);
    expect(find.text('Is BAID X free?'), findsOneWidget, reason: 'the question stays as a bubble; the suggestions are gone');
  });
}
