import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/supabase_config.dart';
import '../../../core/constants/app_routes.dart';
import '../../../shared/providers/app_providers.dart';
import '../data/directory_repository.dart';
import 'member_sheet.dart';

/// BAID Bot (website js/baidbot.js): a floating assistant on the visitor Home. Questions
/// go to the Supabase function "baid-bot", which answers with Claude and BAID X's facts,
/// and finds real people and open jobs ("a top electrician in Kumasi"): its picks come
/// back as cards under the answer.

/// One recommendation under an answer: a member (worker, pm, company, supplier) or an open job.
class BotCard {
  const BotCard(this.data);
  final Map<String, dynamic> data;

  String get kind => '${data['kind'] ?? 'worker'}';
  bool get isJob => kind == 'job';
  String get id => '${data['id'] ?? ''}';
  String get title => '${(isJob ? data['title'] : data['name']) ?? ''}';
  String get trade => '${data['trade'] ?? ''}';
  String? get place => [data['town'], data['region']].whereType<String>().where((v) => v.trim().isNotEmpty).toSet().join(', ').ifEmpty;
  num? get rate => data['rate'] is num ? data['rate'] as num : num.tryParse('${data['rate'] ?? ''}');
  bool get verified => data['verified'] == true;
  bool get featured => data['featured'] == true;
  String? get plan => data['plan'] as String?;
  String? get photo => data['photo'] as String?;
  num? get rating => data['rating'] is num ? data['rating'] as num : null;

  /// The facts on the card, most useful first.
  List<String> get facts => [
        if (rate != null) 'GH₵${rate!.round()} a day',
        if (!isJob && data['experience'] != null) '${data['experience']} yrs',
        if (rating != null) '${rating!.toStringAsFixed(1)} rating',
        if (isJob && data['workers_needed'] != null) '${data['workers_needed']} needed',
        if (isJob && data['posted_by'] != null) '${data['posted_by']}',
      ];

  DirectoryMember toMember() => DirectoryMember(
        group: switch (kind) { 'company' => 'companies', 'pm' => 'managers', 'supplier' => 'businesses', _ => 'professionals' },
        kind: kind == 'supplier' ? 'business' : kind,
        id: id,
        name: title,
        tag: trade,
        place: place ?? 'Ghana',
        desc: '${data['about'] ?? ''}'.trim().isEmpty ? '$trade on BAID X.' : '${data['about']}',
        stats: [
          (rate != null ? 'GH₵${rate!.round()}' : 'On request', 'Daily rate'),
          (data['experience'] != null ? '${data['experience']} yrs' : 'New', 'Experience'),
        ],
        image: photo,
        badge: data['badge'] as String?,
        region: data['region'] as String?,
        rate: rate?.toDouble(),
        plan: plan,
        boosted: featured,
      );
}

class BotReply {
  const BotReply(this.text, [this.cards = const []]);
  final String text;
  final List<BotCard> cards;
}

extension on String {
  String? get ifEmpty => isEmpty ? null : this;
}

typedef BotAsk = Future<BotReply> Function(List<Map<String, String>> messages);

/// How a question reaches the bot; tests replace it.
final baidBotAskProvider = Provider<BotAsk>(
  (ref) => (messages) async {
    final client = SupabaseConfig.client;
    if (client == null) throw StateError('not connected');
    final res = await client.functions.invoke(
      'baid-bot',
      body: {'messages': messages},
    );
    final data = res.data;
    final reply = data is Map ? data['reply'] : null;
    if (reply is! String || reply.trim().isEmpty) throw StateError('no reply');
    final cards = data is Map && data['cards'] is List ? (data['cards'] as List).whereType<Map>().map((m) => BotCard(Map<String, dynamic>.from(m))).toList() : <BotCard>[];
    return BotReply(reply.trim(), cards);
  },
);

const _greeting =
    "Hi, I'm BAID Bot. Tell me who you need and I'll find the best verified match, or ask me anything about BAID X.";
const _suggestions = [
  'Find me a top electrician in Accra',
  'I need a mason with experience',
  'Any jobs for me in Greater Accra?',
  'How does escrow protect me?',
];

class _Msg {
  _Msg(this.role, this.content, [this.cards = const []]);
  final String role;
  final String content;
  final List<BotCard> cards;
}

// the conversation lasts while the app is open, like the website's tab
final List<_Msg> _session = [];

