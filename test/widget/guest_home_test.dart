import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:baid_x_mobile/features/directory/data/directory_repository.dart';
import 'package:baid_x_mobile/features/directory/presentation/directory_screen.dart';
import 'package:baid_x_mobile/features/directory/presentation/people_console.dart';
import 'package:baid_x_mobile/features/directory/presentation/baid_bot.dart';
import 'package:baid_x_mobile/features/market/listing_gallery.dart';
import 'package:baid_x_mobile/features/tabs/presentation/tab_screens.dart' show JobCard;
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

  test('price guide: a trade needs 3 rates, odd rates are dropped; badge check finds verified members only', () {
    DirectoryMember w(String id, String trade, double? rate, String region, {String? badge}) =>
        DirectoryMember(group: 'professionals', kind: 'worker', id: id, name: id, tag: trade, place: region, desc: '', stats: const [], rate: rate, region: region, badge: badge);
    final all = [
      w('Ama Owusu', 'Electrician', 200, 'Ashanti', badge: 'identity'),
      w('Kofi', 'Electrician', 300, 'Greater Accra'),
      w('Yaw', 'Electrician', 250, 'Greater Accra'),
      w('Kwesi', 'Electrician', 2500, 'Greater Accra'),
      w('Esi', 'Mason', 150, 'Greater Accra'),
      w('Efua', 'Mason', 160, 'Greater Accra'),
      w('Abena', 'Mason', null, 'Volta'),
      w('Ama Owoo', 'Plumber', 180, 'Volta'),
    ];
    final ghana = tradeRates(all);
    expect(ghana.map((r) => r.trade), ['Electrician'], reason: 'Mason and Plumber have fewer than 3 rates');
    expect([ghana.first.median, ghana.first.low, ghana.first.high], [250, 200, 300], reason: 'GH₵2,500 is over 3 times the middle and is dropped');
    expect(tradeRates(all, region: 'Greater Accra'), isEmpty, reason: 'only 2 steady electrician rates in Greater Accra');
    expect(rateRegions(all), isEmpty, reason: 'no region has a trade with 3 rates');
    expect(checkMembers(all, 'ow').map((m) => m.id), isEmpty, reason: 'three letters or more');
    expect(checkMembers(all, 'ama ow').map((m) => m.id), ['Ama Owusu'], reason: 'unverified Ama Owoo is not listed');
  });

  testWidgets('BAID Bot: opens from the button, sends a suggested question, shows the answer', (t) async {
    List<Map<String, String>>? sent;
    await t.pumpWidget(ProviderScope(
      overrides: [
        baidBotAskProvider.overrideWithValue((messages, {viewer}) async {
          sent = messages;
          if (messages.last['content']!.contains('electrician')) {
            return const BotReply('Here are the strongest verified electricians in Accra, best match first.', [
              BotCard({'kind': 'worker', 'id': 'w1', 'name': 'Kwame Mensah', 'trade': 'Electrician', 'town': 'Accra', 'rate': 250, 'experience': '5-10', 'verified': true, 'badge': 'verified'}),
              BotCard({'kind': 'worker', 'id': 'w2', 'name': 'Kofi Boateng', 'trade': 'Electrician', 'town': 'Tema', 'verified': false}),
            ]);
          }
          return const BotReply('Escrow holds your money until you approve the work.');
        }),
      ],
      child: const MaterialApp(home: Scaffold(body: Center(child: BaidBotButton()))),
    ));
    await t.tap(find.byType(BaidBotButton));
    await t.pumpAndSettle();
    expect(find.text('BAID Bot'), findsOneWidget);
    expect(find.text('Find me a top electrician in Accra'), findsOneWidget, reason: 'visitors are offered searches first');
    await t.tap(find.text('How does escrow protect me?'));
    await t.pumpAndSettle();
    expect(sent, [{'role': 'user', 'content': 'How does escrow protect me?'}]);
    expect(find.text('Escrow holds your money until you approve the work.'), findsOneWidget);
    expect(find.text('How does escrow protect me?'), findsOneWidget, reason: 'the question stays as a bubble; the suggestions are gone');

    await t.enterText(find.byType(TextField), 'Find me a top electrician in Accra');
    await t.testTextInput.receiveAction(TextInputAction.send);
    await t.pumpAndSettle();
    expect(sent!.length, 3, reason: 'the conversation goes with the question; cards stay on this side');
    expect(find.byType(MemberCard), findsNWidgets(2), reason: 'matches are drawn as Discover member cards');
    expect(find.text('Kwame Mensah'), findsOneWidget);
    expect(find.text('2 PROFESSIONALS · 1 VERIFIED'), findsOneWidget);
    expect(find.text('Swipe for more'), findsOneWidget);
  });

  testWidgets('BAID Bot: jobs and equipment come back as Find work and marketplace cards', (t) async {
    await t.pumpWidget(ProviderScope(
      overrides: [
        baidBotAskProvider.overrideWithValue((messages, {viewer}) async => messages.last['content']!.contains('job')
            ? const BotReply('Here are the open jobs in Greater Accra.', [BotCard({'kind': 'job', 'id': 'j1', 'title': 'Wall Tilling', 'town': 'Accra', 'region': 'Greater Accra', 'rate': 200, 'workers_needed': 5})])
            : const BotReply('Here is the best excavator listing.', [BotCard({'kind': 'equipment', 'id': 'e1', 'name': 'Excavator', 'business': 'Baiden Creatives', 'town': 'Accra', 'daily_rate': 2500, 'verified': true})])),
      ],
      child: const MaterialApp(home: Scaffold(body: Center(child: BaidBotButton()))),
    ));
    await t.tap(find.byType(BaidBotButton));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'Any jobs in Accra?');
    await t.testTextInput.receiveAction(TextInputAction.send);
    await t.pumpAndSettle();
    expect(find.byType(JobCard), findsOneWidget);
    expect(find.text('Wall Tilling'), findsOneWidget);
    expect(find.text('Join to apply'), findsOneWidget, reason: 'a visitor joins to apply');
    await t.enterText(find.byType(TextField), 'Rent an excavator');
    await t.testTextInput.receiveAction(TextInputAction.send);
    await t.pumpAndSettle();
    expect(find.byType(ListingCard), findsOneWidget);
    expect(find.text('GH₵2,500/day', findRichText: true), findsOneWidget);
  });
}
