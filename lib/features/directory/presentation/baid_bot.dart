import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/supabase_config.dart';
import '../../../core/constants/app_routes.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/baid_ui.dart';
import '../../account_type/domain/account_type.dart';
import '../../market/listing_gallery.dart';
import '../../tabs/data/tabs_data.dart' show Json;
import '../../tabs/presentation/tab_screens.dart' show JobCard;
import '../data/directory_repository.dart';
import 'directory_screen.dart' show MemberCard;

/// BAID Bot (website js/baidbot.js): the assistant on the visitor Home (round button) and on
/// every member screen (the button beside the bell). Questions go to the Supabase function
/// "baid-bot", which answers with Claude and BAID X's facts and finds real people, open jobs,
/// equipment and materials. The answer is one short line; the matches come back as cards and
/// are drawn with the app's own cards (Discover's MemberCard, Find work's JobCard, the
/// marketplace's ListingCard) in a row you swipe.

/// One match under an answer: a member (worker, pm, company, supplier), an open job, or an
/// equipment or material listing.
class BotCard {
  const BotCard(this.data);
  final Map<String, dynamic> data;

  String get kind => '${data['kind'] ?? 'worker'}';
  bool get isJob => kind == 'job';
  bool get isListing => kind == 'equipment' || kind == 'material';
  bool get isMember => !isJob && !isListing;
  String get id => '${data['id'] ?? ''}';
  String get title => '${(isJob ? data['title'] : data['name']) ?? ''}';
  String get trade => '${data['trade'] ?? ''}';
  String? get place => [data['town'], data['region']]
      .whereType<String>()
      .where((v) => v.trim().isNotEmpty)
      .toSet()
      .join(', ')
      .ifEmpty;
  num? get rate => data['rate'] is num
      ? data['rate'] as num
      : num.tryParse('${data['rate'] ?? ''}');
  bool get verified => data['verified'] == true;
  bool get featured => data['featured'] == true;
  String? get plan => data['plan'] as String?;
  String? get photo => data['photo'] as String?;

  /// The member as Discover would show them, when their live row isn't loaded.
  DirectoryMember toMember() => DirectoryMember(
    group: switch (kind) {
      'company' => 'companies',
      'pm' => 'managers',
      'supplier' => 'businesses',
      _ => 'professionals',
    },
    kind: kind == 'supplier' ? 'business' : kind,
    id: id,
    name: title,
    tag: trade,
    place: place ?? 'Ghana',
    desc: '${data['about'] ?? ''}'.trim().isEmpty
        ? '$trade on BAID X.'
        : '${data['about']}',
    stats: [
      (rate != null ? 'GH₵${rate!.round()}' : 'On request', 'Daily rate'),
      (
        data['experience'] != null ? '${data['experience']}' : 'New',
        'Experience',
      ),
    ],
    image: photo,
    badge: data['badge'] as String?,
    region: data['region'] as String?,
    rate: rate?.toDouble(),
    plan: plan,
    boosted: featured,
  );

  /// The job as Find work's card reads it.
  Json toJob() => {
    'id': id,
    'title': title,
    'description': data['about'],
    'city_town': data['town'],
    'region': data['region'],
    'daily_rate_ghs': data['rate'],
    'workers_needed': data['workers_needed'],
    'created_at': data['created_at'],
    'job_category_id': data['job_category_id'],
    'boosted': featured,
  };
}

class BotReply {
  const BotReply(this.text, [this.cards = const []]);
  final String text;
  final List<BotCard> cards;
}

extension on String {
  String? get ifEmpty => isEmpty ? null : this;
}

/// Sends the conversation (and the member's account type, so suggestions fit) and returns the reply.
typedef BotAsk = Future<BotReply> Function(
  List<Map<String, String>> messages, {
  String? viewer,
});

/// How a question reaches the bot; tests replace it.
final baidBotAskProvider = Provider<BotAsk>(
  (ref) => (messages, {viewer}) async {
    final client = SupabaseConfig.client;
    if (client == null) throw StateError('not connected');
    final res = await client.functions.invoke(
      'baid-bot',
      body: {'messages': messages, 'viewer': ?viewer},
    );
    final data = res.data;
    final reply = data is Map ? data['reply'] : null;
    if (reply is! String || reply.trim().isEmpty) throw StateError('no reply');
    final cards = data is Map && data['cards'] is List
        ? (data['cards'] as List)
              .whereType<Map>()
              .map((m) => BotCard(Map<String, dynamic>.from(m)))
              .toList()
        : <BotCard>[];
    return BotReply(reply.trim(), cards);
  },
);

const _greeting =
    "Good to see you. Tell me who or what you need, a trade, a town, a budget, and I'll bring you the best verified matches on BAID X.";