/// The round white button that opens the chat.
class BaidBotButton extends StatelessWidget {
  const BaidBotButton({super.key});
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Ask BAID Bot',
    child: GestureDetector(
      onTap: () => openBaidBot(context),
      child: Container(
        width: 60,
        height: 60,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Color(0xB3000000),
              blurRadius: 40,
              spreadRadius: -10,
              offset: Offset(0, 18),
            ),
            BoxShadow(
              color: Color(0x73FFFFFF),
              blurRadius: 30,
              spreadRadius: -6,
            ),
          ],
        ),
        child: const Icon(
          Icons.smart_toy_outlined,
          color: Colors.black,
          size: 27,
        ),
      ),
    ),
  );
}

Future<void> openBaidBot(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  backgroundColor: Colors.transparent,
  // the bot draws its own glass panel: no theme sheet, handle or shadow behind it
  showDragHandle: false,
  elevation: 0,
  shape: const RoundedRectangleBorder(),
  constraints: const BoxConstraints(),
  barrierColor: const Color(0x99000000),
  builder: (_) => const _BotSheet(),
);

class _BotSheet extends ConsumerStatefulWidget {
  const _BotSheet();
  @override
  ConsumerState<_BotSheet> createState() => _BotSheetState();
}

class _BotSheetState extends ConsumerState<_BotSheet> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  var _busy = false;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _toEnd() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_scroll.hasClients) {
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  });

  Future<void> _ask(String text) async {
    final q = text.trim();
    if (q.isEmpty || _busy) return;
    final asked = q.length > 600 ? q.substring(0, 600) : q;
    setState(() {
      _session.add(_Msg('user', asked));
      _busy = true;
    });
    _toEnd();
    BotReply reply;
    try {
      final recent = (_session.length > 8 ? _session.sublist(_session.length - 8) : _session)
          .map((m) => {'role': m.role, 'content': m.content})
          .toList();
      reply = await ref.read(baidBotAskProvider)(recent);
    } catch (_) {
      reply = const BotReply("I couldn't reach BAID X just now. Check your connection and try again.");
    }
    if (!mounted) return;
    setState(() {
      _session.add(_Msg('assistant', reply.text, reply.cards));
      if (_session.length > 20) _session.removeRange(0, _session.length - 20);
      _busy = false;
    });
    _toEnd();
  }

  /// A person opens their profile; a job opens Find work (or sign-up for visitors).
  void _openCard(BotCard c) {
    final signedIn = ref.read(authStateProvider).asData?.value != null;
    final router = GoRouter.maybeOf(context);
    if (c.isJob) {
      Navigator.of(context).pop();
      router?.go(signedIn ? AppRoutes.work : AppRoutes.signUp);
      return;
    }
    showMemberSheet(context, member: c.toMember(), signedIn: signedIn);
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    const r = BorderRadius.all(Radius.circular(26));
    return Padding(
      padding: EdgeInsets.fromLTRB(
        8,
        0,
        8,
        8 + mq.viewInsets.bottom + mq.padding.bottom,
      ),
      child: SizedBox(
        height: (mq.size.height * .78).clamp(360.0, 640.0),
        child: ClipRRect(
          borderRadius: r,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: r,
                color: const Color(0xE00A0A0A),
                border: Border.all(color: const Color(0x38FFFFFF)),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.smart_toy_outlined,
                            color: Colors.black,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'BAID Bot',
                                style: TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Row(
                                children: [
                                  SizedBox(
                                    width: 6,
                                    height: 6,
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: Color(0xFF3DDC84),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      'Finds verified people and jobs',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFFA3A3A3),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Close',
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0x1AFFFFFF)),
                  Expanded(
                    child: ListView(
                      controller: _scroll,
                      padding: const EdgeInsets.all(14),
                      children: [
                        const _Bubble(text: _greeting, mine: false),
                        for (final m in _session) ...[
                          _Bubble(text: m.content, mine: m.role == 'user'),
                          if (m.cards.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Column(
                                children: [
                                  for (final (i, c) in m.cards.indexed)
                                    _CardIn(index: i, child: _MatchCard(card: c, top: i == 0 && !c.isJob, onTap: () => _openCard(c))),
                                ],
                              ),
                            ),
                        ],
                        if (_busy) const _Typing(),
                      ],
                    ),
                  ),
                  if (_session.isEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final s in _suggestions)
                            GestureDetector(
                              onTap: () => _ask(s),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0x0FFFFFFF),
                                  borderRadius: BorderRadius.circular(99),
                                  border: Border.all(
                                    color: const Color(0x2EFFFFFF),
                                  ),
                                ),
                                child: Text(
                                  s,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFFE6E6E6),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  const Divider(height: 1, color: Color(0x1AFFFFFF)),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 46,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            alignment: Alignment.centerLeft,
                            decoration: BoxDecoration(
                              color: const Color(0x73000000),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                color: const Color(0x2EFFFFFF),
                              ),
                            ),
                            child: TextField(
                              controller: _input,
                              maxLength: 600,
                              textInputAction: TextInputAction.send,
                              onSubmitted: (v) {
                                _input.clear();
                                _ask(v);
                              },
                              style: const TextStyle(
                                fontSize: 15,
                                color: Colors.white,
                              ),
                              decoration: const InputDecoration(
                                hintText: 'Who do you need?',
                                hintStyle: TextStyle(
                                  fontSize: 15,
                                  color: Color(0xFF7A7A7A),
                                ),
                                counterText: '',
                                filled: false,
                                isCollapsed: true,
                                contentPadding: EdgeInsets.zero,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Semantics(
                          button: true,
                          label: 'Send',
                          child: GestureDetector(
                            onTap: () {
                              final v = _input.text;
                              _input.clear();
                              _ask(v);
                            },
                            child: Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: const Icon(
                                Icons.arrow_forward_rounded,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(14, 2, 14, 10),
                    child: Text(
                      'BAID Bot can be wrong. Never share passwords or SMS codes.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: Color(0xFF7A7A7A)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.text, required this.mine});
  final String text;
  final bool mine;
  @override
  Widget build(BuildContext context) => Align(
    alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
    child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * .74,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        color: mine ? Colors.white : const Color(0x14FFFFFF),
        border: mine ? null : Border.all(color: const Color(0x1FFFFFFF)),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(mine ? 18 : 6),
          bottomRight: Radius.circular(mine ? 6 : 18),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          height: 1.45,
          color: mine ? Colors.black : Colors.white,
          fontWeight: mine ? FontWeight.w500 : FontWeight.w400,
        ),
      ),
    ),
  );
}

class _Typing extends StatelessWidget {
  const _Typing();
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0x14FFFFFF),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Text(
        'BAID Bot is typing…',
        style: TextStyle(fontSize: 12.5, color: Color(0xFFBDBDBD)),
      ),
    ),
  );
}

/// Cards rise in one after another under the answer.
class _CardIn extends StatelessWidget {
  const _CardIn({required this.index, required this.child});
  final int index;
  final Widget child;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: Duration(milliseconds: 380 + 90 * index),
    curve: Interval(index * .18 / (1 + index * .18), 1, curve: Curves.easeOutCubic),
    builder: (context, v, child) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, 12 * (1 - v)), child: child)),
    child: child,
  );
}

