import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/baid_ui.dart';
import '../../../shared/widgets/dash_ui.dart';
import '../../../shared/widgets/verified_badge.dart';
import '../../tabs/data/tabs_data.dart';
import '../data/profile_data.dart';
import 'account_sheets.dart';
import 'profile_pages.dart';
import 'profile_pages_b.dart' show cedi, accessPlanText;

/// Plans & billing, same layout and wording as the website (js/billing.js, css/billing.css):
/// Plans (your plan, monthly/yearly, plan cards, compare table), Services (Boosts,
/// Verification, Fees) and Payments.

const _tierName = {
  'access': 'Access',
  'pro': 'Pro',
  'premium': 'Premium',
  'enterprise': 'Enterprise',
};
const _cap = {
  'org_members': 'people in your organization',
  'active_projects': 'active projects',
  'job_postings_per_month': 'job posts a month',
  'org_admins': 'organization admins',
  'collaborators_per_project': 'collaborators per project',
};
const _status = {
  'active': 'Active',
  'trialing': 'Trial',
  'grace_period': 'Payment due',
  'past_due': 'Payment due',
  'cancel_at_period_end': 'Ends soon',
  'cancelled': 'Cancelled',
  'expired': 'Expired',
  'suspended': 'Paused',
};
const _payStatus = {
  'successful': 'Paid',
  'pending': 'Not paid',
  'processing': 'Checking',
  'failed': 'Failed',
  'refunded': 'Refunded',
  'partially_refunded': 'Part refunded',
  'cancelled': 'Cancelled',
  'disputed': 'Disputed',
  'reversed': 'Reversed',
};
const _live = [
  'active',
  'trialing',
  'grace_period',
  'past_due',
  'cancel_at_period_end',
];

String _date(Object? iso) {
  final t = DateTime.tryParse('${iso ?? ''}');
  if (t == null) return '—';
  const m = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${t.day} ${m[t.month - 1]} ${t.year}';
}

/// "1 day", "3 days" (website `dur`).
String boostDuration(num hours) => hours < 48
    ? (hours == 24 ? '1 day' : '$hours hours')
    : '${(hours / 24).round()} days';

/// Website compareRows: only what each plan really changes. `true`/`false` draw a
/// tick or a dash; text is shown as it is.
List<(String, List<Object>)> billingCompareRows(
  String role,
  List<String> tiers,
) {
  List<Object> t(Map<String, Object> v) => [
    for (final k in ['access', ...tiers]) v[k]!,
  ];
  return [
    if (role == 'worker')
      (
        'Job applications',
        t({
          'access': '5 a month',
          'pro': 'Unlimited',
          'premium': 'Unlimited',
          'enterprise': 'Unlimited',
        }),
      ),
    if (role == 'company' || role == 'individual-employer')
      (
        'Open job posts',
        t({
          'access': '1 at a time',
          'pro': 'Unlimited',
          'premium': 'Unlimited',
          'enterprise': 'Unlimited',
        }),
      ),
    (
      'Mark beside your name',
      t({
        'access': false,
        'pro': 'Pro',
        'premium': 'Premium',
        'enterprise': 'Enterprise',
      }),
    ),
    (
      'Place in Discover',
      t({
        'access': 'Standard',
        'pro': 'Before free',
        'premium': 'Above Pro',
        'enterprise': 'Top of paid',
      }),
    ),
    (
      'Support',
      t({
        'access': 'Standard',
        'pro': 'Priority',
        'premium': 'First in line',
        'enterprise': 'Named contact',
      }),
    ),
    if (tiers.contains('enterprise'))
      (
        'Team organization',
        t({
          'access': false,
          'pro': false,
          'premium': false,
          'enterprise': true,
        }),
      ),
  ];
}

const _verTier = {
  'identity': 'identity',
  'standard': 'identity',
  'professional': 'professional',
  'advanced': 'advanced',
  'enhanced': 'advanced',
};
const _verChecks = {
  'identity': [
    'Your Ghana Card is checked against your profile',
    'Green badge on your profile and cards',
  ],
  'standard': [
    'Business registration and TIN checked',
    'Green badge on your profile and cards',
  ],
  'professional': [
    'Ghana Card, trade certificates and past work checked',
    'Purple badge on your profile and cards',
  ],
  'advanced': [
    'Everything in Professional',
    'References and a background check',
    'White badge, the highest BAID X gives',
  ],
  'enhanced': [
    'Everything in the standard check',
    'A deeper check of the owners and past work',
    'White badge, the highest BAID X gives',
  ],
};