const _suggestions = {
  null: [
    'Find me a top electrician in Accra',
    'I need an experienced mason',
    'Rent an excavator in Accra',
    'How does escrow protect me?',
  ],
  AccountType.worker: [
    'Any jobs for me in Greater Accra?',
    'Find electrical jobs near me',
    'How do I get verified?',
    'How do I get paid?',
  ],
  AccountType.company: [
    'Find a project manager in Accra',
    'Top verified masons',
    'Rent an excavator',
    'Suppliers of cement blocks',
  ],
  AccountType.projectManager: [
    'Find verified electricians',
    'Masons in Accra',
    'Rent a concrete mixer',
    'Cement suppliers',
  ],
  AccountType.business: [
    'Show me open jobs',
    'Companies in Accra',
    'How do boosts work?',
    'How do I get verified?',
  ],
  AccountType.employer: [
    'Find a plumber near me',
    'Top verified electricians',
    'Find a painter in Accra',
    'How does escrow protect me?',
  ],
};

class _Msg {
  _Msg(this.role, this.content, [this.cards = const []]);
  final String role;
  final String content;
  final List<BotCard> cards;
}

// the conversation lasts while the app is open, like the website's tab
final List<_Msg> _session = [];

const _sparkle = Icons.auto_awesome_outlined;

/// The round white button that opens the chat (visitor Home).
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
        child: const Icon(_sparkle, color: Colors.black, size: 26),
      ),
    ),
  );
}

/// The glass button beside the bell on member screens.
class BaidBotHeaderButton extends StatelessWidget {
  const BaidBotHeaderButton({super.key});
  @override
  Widget build(BuildContext context) => GlassIconButton(
    icon: _sparkle,
    tooltip: 'Ask BAID Bot',
    onTap: () => openBaidBot(context),
  );
}

/// Opens BAID Bot; with [ask] it asks that question straight away.
Future<void> openBaidBot(BuildContext context, {String? ask}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  backgroundColor: Colors.transparent,
  // the bot draws its own glass panel: no theme sheet, handle or shadow behind it
  showDragHandle: false,
  elevation: 0,
  shape: const RoundedRectangleBorder(),
  constraints: const BoxConstraints(),
  barrierColor: const Color(0x99000000),
  builder: (_) => _BotSheet(ask: ask),
);

class _BotSheet extends ConsumerStatefulWidget {
  const _BotSheet({this.ask});
  final String? ask;
  @override
  ConsumerState<_BotSheet> createState() => _BotSheetState();
}

class _BotSheetState extends ConsumerState<_BotSheet> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  var _busy = false;

  AccountType? get _type =>
      ref.read(accountProfileProvider).asData?.value?.type;

  @override
  void initState() {
    super.initState();
    final q = widget.ask;
    if (q != null && q.isNotEmpty) WidgetsBinding.instance.addPostFrameCallback((_) => _ask(q));
  }

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
      final recent =
          (_session.length > 8
                  ? _session.sublist(_session.length - 8)
                  : _session)
              .map((m) => {'role': m.role, 'content': m.content})
              .toList();
      reply = await ref.read(baidBotAskProvider)(
        recent,
        viewer: _type?.webRole,
      );
    } catch (_) {
      reply = const BotReply(
        "I couldn't reach BAID X just now. Check your connection and try again.",
      );
    }
    if (!mounted) return;
    setState(() {
      _session.add(_Msg('assistant', reply.text, reply.cards));
      if (_session.length > 20) _session.removeRange(0, _session.length - 20);
      _busy = false;
    });
    _toEnd();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    const r = BorderRadius.all(Radius.circular(26));
    final signedIn = ref.watch(authStateProvider).asData?.value != null;
    final members = {
      for (final m
          in ref.watch(directoryProvider).asData?.value ??
              const <DirectoryMember>[])
        m.id: m,
    };
    return Padding(
      padding: EdgeInsets.fromLTRB(
        8,
        0,
        8,
        8 + mq.viewInsets.bottom + mq.padding.bottom,
      ),
      child: SizedBox(
        height: (mq.size.height * .88).clamp(380.0, 760.0),
        child: ClipRRect(
          borderRadius: r,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: r,
                color: const Color(0xE80A0A0A),
                border: Border.all(color: const Color(0x38FFFFFF)),
              ),
              child: Column(
                children: [
                  _Head(onNew: () => setState(_session.clear)),
                  const Divider(height: 1, color: Color(0x1AFFFFFF)),
                  Expanded(
                    child: ListView(
                      controller: _scroll,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      children: [
                        const _Bubble(text: _greeting, mine: false),
                        for (final m in _session) ...[
                          _Bubble(text: m.content, mine: m.role == 'user'),
                          if (m.cards.isNotEmpty)
                            _Results(
                              cards: m.cards,
                              members: members,
                              signedIn: signedIn,
                              type: _type,
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
                          for (final s
                              in _suggestions[_type] ?? _suggestions[null]!)
                            _Suggestion(s, onTap: () => _ask(s)),
                        ],
                      ),
                    ),
                  const Divider(height: 1, color: Color(0x1AFFFFFF)),
                  _Composer(
                    controller: _input,
                    onSend: () {
                      final v = _input.text;
                      _input.clear();
                      _ask(v);
                    },
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(14, 2, 14, 10),
                    child: Text(
                      'Matches come from live profiles. Never share passwords or SMS codes.',
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

class _Head extends StatelessWidget {
  const _Head({required this.onNew});
  final VoidCallback onNew;
  @override
  Widget build(BuildContext context) => Padding(
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
          child: const Icon(_sparkle, color: Colors.black, size: 22),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'BAID Bot',
                style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800),
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
                      'People, jobs and equipment',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: Color(0xFFA3A3A3)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'New conversation',
          onPressed: onNew,
          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
        ),
        IconButton(
          tooltip: 'Close',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_rounded, color: Colors.white),
        ),
      ],
    ),
  );
}

class _Suggestion extends StatelessWidget {
  const _Suggestion(this.text, {required this.onTap});
  final String text;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0x0FFFFFFF),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: const Color(0x2EFFFFFF)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: Color(0xFFE6E6E6),
        ),
      ),
    ),
  );
}