/// A recommended member or job: photo or initials, name, trade and place, badge, the
/// facts that decide (rate, experience, rating) and "Top match" on the first pick.
class _MatchCard extends StatelessWidget {
  const _MatchCard({required this.card, required this.top, required this.onTap});
  final BotCard card;
  final bool top;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = card;
    final initials = c.title.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).take(2).map((w) => w[0].toUpperCase()).join();
    return Semantics(
      button: true,
      label: '${c.title}, ${c.trade}${c.verified ? ', verified' : ''}',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(top: 6),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: top ? const Color(0x1AFFFFFF) : const Color(0x0DFFFFFF),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: top ? const Color(0x59FFFFFF) : const Color(0x24FFFFFF)),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(color: c.isJob ? const Color(0x1FFFFFFF) : Colors.white, borderRadius: BorderRadius.circular(c.isJob ? 14 : 23)),
                alignment: Alignment.center,
                child: c.isJob
                    ? const Icon(Icons.work_outline_rounded, color: Colors.white, size: 22)
                    : (c.photo != null
                          ? Image.network(c.photo!, width: 46, height: 46, fit: BoxFit.cover, errorBuilder: (_, _, _) => Text(initials, style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.black)))
                          : Text(initials, style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.black))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(child: Text(c.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: Colors.white))),
                        if (c.verified) const Padding(padding: EdgeInsets.only(left: 5), child: Icon(Icons.verified_rounded, size: 15, color: Colors.white)),
                        if (top) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(99)),
                            child: const Text('Top match', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.black)),
                          ),
                        ] else if (c.featured) ...[
                          const SizedBox(width: 6),
                          const Text('Featured', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFFBDBDBD))),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text([c.trade, ?c.place].join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Color(0xFFBDBDBD))),
                    if (c.facts.isNotEmpty || (!c.isJob && !c.verified)) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 5,
                        runSpacing: 5,
                        children: [
                          for (final f in c.facts)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: const Color(0x14FFFFFF), borderRadius: BorderRadius.circular(99)),
                              child: Text(f, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFE6E6E6))),
                            ),
                          if (!c.isJob && !c.verified)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(borderRadius: BorderRadius.circular(99), border: Border.all(color: const Color(0x33FFFFFF))),
                              child: const Text('Not verified yet', style: TextStyle(fontSize: 11, color: Color(0xFFBDBDBD))),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF8A8A8A)),
            ],
          ),
        ),
      ),
    );
  }
}