// ---------------------------------------------------------------- glass pieces
const _line = Color(0x2EFFFFFF);
const _mut = Color(0xFFA3A3A3);

class _Glass extends StatelessWidget {
  const _Glass({
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.current = false,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool current;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xA80E0E0E), Color(0x660E0E0E), Color(0x1AFFFFFF)],
          stops: [0, .55, 1],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: current ? Colors.white : _line,
          width: current ? 2 : 1.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 40,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: child,
    ),
  );
}

/// Website `.bl-seg`: equal-width options, the chosen one solid white with black text.
class BillingSeg extends StatelessWidget {
  const BillingSeg({
    required this.items,
    required this.active,
    required this.onTap,
    this.small = false,
    super.key,
  });
  final List<(String, String, String?)> items; // key, label, tag
  final String active;
  final ValueChanged<String> onTap;
  final bool small;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0x800E0E0E),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _line, width: 1.5),
      ),
      child: Row(
        children: [
          for (final (k, l, tag) in items)
            Expanded(
              child: Semantics(
                selected: k == active,
                button: true,
                child: GestureDetector(
                  onTap: () => onTap(k),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: small ? 38 : 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: k == active ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            l,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: small ? 13 : 13.5,
                              fontWeight: FontWeight.w700,
                              color: k == active
                                  ? Colors.black
                                  : const Color(0xFFD4D4D4),
                            ),
                          ),
                        ),
                        if (tag != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: k == active
                                  ? Colors.black
                                  : const Color(0x1FFFFFFF),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              tag,
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class _Pill extends StatelessWidget {
  const _Pill(this.label, {this.tone = ''});
  final String label;
  final String tone; // ok | warn | bad
  @override
  Widget build(BuildContext context) {
    final (bg, line, fg) = switch (tone) {
      'ok' => (
        const Color(0x1F34D399),
        const Color(0x6634D399),
        const Color(0xFF6EE7B7),
      ),
      'bad' => (
        const Color(0x1FF87171),
        const Color(0x66F87171),
        const Color(0xFFFCA5A5),
      ),
      'warn' => (
        const Color(0x24FFFFFF),
        const Color(0x66FFFFFF),
        Colors.white,
      ),
      _ => (
        const Color(0x1AFFFFFF),
        const Color(0x38FFFFFF),
        const Color(0xFFE5E5E5),
      ),
    };
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: line),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          color: fg,
        ),
      ),
    );
  }
}