class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.onSend});
  final TextEditingController controller;
  final VoidCallback onSend;
  @override
  Widget build(BuildContext context) => Padding(
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
              border: Border.all(color: const Color(0x2EFFFFFF)),
            ),
            child: TextField(
              controller: controller,
              maxLength: 600,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              style: const TextStyle(fontSize: 15, color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Who or what do you need?',
                hintStyle: TextStyle(fontSize: 15, color: Color(0xFF7A7A7A)),
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
            onTap: onSend,
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
  );
}

/// The matches under an answer: a small label ("2 professionals · 2 verified · Accra"), then
/// the app's own cards in a row that snaps card by card.
class _Results extends StatelessWidget {
  const _Results({
    required this.cards,
    required this.members,
    required this.signedIn,
    required this.type,
  });
  final List<BotCard> cards;
  final Map<String, DirectoryMember> members;
  final bool signedIn;
  final AccountType? type;

  static const _noun = {
    'worker': ('professional', 'professionals'),
    'pm': ('project manager', 'project managers'),
    'company': ('company', 'companies'),
    'supplier': ('supplier', 'suppliers'),
    'job': ('open job', 'open jobs'),
    'equipment': ('equipment listing', 'equipment listings'),
    'material': ('material listing', 'material listings'),
  };

  String get _label {
    final first = cards.first, n = _noun[first.kind] ?? ('match', 'matches');
    final verified = cards.where((c) => c.verified).length;
    final place = first.data['town'] ?? first.data['region'];
    final samePlace =
        place != null &&
        cards.every((c) => (c.data['town'] ?? c.data['region']) == place);
    return [
      '${cards.length} ${cards.length == 1 ? n.$1 : n.$2}',
      if (first.isMember && verified > 0) '$verified verified',
      if (samePlace) '$place',
    ].join(' · ').toUpperCase();
  }

  void _go(BuildContext context, String route) {
    final router = GoRouter.maybeOf(context);
    Navigator.of(context).pop();
    router?.go(route);
  }

  Widget _card(BuildContext context, BotCard c) {
    if (c.isMember) {
      return MemberCard(
        member: members[c.id] ?? c.toMember(),
        signedIn: signedIn,
      );
    }
    if (c.isJob) {
      final worker = type == AccountType.worker;
      return JobCard(
        job: c.toJob(),
        actionLabel: worker ? 'View and apply' : 'Join to apply',
        onApply: worker
            ? () => _go(context, AppRoutes.work)
            : (signedIn ? null : () => _go(context, AppRoutes.signUp)),
      );
    }
    final eq = c.kind == 'equipment';
    final (price, per) = listingPrice(c.data, equipment: eq);
    return ListingCard(
      item: c.data,
      equipment: eq,
      price: price,
      per: per,
      onTap: () => _go(
        context,
        signedIn
            ? (eq ? AppRoutes.equipment : AppRoutes.materials)
            : AppRoutes.signUp,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _label,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.3,
                      color: Color(0xFFD6D6D6),
                    ),
                  ),
                ),
                if (cards.length > 1)
                  const Text(
                    'Swipe for more',
                    style: TextStyle(fontSize: 11.5, color: Color(0xFF8A8A8A)),
                  ),
              ],
            ),
          ),
          LayoutBuilder(
            builder: (context, box) {
              const gap = 12.0, side = 14.0;
              final one = cards.length == 1;
              final w = one
                  ? box.maxWidth - side * 2
                  : (box.maxWidth - side) * (cards.first.isMember ? .86 : .78);
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(side, 4, side, 4),
                physics: one
                    ? const NeverScrollableScrollPhysics()
                    : _SnapPhysics(extent: w + gap),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final (i, c) in cards.indexed) ...[
                      if (i > 0) const SizedBox(width: gap),
                      _CardIn(
                        index: i,
                        child: SizedBox(width: w, child: _card(context, c)),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Settles a fling on the nearest card, like the website's scroll snap.
class _SnapPhysics extends ScrollPhysics {
  const _SnapPhysics({required this.extent, super.parent});
  final double extent;

  @override
  _SnapPhysics applyTo(ScrollPhysics? ancestor) =>
      _SnapPhysics(extent: extent, parent: buildParent(ancestor));

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    if ((velocity <= 0 && position.pixels <= position.minScrollExtent) ||
        (velocity >= 0 && position.pixels >= position.maxScrollExtent)) {
      return super.createBallisticSimulation(position, velocity);
    }
    final tol = toleranceFor(position);
    var page = position.pixels / extent;
    if (velocity < -tol.velocity) {
      page -= .5;
    } else if (velocity > tol.velocity) {
      page += .5;
    }
    final target = (page.roundToDouble() * extent).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if ((target - position.pixels).abs() < tol.distance) return null;
    return ScrollSpringSimulation(
      spring,
      position.pixels,
      target,
      velocity,
      tolerance: tol,
    );
  }

  @override
  bool get allowImplicitScrolling => false;
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.text, required this.mine});
  final String text;
  final bool mine;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14),
    child: Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * .78,
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
    ),
  );
}

class _Typing extends StatelessWidget {
  const _Typing();
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0x14FFFFFF),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Text(
          'Searching live profiles…',
          style: TextStyle(fontSize: 12.5, color: Color(0xFFBDBDBD)),
        ),
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
    duration: Duration(milliseconds: 420 + 80 * index),
    curve: Interval(
      index * .16 / (1 + index * .16),
      1,
      curve: Curves.easeOutCubic,
    ),
    builder: (context, v, child) => Opacity(
      opacity: v,
      child: Transform.translate(offset: Offset(0, 14 * (1 - v)), child: child),
    ),
    child: child,
  );
}

/// BAID Bot on every member Home (website js/dash.js aiBar): a field that opens it and two
/// questions that fit the account.
class BotPromptBar extends StatelessWidget {
  const BotPromptBar({required this.type, super.key});
  final AccountType? type;

  static const _bars = {
    AccountType.worker: ('Ask for jobs near you, or anything about BAID X', ['Any jobs for me near me?', 'How do I get verified?']),
    AccountType.company: ('Find verified pros, project managers or equipment', ['Find a project manager in Accra', 'Rent an excavator']),
    AccountType.projectManager: ('Build your crew with verified professionals', ['Find verified masons', 'Cement suppliers near me']),
    AccountType.business: ('Find companies, projects and open jobs', ['Companies in Accra', 'How do boosts work?']),
    AccountType.employer: ('Who do you need for your home?', ['Find a plumber near me', 'Top verified electricians']),
  };

  @override
  Widget build(BuildContext context) {
    final (hint, qs) = _bars[type] ?? _bars[AccountType.worker]!;
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            label: 'Ask BAID Bot',
            child: GestureDetector(
              onTap: () => openBaidBot(context),
              child: Container(
                constraints: const BoxConstraints(minHeight: 56),
                padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0x24FFFFFF), Color(0x0AFFFFFF), Color(0x14FFFFFF)], stops: [0, .6, 1]),
                  border: Border.all(color: const Color(0x42FFFFFF)),
                  boxShadow: const [BoxShadow(color: Color(0xCC000000), blurRadius: 40, spreadRadius: -18, offset: Offset(0, 18))],
                ),
                child: Row(children: [
                  Container(width: 36, height: 36, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)), child: const Icon(_sparkle, size: 18, color: Colors.black)),
                  const SizedBox(width: 12),
                  Expanded(child: Text(hint, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, color: Color(0xFFCFCFCF)))),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: const Color(0x1AFFFFFF), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0x2EFFFFFF))),
                    child: const Icon(Icons.arrow_forward_rounded, size: 18, color: Colors.white),
                  ),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [for (final q in qs) _Suggestion(q, onTap: () => openBaidBot(context, ask: q))]),
        ],
      ),
    );
  }
}