class _Check extends StatelessWidget {
  const _Check(this.title, {this.sub, this.soft = false});
  final String title;
  final String? sub;
  final bool soft;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          margin: const EdgeInsets.only(top: 1),
          decoration: BoxDecoration(
            color: soft ? const Color(0x24FFFFFF) : Colors.white,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.check_rounded,
            size: 14,
            color: soft ? Colors.white : Colors.black,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: soft ? 13 : 13.5,
                  fontWeight: soft ? FontWeight.w500 : FontWeight.w700,
                  color: soft ? const Color(0xFFE5E5E5) : Colors.white,
                  height: 1.35,
                ),
              ),
              if (sub != null && sub!.isNotEmpty)
                Text(
                  sub!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: _mut,
                    height: 1.4,
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Btn extends StatelessWidget {
  const _Btn(this.label, {this.onTap, this.dark = false});
  final String label;
  final VoidCallback? onTap;
  final bool dark;
  @override
  Widget build(BuildContext context) {
    final off = onTap == null;
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Material(
        color: off
            ? Colors.transparent
            : (dark ? const Color(0x0FFFFFFF) : Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: off
                ? _line
                : (dark ? const Color(0x59FFFFFF) : Colors.white),
            width: 1.5,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: SizedBox(
            height: 50,
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: off ? _mut : (dark ? Colors.white : Colors.black),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

const _divider = Padding(
  padding: EdgeInsets.symmetric(vertical: 12),
  child: Divider(height: 1, color: Color(0x1AFFFFFF)),
);

// ---------------------------------------------------------------- screen
class PlansBillingScreen extends ConsumerStatefulWidget {
  const PlansBillingScreen({super.key});
  @override
  ConsumerState<PlansBillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends ConsumerState<PlansBillingScreen> {
  var _tab = 'plans';
  var _interval = 'monthly';
  String? _svc;
  String? _boost;
  String? _job;

  @override
  Widget build(BuildContext context) {
    return DashPage<BillingData>(
      head: backHead(context, 'Plans & billing'),
      top: [
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text(
            'Your plan, boosts, verification and receipts. Pay with Mobile Money, bank or card.',
            style: TextStyle(fontSize: 13.5, color: _mut, height: 1.45),
          ),
        ),
        BillingSeg(
          items: const [
            ('plans', 'Plans', null),
            ('services', 'Services', null),
            ('history', 'Payments', null),
          ],
          active: _tab,
          onTap: (k) => setState(() => _tab = k),
        ),
      ],
      data: ref.watch(billingProvider),
      onRefresh: () => ref.refresh(billingProvider.future),
      builder: (b) => switch (_tab) {
        'services' => _services(b),
        'history' => _history(b),
        _ => _plans(b),
      },
    );
  }

  // ------------------------------------------------------------ plans
  List<Widget> _plans(BillingData b) {
    final s = b.summary;
    final cur = s['subscribed'] == true && _live.contains(s['status'])
        ? '${s['tier']}'
        : 'access';
    final slots = b.slots;
    final start = DateTime.tryParse('${slots?['program_start'] ?? ''}');
    final end =
        DateTime.tryParse('${slots?['program_end'] ?? ''}') ??
        start?.add(const Duration(days: 90));
    final claimed = num.tryParse('${slots?['claimed_slots'] ?? 0}') ?? 0,
        total = num.tryParse('${slots?['total_slots'] ?? 0}') ?? 0;
    final open =
        start != null &&
        !start.isAfter(DateTime.now()) &&
        end != null &&
        end.isAfter(DateTime.now()) &&
        claimed < total;
    final annual = _interval == 'annual';
    Json? find(String t, bool founding) => b.plans
        .where(
          (p) =>
              p['tier'] == t &&
              p['billing_interval'] == _interval &&
              (p['is_founding'] == true) == founding,
        )
        .firstOrNull;
    final tiers = ['pro', 'premium', 'enterprise']
        .where(
          (t) => b.plans.any(
            (p) =>
                p['tier'] == t &&
                p['billing_interval'] == 'monthly' &&
                p['is_founding'] != true,
          ),
        )
        .toList();
    final rows = billingCompareRows(b.role, tiers), cols = ['access', ...tiers];

    return [
      _nowCard(s, cur, b.role),
      BillingSeg(
        items: const [
          ('monthly', 'Monthly', null),
          ('annual', 'Yearly', '2 months free'),
        ],
        active: _interval,
        onTap: (k) => setState(() => _interval = k),
      ),
      if (open)
        Note(
          'Founding prices are open: 30% off for your first 12 months. ${total - claimed} places left.',
          icon: Icons.star_border_rounded,
        ),
      _Glass(
        current: cur == 'access',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Access',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Everyone starts here.',
                        style: TextStyle(fontSize: 12.5, color: _mut),
                      ),
                    ],
                  ),
                ),
                if (cur == 'access') const _Pill('Your plan', tone: 'ok'),
              ],
            ),
            const SizedBox(height: 12),
            const Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  'Free',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                    height: 1,
                  ),
                ),
                SizedBox(width: 6),
                Text(
                  'for good',
                  style: TextStyle(
                    fontSize: 13,
                    color: _mut,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              accessPlanText(b.role),
              style: const TextStyle(fontSize: 12.5, color: _mut, height: 1.5),
            ),
          ],
        ),
      ),
      for (final t in tiers)
        () {
          final std = find(t, false),
              f = open ? find(t, true) : null,
              show = f ?? std;
          if (show == null || std == null) return const SizedBox.shrink();
          final meta = std['metadata'] is Map
              ? std['metadata'] as Map
              : const {};
          final list = [
            for (final x
                in (meta['benefits'] is List
                    ? meta['benefits'] as List
                    : const []))
              if (x is Map && x['t'] is String)
                (x['t'] as String, x['d'] as String?),
          ];
          final caps = [
            for (final e
                in (std['capacity_limits'] is Map
                        ? (std['capacity_limits'] as Map)
                        : const {})
                    .entries)
              ('Up to ${e.value} ${_cap[e.key] ?? prettyText(e.key)}', null),
          ];
          final price = num.tryParse('${show['price_minor']}') ?? 0;
          final isCur = cur == t;
          return _Glass(
            current: isCur,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _tierName[t]!,
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if ('${meta['best_for'] ?? ''}'.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                '${meta['best_for']}',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: _mut,
                                  height: 1.45,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (isCur) const _Pill('Your plan', tone: 'ok'),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.end,
                  spacing: 6,
                  children: [
                    Text(
                      cedi(price, show['currency']),
                      style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1,
                        height: 1,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text(
                        '/ ${annual ? 'year' : 'month'}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: _mut,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (f != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text(
                          cedi(std['price_minor'], std['currency']),
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF737373),
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ),
                  ],
                ),
                if (annual)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '${cedi((price / 12).round(), show['currency'])} a month, billed yearly · 2 months free',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFFD4D4D4),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0x1AFFFFFF)),
                for (final (title, sub) in [...list, ...caps])
                  _Check(title, sub: sub),
                isCur
                    ? const _Btn('Your current plan')
                    : _Btn(
                        '${cur == 'access' ? 'Choose' : 'Switch to'} ${_tierName[t]}',
                        dark: !(t == 'pro' && cur == 'access'),
                        onTap: () => _checkout(show),
                      ),
              ],
            ),
          );
        }(),
      const Padding(
        padding: EdgeInsets.only(top: 6, bottom: 10, left: 2),
        child: Text(
          'Compare plans',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
      ),
      _Glass(
        padding: const EdgeInsets.all(6),
        child: Table(
          columnWidths: const {0: FlexColumnWidth(1.25)},
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          border: const TableBorder(
            horizontalInside: BorderSide(color: Color(0x14FFFFFF)),
          ),
          children: [
            TableRow(
              children: [
                const SizedBox(),
                for (final k in cols)
                  _cell(
                    Text(
                      _tierName[k]!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    k == cur,
                  ),
              ],
            ),
            for (final (label, vals) in rows)
              TableRow(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 6,
                    ),
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFCFCFCF),
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                  ),
                  for (final (i, v) in vals.indexed)
                    _cell(
                      v == true
                          ? const Icon(
                              Icons.check_rounded,
                              size: 16,
                              color: Colors.white,
                            )
                          : v == false
                          ? const Icon(
                              Icons.remove_rounded,
                              size: 16,
                              color: Color(0xFF5C5C5C),
                            )
                          : Text(
                              '$v',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFE5E5E5),
                                height: 1.3,
                              ),
                            ),
                      cols[i] == cur,
                    ),
                ],
              ),
          ],
        ),
      ),
      _Glass(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Column(
          children: [
            _fact(
              Icons.restart_alt_rounded,
              'Cancel any time',
              'Paid access lasts to the end of the period.',
            ),
            const Divider(height: 1, color: Color(0x14FFFFFF)),
            _fact(
              Icons.verified_user_outlined,
              '7-day refund window',
              'From the day the plan starts.',
            ),
            const Divider(height: 1, color: Color(0x14FFFFFF)),
            _fact(
              Icons.lock_outline_rounded,
              'Paid through Paystack',
              'Mobile Money, bank or card.',
            ),
          ],
        ),
      ),
      const _Fine(
        'A plan never includes a badge. Badges come from a review by our team.',
      ),
    ];
  }

  Widget _cell(Widget child, bool cur) => Container(
    color: cur ? const Color(0x12FFFFFF) : null,
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
    alignment: Alignment.center,
    child: child,
  );

  Widget _fact(IconData icon, String title, String sub) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 11),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.white),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                sub,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: _mut,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _nowCard(Json s, String cur, String role) {
    if (cur == 'access') {
      final text = role == 'worker'
          ? 'You can send 5 job applications a month. Pro removes the limit and puts you ahead of free members in Discover.'
          : role == 'company' || role == 'individual-employer'
          ? 'You can keep 1 job post open at a time. Pro removes the limit and puts you ahead of free members in Discover.'
          : 'Pro puts you ahead of free members in Discover, with a Pro mark beside your name.';
      return _Glass(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _NowTitle('YOUR PLAN', 'Access')),
                _Pill('Free'),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFFCFCFCF),
                height: 1.5,
              ),
            ),
          ],
        ),
      );
    }
    final tier = _tierName['${s['tier']}'] ?? '${s['tier']}';
    final ending = s['cancel_at_period_end'] == true;
    final st = '${s['status']}';
    return _Glass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _NowTitle('YOUR PLAN', tier, mark: tier)),
              _Pill(
                _status[st] ?? prettyText(st),
                tone: st == 'active' || st == 'trialing'
                    ? 'ok'
                    : [
                        'grace_period',
                        'past_due',
                        'cancel_at_period_end',
                      ].contains(st)
                    ? 'warn'
                    : 'bad',
              ),
            ],
          ),
          _divider,
          Wrap(
            runSpacing: 10,
            children: [
              _dl(
                ending ? 'Access ends' : 'Next payment',
                '${_date(s['period_end'])}${ending ? '' : ' · ${cedi(s['price_minor'], s['currency'])}'}',
              ),
              _dl('Billing', s['interval'] == 'annual' ? 'Yearly' : 'Monthly'),
              if (s['founding'] == true)
                _dl('Founding price until', _date(s['founding_lock_end'])),
              _dl(
                'Refund deadline',
                '${_date(s['refund_deadline'])}${s['refundable'] == true ? '' : ' (passed)'}',
              ),
            ],
          ),
          if (st == 'grace_period')
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                'Your last payment didn\'t go through. Access continues until ${_date(s['grace_until'])}. Renew below to keep it. Nothing is deleted.',
                style: const TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFFFCA5A5),
                  height: 1.45,
                ),
              ),
            ),
          if (_live.contains(st) && !ending)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: GestureDetector(
                onTap: _cancel,
                child: const Text(
                  'Cancel renewal',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.underline,
                    decorationColor: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _dl(String k, String v) => FractionallySizedBox(
    widthFactor: .5,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(k, style: const TextStyle(fontSize: 11.5, color: _mut)),
        const SizedBox(height: 2),
        Text(
          v,
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );

  void _checkout(Json plan) {
    final annual = plan['billing_interval'] == 'annual';
    final renew = DateTime.now().add(Duration(days: annual ? 365 : 30)),
        refund = DateTime.now().add(const Duration(days: 7));
    final role = '${plan['role'] ?? ''}';
    final std = ref
        .read(billingProvider)
        .asData
        ?.value
        .plans
        .where(
          (p) =>
              p['tier'] == plan['tier'] &&
              p['billing_interval'] == plan['billing_interval'] &&
              p['is_founding'] != true,
        )
        .firstOrNull;
    showGlassSheet(
      context,
      title: '${_tierName['${plan['tier']}'] ?? ''} plan',
      child: Flexible(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: const Color(0x0FFFFFFF),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0x24FFFFFF)),
                ),
                child: Column(
                  children: [
                    const Text(
                      'PAY TODAY',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.3,
                        color: _mut,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      cedi(plan['price_minor'], plan['currency']),
                      style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1,
                      ),
                    ),
                    Text(
                      annual ? 'for one year' : 'for one month',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFFCFCFCF),
                      ),
                    ),
                  ],
                ),
              ),
              KV(
                'Account',
                prettyText(
                  role == 'individual-employer'
                      ? 'client'
                      : role == 'business'
                      ? 'supplier'
                      : role,
                ),
              ),
              KV(
                'Renews',
                '${cedi(plan['price_minor'], plan['currency'])} on about ${_date(renew.toIso8601String())}',
              ),
              if (plan['is_founding'] == true && std != null)
                KV(
                  'Founding price',
                  '12 months, then ${cedi(std['price_minor'], std['currency'])}',
                ),
              KV('Refund deadline', _date(refund.toIso8601String())),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Stop renewal any time and keep access to the end of the period. If a payment fails you get 7 days of grace. Nothing is ever deleted.',
                  style: TextStyle(fontSize: 12.5, color: _mut, height: 1.5),
                ),
              ),
              PillButton(
                label: 'Continue to payment',
                onPressed: () async {
                  Navigator.of(context).pop();
                  await openPaystack(
                    context,
                    () => rpcCall('billing_start_checkout', {
                      'p_plan': plan['id'],
                      'p_org': null,
                    }),
                    interval: annual ? 'annual' : 'monthly',
                  );
                },
              ),
              const _Fine(
                'Next you choose Mobile Money, bank or card. Access starts once Paystack confirms the payment.',
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _cancel() => showGlassSheet(
    context,
    title: 'Cancel renewal',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Your plan will not renew. You keep paid access until the end of the period you already paid for. Nothing is deleted.',
          style: TextStyle(fontSize: 13, color: _mut, height: 1.45),
        ),
        const SizedBox(height: 14),
        PillButton(
          label: 'Stop renewal',
          onPressed: () async {
            Navigator.of(context).pop();
            if (await runAction(
              context,
              () => rpcCall('cancel_subscription', {'p_org': null}),
              ok: 'Renewal stopped. Access continues to the end of the period.',
            )) {
              ref.invalidate(billingProvider);
            }
          },
        ),
        const SizedBox(height: 8),
        PillButton(
          label: 'Keep my plan',
          light: false,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    ),
  );

  // ------------------------------------------------------------ services
  List<Widget> _services(BillingData b) {
    final kinds = [
      'boost',
      'verification',
    ].where((k) => b.services.any((x) => x['kind'] == k)).toList();
    final all = [...kinds, 'fees'];
    final k = all.contains(_svc) ? _svc! : all.first;
    const label = {
      'boost': 'Boosts',
      'verification': 'Verification',
      'fees': 'Fees',
    };
    return [
      BillingSeg(
        items: [for (final x in all) (x, label[x]!, null)],
        active: k,
        small: true,
        onTap: (x) => setState(() => _svc = x),
      ),
      ...switch (k) {
        'boost' => _boosts(
          b,
          b.services.where((x) => x['kind'] == 'boost').toList(),
        ),
        'verification' => _verification(
          b.services.where((x) => x['kind'] == 'verification').toList(),
        ),
        _ => _fees(),
      },
    ];
  }

  Widget _hero(Widget icon, String title, String text) => _Glass(
    padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: const EdgeInsets.only(top: 2), child: icon),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                text,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFFCFCFCF),
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  List<Widget> _boosts(BillingData b, List<Json> list) {
    final forJob = billingBoostFor(b.role) == 'job';
    final now = DateTime.now();
    final active = b.boosts
        .where(
          (x) => (DateTime.tryParse('${x['expires_at']}') ?? DateTime(2000))
              .isAfter(now),
        )
        .toList();
    String title(Json x) => x['target_type'] == 'job'
        ? '${b.jobs.where((j) => j['id'] == x['target_id']).firstOrNull?['title'] ?? 'Your job'}'
        : 'Your profile';
    final sel =
        list.where((x) => x['code'] == _boost).firstOrNull ??
        list.where((x) => '${x['duration_hours']}' == '168').firstOrNull ??
        list.firstOrNull;
    final job = b.jobs.any((j) => j['id'] == _job)
        ? _job
        : b.jobs.firstOrNull?['id'] as String?;
    final out = <Widget>[
      _hero(
        const Icon(Icons.bolt_outlined, size: 26, color: Colors.white),
        'Be seen first',
        forJob
            ? 'Your job goes to the top of the job list, marked Featured, for the time you choose.'
            : 'Your profile goes to the top of Discover, marked Featured, for the time you choose.',
      ),
      if (active.isNotEmpty)
        _Glass(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(
            children: [
              for (final (i, x) in active.indexed) ...[
                if (i > 0) const Divider(height: 1, color: Color(0x14FFFFFF)),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  child: Row(
                    children: [
                      Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: const Color(0xFF34D399),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF34D399)
                                  .withValues(alpha: .25),
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title(x),
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'Featured until ${_until(x['expires_at'])}',
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: _mut,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
    ];
    if (sel == null) return out;
    if (forJob && b.jobs.isEmpty) {
      return [
        ...out,
        const _Glass(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Post a job first',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 6),
              Text(
                'A boost needs an open job. Post one, then come back to boost it.',
                style: TextStyle(fontSize: 12.5, color: _mut, height: 1.5),
              ),
            ],
          ),
        ),
      ];
    }
    final hours = num.tryParse('${sel['duration_hours']}') ?? 24,
        price = num.tryParse('${sel['price_minor']}') ?? 0;
    final days = hours / 24 < 1 ? 1 : hours / 24;
    return [
      ...out,
      _Glass(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (forJob) ...[
              const _Lab('JOB TO BOOST'),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0x59000000),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _line, width: 1.5),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: job,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF141414),
                    items: [
                      for (final j in b.jobs)
                        DropdownMenuItem(
                          value: '${j['id']}',
                          child: Text(
                            '${j['title'] ?? 'Job'}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (v) => setState(() => _job = v),
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],
            const _Lab('HOW LONG'),
            LayoutBuilder(
              builder: (context, c) {
                // three to a row; the last row's options share it evenly (website .bl-dur n4 / n5)
                final rows = <List<Json>>[];
                if (list.length == 4) {
                  rows.addAll([list.sublist(0, 2), list.sublist(2)]);
                } else {
                  for (var i = 0; i < list.length; i += 3) {
                    rows.add(
                      list.sublist(
                        i,
                        i + 3 > list.length ? list.length : i + 3,
                      ),
                    );
                  }
                }
                return Column(
                  children: [
                    for (final r in rows)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            for (final (i, x) in r.indexed) ...[
                              if (i > 0) const SizedBox(width: 8),
                              Expanded(
                                child: _DurChip(
                                  label: boostDuration(
                                    num.tryParse('${x['duration_hours']}') ??
                                        24,
                                  ),
                                  price: cedi(x['price_minor'], x['currency']),
                                  on: x == sel,
                                  onTap: () =>
                                      setState(() => _boost = '${x['code']}'),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
            const Divider(height: 17, color: Color(0x1AFFFFFF)),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: Text(
                    '${boostDuration(hours)} of Featured placement',
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: Color(0xFFE5E5E5),
                    ),
                  ),
                ),
                Text(
                  cedi(price, sel['currency']),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'About ${cedi((price / days / 100).round() * 100, sel['currency'])} a day. Starts as soon as Paystack confirms the payment.',
              style: const TextStyle(fontSize: 12.5, color: _mut, height: 1.5),
            ),
            _Btn(
              'Boost for ${cedi(price, sel['currency'])}',
              onTap: () => openPaystack(
                context,
                () => rpcCall('billing_start_service', {
                  'p_kind': 'boost',
                  'p_code': sel['code'],
                  'p_target': forJob ? {'target_id': job} : <String, dynamic>{},
                  'p_org': null,
                }),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  String _until(Object? iso) {
    final t = DateTime.tryParse('${iso ?? ''}')?.toLocal();
    if (t == null) return '—';
    const m = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    return '${t.day} ${m[t.month - 1]}, $h:${t.minute.toString().padLeft(2, '0')} ${t.hour < 12 ? 'am' : 'pm'}';
  }

  List<Widget> _verification(List<Json> list) {
    final me = ref.watch(accountProfileProvider).asData?.value;
    final cur = me?.isVerified == true
        ? (VerifiedBadge.labels.containsKey(me?.badgeTier)
              ? me!.badgeTier!
              : 'verified')
        : null;
    final role = me?.type?.webRole ?? '';
    return [
      if (cur != null)
        _Glass(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _NowTitle(
                      'YOUR BADGE',
                      VerifiedBadge.labels[cur] ?? 'Verified',
                    ),
                  ),
                  VerifiedBadge(cur, size: 34),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'Shown on your profile, cards and search results.',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFFCFCFCF),
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      _hero(
        VerifiedBadge(cur ?? 'identity', size: 28),
        cur != null ? 'Go further' : 'Get verified',
        'Our team checks your documents by hand. The fee pays for the check, not the result, and no plan includes a badge.',
      ),
      for (final x in list)
        () {
          final code = '${x['code']}',
              tier = _verTier[code] ?? 'identity',
              has = cur == tier;
          final col = VerifiedBadge.colorOf(tier);
          final name = code == 'standard'
              ? 'Business'
              : code == 'enhanced' && role == 'business'
              ? 'Enhanced business'
              : prettyText(code);
          return _Glass(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: col.withValues(alpha: .08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: col.withValues(alpha: .33)),
                      ),
                      child: Center(child: VerifiedBadge(tier, size: 26)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Text(
                            'One-time review',
                            style: TextStyle(fontSize: 12, color: _mut),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      cedi(x['price_minor'], x['currency']),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.4,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Divider(height: 17, color: Color(0x1AFFFFFF)),
                for (final t in _verChecks[code] ?? const <String>[])
                  _Check(t, soft: true),
                has
                    ? const _Btn('Your badge')
                    : _Btn(
                        'Request review · ${cedi(x['price_minor'], x['currency'])}',
                        dark: true,
                        onTap: () => openPaystack(
                          context,
                          () => rpcCall('billing_start_service', {
                            'p_kind': 'verification',
                            'p_code': code,
                            'p_target': <String, dynamic>{},
                            'p_org': null,
                          }),
                        ),
                      ),
              ],
            ),
          );
        }(),
      _Glass(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Column(
          children: [
            for (final (i, (t, d)) in const [
              ('Pay the review fee', 'With Mobile Money, bank or card.'),
              ('Send your documents', 'Profile → Verification documents.'),
              (
                'Get the decision',
                'A reviewer decides and you get a notification.',
              ),
            ].indexed) ...[
              if (i > 0) const Divider(height: 1, color: Color(0x14FFFFFF)),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 11),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: Color(0x1FFFFFFF),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${i + 1}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            d,
                            style: const TextStyle(fontSize: 12.5, color: _mut),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    ];
  }

  List<Widget> _fees() => [
    _Glass(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      child: Column(
        children: [
          for (final (i, (a, v, d)) in const [
            (
              'Service fee',
              '10%',
              'Taken from money released to you from escrow. Nothing is charged on a refund.',
            ),
            (
              'Adding money',
              '1.95%',
              "Paystack's processing fee, shown before you pay.",
            ),
            ('Withdrawals', 'Free', 'To Mobile Money, from GH₵10.'),
            ('Disputes', 'Free', 'Money is frozen while BAID X reviews it.'),
          ].indexed) ...[
            if (i > 0) const Divider(height: 1, color: Color(0x14FFFFFF)),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 13),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          a,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          d,
                          style: const TextStyle(
                            fontSize: 12,
                            color: _mut,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    v,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    ),
    const _Fine(
      'Every fee is shown before you confirm. Full details are on the pricing page and in the terms, sections 6 to 9.',
    ),
  ];

  // ------------------------------------------------------------ payments
  List<Widget> _history(BillingData b) {
    if (b.payments.isEmpty) {
      return const [
        _Glass(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'No payments yet',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 6),
              Text(
                'Receipts for plans, boosts and verification show here.',
                style: TextStyle(fontSize: 12.5, color: _mut),
              ),
            ],
          ),
        ),
      ];
    }
    const icons = {
      'subscription': Icons.workspace_premium_outlined,
      'boost': Icons.bolt_outlined,
      'verification': Icons.verified_outlined,
      'wallet_deposit': Icons.account_balance_wallet_outlined,
    };
    return [
      _Glass(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: Column(
          children: [
            for (final (i, p) in b.payments.indexed) ...[
              if (i > 0) const Divider(height: 1, color: Color(0x14FFFFFF)),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0x1AFFFFFF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        icons[p['purpose']] ?? Icons.payments_outlined,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${p['what'] ?? prettyText(p['purpose'])}',
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '${p['about'] != null ? '${p['about']} · ' : ''}${_date(p['created_at'])}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11.5, color: _mut),
                          ),
                          Text(
                            '${p['reference'] ?? ''}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: _mut,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          cedi(p['amount_minor'] ?? 0, p['currency']),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 5),
                        _Pill(
                          _payStatus['${p['status']}'] ??
                              prettyText(p['status']),
                          tone: p['status'] == 'successful'
                              ? 'ok'
                              : [
                                  'failed',
                                  'cancelled',
                                  'reversed',
                                ].contains(p['status'])
                              ? 'bad'
                              : ['processing', 'disputed'].contains(p['status'])
                              ? 'warn'
                              : '',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      const _Fine(
        '"Not paid" means checkout was opened but Paystack never confirmed a payment. Nothing was charged.',
      ),
    ];
  }
}

class _NowTitle extends StatelessWidget {
  const _NowTitle(this.over, this.title, {this.mark});
  final String over;
  final String title;
  final String? mark;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        over,
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.3,
          color: _mut,
        ),
      ),
      const SizedBox(height: 4),
      Row(
        children: [
          Flexible(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: -.5,
              ),
            ),
          ),
          if (mark != null) ...[const SizedBox(width: 8), PlanMark(mark!)],
        ],
      ),
    ],
  );
}

class _Lab extends StatelessWidget {
  const _Lab(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.3,
        color: _mut,
      ),
    ),
  );
}

class _Fine extends StatelessWidget {
  const _Fine(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 10, 8, 4),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 12,
        color: Color(0xFF8A8A8A),
        height: 1.5,
      ),
    ),
  );
}

class _DurChip extends StatelessWidget {
  const _DurChip({
    required this.label,
    required this.price,
    required this.on,
    required this.onTap,
  });
  final String label;
  final String price;
  final bool on;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    selected: on,
    button: true,
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 64,
        decoration: BoxDecoration(
          color: on ? Colors.white : const Color(0x0AFFFFFF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: on ? Colors.white : _line, width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: on ? Colors.black : Colors.white,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              price,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: on ? const Color(0xFF262626) : const Color(0xFFCFCFCF),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
