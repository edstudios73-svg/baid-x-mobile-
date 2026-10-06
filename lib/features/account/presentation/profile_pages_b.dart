import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/baid_ui.dart';
import '../../../shared/widgets/dash_ui.dart';
import '../../account_type/domain/account_type.dart';
import '../../directory/presentation/member_sheet.dart' show startConversationWith;
import '../../tabs/data/tabs_data.dart';
import '../data/profile_data.dart';
import 'account_sheets.dart';
import 'profile_pages.dart';
import '../../market/listing_gallery.dart';

/// Profile menu pages, part 2 (website js/billing.js, js/orgs.js,
/// js/orders.js, js/market.js paymentsView / supplierView).

String cedi(Object? minor, [Object? cur]) {
  final m = num.tryParse('${minor ?? 0}') ?? 0;
  final v = m / 100;
  final s = m % 100 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
  final parts = s.split('.');
  final whole = parts[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  final c = '${cur ?? 'GHS'}';
  return '${c == 'GHS' ? 'GH₵' : '$c '}$whole${parts.length > 1 ? '.${parts[1]}' : ''}';
}

String _date(Object? iso) {
  final t = DateTime.tryParse('${iso ?? ''}');
  if (t == null) return '—';
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${t.day} ${m[t.month - 1]} ${t.year}';
}

// ======================================================================
// Plans & billing
// ======================================================================
class PlansBillingScreen extends ConsumerStatefulWidget {
  const PlansBillingScreen({super.key});
  @override
  ConsumerState<PlansBillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends ConsumerState<PlansBillingScreen> {
  var _tab = 'plans';
  var _interval = 'monthly';

  static const _tierName = {'access': 'Access', 'pro': 'Pro', 'premium': 'Premium', 'enterprise': 'Enterprise'};
  static const _cap = {'org_members': 'people in your organization', 'active_projects': 'active projects', 'job_postings_per_month': 'job posts a month', 'org_admins': 'organization admins', 'collaborators_per_project': 'collaborators per project'};
  static const _status = {'active': 'Active', 'trialing': 'Trial', 'grace_period': 'Payment due', 'past_due': 'Payment due', 'cancel_at_period_end': 'Ends soon', 'cancelled': 'Cancelled', 'expired': 'Expired', 'suspended': 'Paused'};
  static const _pay = {'successful': 'Paid', 'pending': 'Pending', 'processing': 'Checking', 'failed': 'Failed', 'refunded': 'Refunded', 'cancelled': 'Cancelled'};

  @override
  Widget build(BuildContext context) {
    return DashPage<BillingData>(
      head: backHead(context, 'Plans & billing'),
      top: [DashSegs(items: const [('plans', 'Plans'), ('services', 'Services & fees'), ('history', 'History')], active: _tab, onTap: (k) => setState(() => _tab = k))],
      data: ref.watch(billingProvider),
      onRefresh: () => ref.refresh(billingProvider.future),
      builder: (b) => switch (_tab) {
        'services' => _services(b),
        'history' => _history(b),
        _ => _plans(b),
      },
    );
  }

  List<Widget> _plans(BillingData b) {
    final s = b.summary;
    final live = s['subscribed'] == true && ['active', 'trialing', 'grace_period', 'past_due', 'cancel_at_period_end'].contains(s['status']);
    final cur = live ? '${s['tier']}' : 'access';
    final slots = b.slots;
    final start = DateTime.tryParse('${slots?['program_start'] ?? ''}');
    final end = DateTime.tryParse('${slots?['program_end'] ?? ''}') ?? start?.add(const Duration(days: 90));
    final claimed = num.tryParse('${slots?['claimed_slots'] ?? 0}') ?? 0, total = num.tryParse('${slots?['total_slots'] ?? 0}') ?? 0;
    final open = start != null && !start.isAfter(DateTime.now()) && end != null && end.isAfter(DateTime.now()) && claimed < total;
    Json? find(String t, bool founding) => b.plans.where((p) => p['tier'] == t && p['billing_interval'] == _interval && (p['is_founding'] == true) == founding).firstOrNull;
    final tiers = ['pro', 'premium', 'enterprise'].where((t) => b.plans.any((p) => p['tier'] == t && p['billing_interval'] == 'monthly' && p['is_founding'] != true));
    return [
      SurfaceCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Text(s['subscribed'] == true ? '${_tierName['${s['tier']}'] ?? s['tier']} · ${s['interval'] ?? ''}' : 'Your plan', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
            StatusPill('done', label: s['subscribed'] == true ? (_status['${s['status']}'] ?? prettyText(s['status'])) : 'Access'),
          ]),
          const SizedBox(height: 8),
          if (s['subscribed'] != true)
            const Text('You are on the free Access plan. Upgrade any time. Nothing is charged unless you confirm a checkout.', style: TextStyle(fontSize: 12.5, color: AppColors.muted, height: 1.4))
          else ...[
            KV(s['cancel_at_period_end'] == true ? 'Access ends' : 'Next payment', '${_date(s['period_end'])}${s['cancel_at_period_end'] == true ? '' : ' · ${cedi(s['price_minor'], s['currency'])}'}'),
            KV('Refund deadline', '${_date(s['refund_deadline'])}${s['refundable'] == true ? '' : ' (passed)'}'),
            if (live && s['cancel_at_period_end'] != true) ...[
              const SizedBox(height: 8),
              Align(alignment: Alignment.centerLeft, child: SmallButton('Cancel renewal', light: false, onPressed: _cancel)),
            ],
          ],
        ]),
      ),
      DashSegs(items: const [('monthly', 'Monthly'), ('annual', 'Annual · save 20%')], active: _interval, onTap: (k) => setState(() => _interval = k)),
      if (open) Note('Founding member prices are open. ${total - claimed} places left. Your price stays the same for 12 months from your start date.', icon: Icons.star_border_rounded),
      _planCard('Access', 'Free', 'Everything you need to get started, free for good: profile, search, messaging, applications, reviews and reputation, and XID lookup.', current: cur == 'access'),
      for (final t in tiers)
        () {
          final std = find(t, false), f = open ? find(t, true) : null, show = f ?? std;
          if (show == null) return const SizedBox.shrink();
          final caps = (std?['capacity_limits'] is Map ? (std!['capacity_limits'] as Map) : const {}).entries.map((e) => '${e.value} ${_cap[e.key] ?? prettyText(e.key)}').toList();
          return _planCard(
            _tierName[t]!,
            '${cedi(show['price_minor'], show['currency'])} per ${_interval == 'monthly' ? 'month' : 'year'}',
            caps.join(' · '),
            current: cur == t,
            was: f != null && std != null ? cedi(std['price_minor'], std['currency']) : null,
            action: cur == t ? null : SmallButton(cur == 'access' ? 'Choose ${_tierName[t]}' : 'Switch to ${_tierName[t]}', onPressed: () => _checkout(show)),
          );
        }(),
    ];
  }

  Widget _planCard(String name, String price, String text, {bool current = false, String? was, Widget? action}) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: SurfaceCard(
          borderColor: current ? const Color(0x99FFFFFF) : null,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
              if (current) const StatusPill('done', label: 'Your plan'),
            ]),
            const SizedBox(height: 6),
            Row(children: [
              Text(price, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFFE8C46A))),
              if (was != null) ...[const SizedBox(width: 8), Text(was, style: const TextStyle(fontSize: 12.5, color: AppColors.muted, decoration: TextDecoration.lineThrough))],
            ]),
            if (text.isNotEmpty) ...[const SizedBox(height: 6), Text(text, style: const TextStyle(fontSize: 12.5, color: AppColors.muted, height: 1.4))],
            if (action != null) ...[const SizedBox(height: 10), action],
          ]),
        ),
      );

  void _checkout(Json plan) {
    final annual = plan['billing_interval'] == 'annual';
    final renew = DateTime.now().add(Duration(days: annual ? 365 : 30)), refund = DateTime.now().add(const Duration(days: 7));
    showGlassSheet(
      context,
      title: '${_tierName['${plan['tier']}'] ?? ''} plan',
      child: Flexible(
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            KV('Plan', _tierName['${plan['tier']}'] ?? ''),
            KV('Billing', annual ? 'Once a year' : 'Every month'),
            KV('Pay today', cedi(plan['price_minor'], plan['currency']), strong: true),
            KV('Renews at', '${cedi(plan['price_minor'], plan['currency'])} on about ${_date(renew.toIso8601String())}'),
            KV('Refund deadline', '${_date(refund.toIso8601String())} (7 days from activation)'),
            const SizedBox(height: 10),
            const Note('You can stop renewal at any time and keep paid access until the end of the period. If a payment fails you get 7 days of grace. Nothing is ever deleted.'),
            PillButton(label: 'Pay ${cedi(plan['price_minor'], plan['currency'])} with Paystack', onPressed: () async {
              Navigator.of(context).pop();
              await openPaystack(context, () => rpcCall('billing_start_checkout', {'p_plan': plan['id'], 'p_org': null}));
            }),
            const SizedBox(height: 8),
            const Text('Access starts only after Paystack confirms your payment to BAID X.', textAlign: TextAlign.center, style: TextStyle(fontSize: 11.5, color: AppColors.muted)),
          ]),
        ),
      ),
    );
  }

  void _cancel() => showGlassSheet(
        context,
        title: 'Cancel renewal',
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Your plan will not renew. You keep paid access until the end of the period you already paid for. Nothing is deleted.', style: TextStyle(fontSize: 13, color: AppColors.muted, height: 1.4)),
          const SizedBox(height: 14),
          PillButton(label: 'Stop renewal', onPressed: () async {
            Navigator.of(context).pop();
            if (await runAction(context, () => rpcCall('cancel_subscription', {'p_org': null}), ok: 'Renewal stopped. Access continues to the end of the period.')) ref.invalidate(billingProvider);
          }),
        ]),
      );

  static const _kind = {'verification': 'Verification', 'boost': 'Boosts', 'xid': 'Digital ID', 'promotion': 'Promotions'};
  List<Widget> _services(BillingData b) {
    if (b.services.isEmpty) return const [Text('No services are available for your account type yet.', style: TextStyle(color: AppColors.muted, fontSize: 13))];
    final out = <Widget>[];
    for (final k in ['verification', 'boost', 'xid', 'promotion']) {
      final list = b.services.where((x) => x['kind'] == k).toList();
      if (list.isEmpty) continue;
      out.add(SecLabel(_kind[k]!));
      for (final x in list) {
        final meta = x['metadata'] is Map ? x['metadata'] as Map : const {};
        final later = k == 'promotion' || meta['target'] == 'project' || meta['target'] == 'business_listing' || meta['target'] == 'job';
        final hours = num.tryParse('${x['duration_hours'] ?? 0}') ?? 0;
        out.add(DashRow(
          icon: k == 'verification' ? Icons.verified_outlined : k == 'boost' ? Icons.bolt_outlined : k == 'xid' ? Icons.badge_outlined : Icons.campaign_outlined,
          title: k == 'verification' ? prettyText(x['code'] == 'standard' ? 'business' : x['code']) : '${x['label'] ?? ''}',
          sub: k == 'verification' ? 'One-time review' : hours > 0 ? 'Lasts ${hours < 48 ? '$hours hours' : '${(hours / 24).round()} days'}' : (k == 'xid' ? 'Valid for one year' : ''),
          trailing: Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
            Text(cedi(x['price_minor'], x['currency']), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
            const SizedBox(height: 4),
            later
                ? const Text('From your listing', style: TextStyle(fontSize: 11, color: AppColors.muted))
                : SmallButton('Buy', onPressed: () => openPaystack(context, () => rpcCall('billing_start_service', {'p_kind': k, 'p_code': x['code'], 'p_target': <String, dynamic>{}, 'p_org': null}))),
          ]),
        ));
      }
    }
    out.add(const Padding(padding: EdgeInsets.only(top: 8), child: Text('Secure payment with Paystack · Mobile Money or card', textAlign: TextAlign.center, style: TextStyle(fontSize: 11.5, color: AppColors.muted))));
    return out;
  }

  List<Widget> _history(BillingData b) => [
        const SecLabel('Payment history'),
        if (b.payments.isEmpty)
          const Text('No payments yet.', style: TextStyle(color: AppColors.muted, fontSize: 13))
        else
          for (final p in b.payments)
            DashRow(
              icon: Icons.payments_outlined,
              title: p['purpose'] == 'wallet_deposit' ? 'Wallet top-up' : prettyText(p['purpose']),
              sub: '${_date(p['created_at'])} · ${p['reference'] ?? ''}',
              trailing: Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
                Text(cedi(p['amount_minor'] ?? p['expected_amount_minor'] ?? 0, p['currency']), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 4),
                StatusPill(p['status'] == 'successful' ? 'done' : ['pending', 'processing'].contains(p['status']) ? 'pending' : '', label: _pay['${p['status']}'] ?? prettyText(p['status'])),
              ]),
            ),
      ];
}

// ======================================================================
// Company payments
// ======================================================================
class PaymentsScreen extends ConsumerWidget {
  const PaymentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DashPage<List<Json>>(
      head: backHead(context, 'Payments'),
      data: ref.watch(companyPaymentsProvider),
      onRefresh: () => ref.refresh(companyPaymentsProvider.future),
      builder: (list) {
        final paid = list.where((p) => p['status'] == 'paid').fold<num>(0, (s, p) => s + (num.tryParse('${p['amount']}') ?? 0));
        final waiting = list.where((p) => ['pending', 'approved'].contains(p['status'])).length;
        return [
          Row(children: [
            Expanded(child: SurfaceCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(money(paid), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)), const Text('Paid out', style: TextStyle(fontSize: 12, color: AppColors.muted))]))),
            const SizedBox(width: 10),
            Expanded(child: SurfaceCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('$waiting', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)), const Text('Waiting', style: TextStyle(fontSize: 12, color: AppColors.muted))]))),
          ]),
          const SizedBox(height: 12),
          const Note('Money moves by Mobile Money for now. Each payment is recorded against its project as a paper trail.'),
          if (list.isEmpty)
            DashEmpty(icon: Icons.payments_outlined, title: 'No payments yet', text: 'Payments recorded or requested inside your projects appear here.', action: SmallButton('Open projects', onPressed: () => context.go(AppRoutes.projects)))
          else
            for (final p in list)
              DashRow(
                icon: Icons.payments_outlined,
                title: '${p['payee'] ?? ''} · ${money(p['amount'])}',
                sub: '${p['project'] ?? ''} · ${p['purpose'] ?? prettyText(p['type'])} · ${ago(p['created_at'])}',
                trailing: StatusPill(p['status'] == 'paid' ? 'done' : p['status'] == 'rejected' ? '' : 'pending', label: prettyText(p['status'])),
              ),
        ];
      },
    );
  }
}

// ======================================================================
// Equipment and materials from suppliers, with ordering
// ======================================================================
class SupplierScreen extends ConsumerStatefulWidget {
  const SupplierScreen({required this.kind, super.key});
  final String kind; // equipment | products
  @override
  ConsumerState<SupplierScreen> createState() => _SupplierScreenState();
}

class _SupplierScreenState extends ConsumerState<SupplierScreen> {
  var _q = '', _cat = '';

  bool get _eq => widget.kind == 'equipment';
  num _n(Object? v) => num.tryParse('${v ?? ''}') ?? 0;
  String _cedis(Object? v) {
    final n = _n(v);
    final whole = n.truncate().toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
    final frac = n == n.truncateToDouble() ? '' : n.toStringAsFixed(2).split('.').last;
    return 'GH₵$whole${frac.isEmpty ? '' : '.$frac'}';
  }

  (String, String) _price(Json i) => _eq
      ? (_n(i['daily_rate']) > 0 ? (_cedis(i['daily_rate']), '/day') : _n(i['sale_price']) > 0 ? (_cedis(i['sale_price']), '') : ('Ask for price', ''))
      : (_n(i['price']) > 0 ? (_cedis(i['price']), '') : ('Ask for price', ''));

  @override
  Widget build(BuildContext context) {
    final eq = _eq;
    // Watched here so the account type is loaded before a listing opens (it decides Buy/Rent).
    ref.watch(accountProfileProvider);
    return DashPage<List<Json>>(
      head: backHead(context, eq ? 'Equipment' : 'Materials'),
      data: ref.watch(supplierCatalogProvider(widget.kind)),
      onRefresh: () => ref.refresh(supplierCatalogProvider(widget.kind).future),
      builder: (list) {
        if (list.isEmpty) {
          return [DashEmpty(icon: eq ? Icons.construction_outlined : Icons.inventory_2_outlined, title: 'No ${eq ? 'equipment' : 'materials'} listed yet', text: 'Suppliers list what they rent and sell here. Check back soon, or find suppliers in Discover.', action: SmallButton('Find suppliers', onPressed: () => context.go(AppRoutes.discover)))];
        }
        final cats = {for (final i in list) if ('${i['category'] ?? ''}'.isNotEmpty) '${i['category']}'}.toList()..sort();
        final q = _q.toLowerCase();
        final shown = list.where((i) => (_cat.isEmpty || i['category'] == _cat) && (q.isEmpty || '${i['name']} ${i['category'] ?? ''} ${i['business']} ${i['town'] ?? ''} ${i['region'] ?? ''}'.toLowerCase().contains(q))).toList();
        return [
          Text(eq ? 'Machines and tools to rent or buy from suppliers across Ghana.' : 'Building materials from suppliers across Ghana.', style: const TextStyle(fontSize: 13, color: AppColors.muted)),
          const SizedBox(height: 12),
          TextField(
            onChanged: (v) => setState(() => _q = v.trim()),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: eq ? 'Search excavators, mixers, scaffolds…' : 'Search cement, blocks, tiles…',
              prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFFBDBDBD)),
              filled: true,
              fillColor: const Color(0x12FFFFFF),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(99), borderSide: const BorderSide(color: Color(0x2EFFFFFF), width: 1.5)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(99), borderSide: const BorderSide(color: Color(0x2EFFFFFF), width: 1.5)),
            ),
          ),
          if (cats.length > 1) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 36,
              child: ListView(scrollDirection: Axis.horizontal, children: [
                for (final c in ['', ...cats])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(c.isEmpty ? 'All' : c),
                      selected: _cat == c,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _cat = c),
                      labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _cat == c ? Colors.black : Colors.white),
                      selectedColor: Colors.white,
                      backgroundColor: const Color(0x0DFFFFFF),
                      side: BorderSide(color: _cat == c ? Colors.white : const Color(0x38FFFFFF), width: 1.5),
                      shape: const StadiumBorder(),
                    ),
                  ),
              ]),
            ),
          ],
          const SizedBox(height: 12),
          if (shown.isEmpty)
            const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Text('Nothing matches. Try another word or category.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13.5, color: AppColors.muted)))
          else
            LayoutBuilder(
              builder: (context, c) {
                final cols = c.maxWidth >= 700 ? 3 : 2;
                final w = (c.maxWidth - 12 * (cols - 1)) / cols;
                return Wrap(spacing: 12, runSpacing: 12, children: [
                  for (final i in shown)
                    SizedBox(
                      width: w,
                      child: Builder(builder: (context) {
                        final (p, per) = _price(i);
                        return ListingCard(item: i, equipment: eq, price: p, per: per, onTap: () => _open(i));
                      }),
                    ),
                ]);
              },
            ),
        ];
      },
    );
  }

  void _open(Json i) {
    final eq = _eq;
    final type = ref.read(accountProfileProvider).asData?.value?.type;
    final canOrder = type == AccountType.company || type == AccountType.employer;
    final accepting = i['accepting'] != false;
    final imgs = listingImages(i);
    final cond = '${i['condition'] ?? ''}';
    final facts = [
      if ('${i['category'] ?? ''}'.isNotEmpty) '${i['category']}',
      if (eq && cond.isNotEmpty) '${cond[0].toUpperCase()}${cond.substring(1)} condition',
      if (!eq && i['quantity'] != null) _n(i['quantity']) > 0 ? '${i['quantity']} in stock' : 'Out of stock',
    ];
    Widget priceBox(String label, String value, [String per = '']) => Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: const Color(0x0FFFFFFF), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0x24FFFFFF), width: 1.5)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
          Text.rich(TextSpan(children: [TextSpan(text: value), if (per.isNotEmpty) TextSpan(text: per, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFBDBDBD)))]), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -.3)),
        ]),
      ),
    );
    final prices = <Widget>[
      if (eq && _n(i['daily_rate']) > 0) priceBox('Rent', _cedis(i['daily_rate']), '/day'),
      if (eq && _n(i['sale_price']) > 0) priceBox('Buy', _cedis(i['sale_price'])),
      if (!eq && _n(i['price']) > 0) priceBox('Price', _cedis(i['price'])),
    ];
    showGlassSheet(
      context,
      title: '${i['name'] ?? ''}',
      child: Flexible(
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            ListingGallery(images: imgs, equipment: eq, title: '${i['name'] ?? ''}'),
            const SizedBox(height: 16),
            Row(children: [for (final (k, w) in (prices.isEmpty ? [priceBox('Price', 'Ask the supplier')] : prices).indexed) ...[if (k > 0) const SizedBox(width: 10), w]]),
            if (facts.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final f in facts)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: const Color(0x12FFFFFF), borderRadius: BorderRadius.circular(99), border: Border.all(color: const Color(0x24FFFFFF))),
                    child: Text(f, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
              ]),
            ],
            if ('${i['description'] ?? ''}'.isNotEmpty) ...[const SizedBox(height: 12), Text('${i['description']}', style: const TextStyle(fontSize: 14, height: 1.55, color: Color(0xFFD6D6D6)))],
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0x0DFFFFFF), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0x1FFFFFFF))),
              child: Row(children: [
                Container(
                  width: 44,
                  height: 44,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(color: const Color(0xFF262626), borderRadius: BorderRadius.circular(12)),
                  child: '${i['logo'] ?? ''}'.isNotEmpty ? Image.network('${i['logo']}', fit: BoxFit.cover, errorBuilder: (_, _, _) => const Icon(Icons.storefront_outlined, color: Color(0xFFBDBDBD))) : const Icon(Icons.storefront_outlined, color: Color(0xFFBDBDBD)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Flexible(child: Text('${i['business'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700))),
                      if (i['verified'] == true) ...[const SizedBox(width: 6), const StatusPill('open', label: 'Verified')],
                    ]),
                    Text([i['town'], i['region']].where((v) => v != null && '$v'.isNotEmpty).join(', ').ifEmpty('Ghana'), style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 14),
            Wrap(spacing: 8, runSpacing: 8, children: [
              if (canOrder && accepting && !eq && _n(i['price']) > 0 && i['quantity'] != 0) SmallButton('Buy', onPressed: () => _order(i, 'product', i['price'])),
              if (canOrder && accepting && eq && _n(i['daily_rate']) > 0) SmallButton('Rent', onPressed: () => _order(i, 'equipment_rental', i['daily_rate'])),
              if (canOrder && accepting && eq && _n(i['sale_price']) > 0) SmallButton('Buy', onPressed: () => _order(i, 'equipment_sale', i['sale_price'])),
              SmallButton('Message supplier', light: false, onPressed: () => startConversationWith(context, '${i['business_id']}')),
            ]),
            if (!canOrder || !accepting)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(!canOrder ? 'Ordering through escrow is for company and client accounts. Message the supplier to ask about price and delivery.' : 'This supplier isn\'t taking orders right now. Message them to ask.', style: const TextStyle(fontSize: 12, color: AppColors.muted, height: 1.5)),
              ),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }

  void _order(Json item, String kind, Object? price) {
    Navigator.of(context).pop();
    showGlassSheet(context, title: kind == 'equipment_rental' ? 'Rent equipment' : 'Place order', child: _OrderSheet(item: item, kind: kind, price: num.tryParse('$price') ?? 0));
  }
}

extension on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}

class _OrderSheet extends ConsumerStatefulWidget {
  const _OrderSheet({required this.item, required this.kind, required this.price});
  final Json item;
  final String kind;
  final num price;
  @override
  ConsumerState<_OrderSheet> createState() => _OrderSheetState();
}

class _OrderSheetState extends ConsumerState<_OrderSheet> {
  final _qty = TextEditingController(text: '1'), _days = TextEditingController(text: '1'), _note = TextEditingController();
  late final TextEditingController _addr;
  num _bal = 0;
  bool _busy = false;
  String? _err;

  @override
  void initState() {
    super.initState();
    final p = ref.read(accountProfileProvider).asData?.value?.row ?? const {};
    _addr = TextEditingController(text: [p['physical_address'], p['city_town'], p['region']].where((v) => v != null && '$v'.isNotEmpty).join(', '));
    sb.from('wallet_accounts').select('available_ghs').eq('owner_id', myId).maybeSingle().then((r) {
      if (mounted) setState(() => _bal = num.tryParse('${r?['available_ghs'] ?? 0}') ?? 0);
    });
  }

  @override
  void dispose() {
    for (final c in [_qty, _days, _note, _addr]) {
      c.dispose();
    }
    super.dispose();
  }

  int get _q => widget.kind == 'equipment_sale' ? 1 : (int.tryParse(_qty.text) ?? 0);
  int get _d => widget.kind == 'equipment_rental' ? (int.tryParse(_days.text) ?? 0) : 1;

  @override
  Widget build(BuildContext context) {
    final rent = widget.kind == 'equipment_rental';
    final stock = num.tryParse('${widget.item['quantity'] ?? ''}');
    final ok = _q >= 1 && _d >= 1 && (stock == null || _q <= stock);
    final total = (widget.price * _q * _d * 100).round() / 100;
    final short = ((total - _bal) * 100).round() / 100;
    return Flexible(
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('${widget.item['name']} from ${widget.item['business']} · ${money(widget.price)}${rent ? '/day' : widget.kind == 'product' ? ' each' : ''}. Your payment is held in escrow and only released to the supplier when you confirm you received it.', style: const TextStyle(fontSize: 13, color: AppColors.muted, height: 1.4)),
          const SizedBox(height: 12),
          Row(children: [
            if (rent) Expanded(child: field('Days', _days, number: true)),
            if (rent) const SizedBox(width: 10),
            if (widget.kind != 'equipment_sale') Expanded(child: field(rent ? 'Units' : 'Quantity', _qty, number: true)),
          ]),
          field('Delivery address', _addr, hint: 'Where should it be delivered?'),
          field('Note to supplier (optional)', _note, lines: 2),
          if (ok) ...[
            KV('Held in escrow', money(total), strong: true),
            KV('Your balance after', money((_bal - total).clamp(0, double.infinity))),
            if (short > 0) Note('You need ${money(short)} more in your wallet.', icon: Icons.account_balance_wallet_outlined),
          ] else if (stock != null && _q > stock)
            Text('Only $stock in stock.', style: const TextStyle(color: AppColors.red, fontSize: 12.5)),
          if (_err != null) Text(_err!, style: const TextStyle(color: AppColors.red, fontSize: 12.5)),
          const SizedBox(height: 10),
          if (short > 0)
            PillButton(label: 'Add money', onPressed: () {
              Navigator.of(context).pop();
              context.push(AppRoutes.wallet);
            })
          else
            PillButton(
              label: 'Pay and place order',
              icon: Icons.shield_outlined,
              loading: _busy,
              onPressed: !ok || _busy || _addr.text.trim().isEmpty
                  ? null
                  : () async {
                      setState(() {
                        _busy = true;
                        _err = null;
                      });
                      try {
                        final r = asMap(await rpcCall('place_order', {'p_kind': widget.kind, 'p_item': widget.item['id'], 'p_qty': _q, 'p_days': rent ? _d : null, 'p_address': _addr.text.trim(), 'p_note': _note.text.trim().isEmpty ? null : _note.text.trim()}));
                        ref.invalidate(ordersProvider);
                        if (!context.mounted) return;
                        Navigator.of(context).pop();
                        toast(context, 'Order placed. ${money(r['amount'])} is held in escrow.');
                        context.push('${AppRoutes.orders}/${r['order_id']}');
                      } catch (e) {
                        final m = friendlyError(e);
                        final s = RegExp(r'insufficient_funds:([\d.]+)').firstMatch(m);
                        if (mounted) setState(() => _err = s != null ? 'You need ${money(s[1])} more in your wallet.' : m);
                      }
                      if (mounted) setState(() => _busy = false);
                    },
            ),
          const SizedBox(height: 8),
          Text('Your wallet balance: ${money(_bal)}. The supplier has 3 days to accept, or you are refunded automatically.', textAlign: TextAlign.center, style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
        ]),
      ),
    );
  }
}

// ======================================================================
// Orders
// ======================================================================
const _st = {'placed': 'Awaiting supplier', 'accepted': 'Preparing', 'delivered': 'Delivered', 'completed': 'Completed', 'declined': 'Declined', 'cancelled': 'Cancelled', 'disputed': 'In dispute', 'refunded': 'Refunded'};
Widget _orderPill(Object? s) => StatusPill(s == 'completed' ? 'done' : ['placed', 'accepted', 'delivered'].contains(s) ? 'pending' : '', label: _st['$s'] ?? prettyText(s));

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sup = ref.watch(accountProfileProvider).asData?.value?.type == AccountType.business;
    return DashPage<List<Json>>(
      head: backHead(context, sup ? 'Orders' : 'My orders'),
      data: ref.watch(ordersProvider),
      onRefresh: () => ref.refresh(ordersProvider.future),
      builder: (all) {
        final mine = all.where((o) => o['role'] == (sup ? 'supplier' : 'buyer')).toList();
        bool need(Json o) => sup ? ['placed', 'accepted'].contains(o['status']) : o['status'] == 'delivered';
        Widget card(Json o) => DashRow(
              icon: o['kind'] == 'product' ? Icons.inventory_2_outlined : Icons.construction_outlined,
              title: '${o['item_name'] ?? ''}${(num.tryParse('${o['quantity'] ?? 1}') ?? 1) > 1 ? ' × ${o['quantity']}' : ''}',
              sub: '${o['counterpart'] ?? ''} · ${money(o['amount_ghs'])} · ${ago(o['created_at'])}',
              trailing: _orderPill(o['status']),
              onTap: () => context.push('${AppRoutes.orders}/${o['id']}'),
            );
        if (mine.isEmpty) {
          return [
            DashEmpty(
              icon: Icons.inventory_2_outlined,
              title: 'No orders yet',
              text: sup ? 'When a buyer orders from your catalog, it shows here with the payment already held in escrow.' : 'Buy materials or rent equipment from verified suppliers. Your payment stays safe in escrow until you confirm delivery.',
              action: sup ? null : SmallButton('Browse materials', onPressed: () => context.push(AppRoutes.materials)),
            ),
          ];
        }
        final act = mine.where(need).toList(), rest = mine.where((o) => !need(o)).toList();
        return [
          if (act.isNotEmpty) ...[SecLabel(sup ? 'Needs your action' : 'Waiting for you to confirm'), for (final o in act) card(o)],
          if (rest.isNotEmpty) ...[SecLabel(act.isNotEmpty ? 'All orders' : 'Orders'), for (final o in rest) card(o)],
        ];
      },
    );
  }
}

class OrderDetailScreen extends ConsumerWidget {
  const OrderDetailScreen({required this.id, super.key});
  final String id;

  static const _kind = {'product': 'Product', 'equipment_sale': 'Equipment purchase', 'equipment_rental': 'Equipment rental'};
  static const _reasons = ['The item was not delivered', 'The item is not as described', 'The item is damaged or faulty', 'The buyer is not responding', 'Something else'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DashPage<List<Json>>(
      head: backHead(context, 'Order'),
      data: ref.watch(ordersProvider),
      onRefresh: () => ref.refresh(ordersProvider.future),
      builder: (all) {
        final o = all.where((x) => '${x['id']}' == id).firstOrNull;
        if (o == null) return [DashEmpty(icon: Icons.inventory_2_outlined, title: 'Not found', text: 'This order doesn\'t exist or isn\'t yours.', action: SmallButton('Back', onPressed: () => context.pop()))];
        final sup = o['role'] == 'supplier', s = '${o['status']}';
        final gone = ['declined', 'cancelled', 'refunded'].contains(s);
        Future<void> go(String fn, Map<String, dynamic> p, String ok) async {
          if (await runAction(context, () => rpcCall(fn, p), ok: ok)) ref.invalidate(ordersProvider);
        }

        void confirm(String title, String text, String label, Future<void> Function() then) => showGlassSheet(
              context,
              title: title,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(text, style: const TextStyle(fontSize: 13, color: AppColors.muted, height: 1.4)),
                const SizedBox(height: 14),
                Builder(builder: (c) => PillButton(label: label, onPressed: () {
                      Navigator.of(c).pop();
                      then();
                    })),
              ]),
            );
        final acts = <Widget>[
          if (sup && s == 'placed') ...[
            PillButton(label: 'Accept order', icon: Icons.check, onPressed: () => go('order_accept', {'p_id': id}, 'Order accepted.')),
            PillButton(label: 'Decline and refund', light: false, onPressed: () => confirm('Cancel this order?', 'The payment held in escrow goes back to the buyer\'s wallet and the stock is restored.', 'Yes, cancel and refund', () => go('order_cancel', {'p_id': id}, 'Cancelled. The payment was refunded.'))),
          ],
          if (sup && s == 'accepted') ...[
            PillButton(label: 'Mark as delivered', icon: Icons.check, onPressed: () => go('order_deliver', {'p_id': id, 'p_note': null}, 'Marked as delivered.')),
            PillButton(label: 'Cancel order', light: false, onPressed: () => confirm('Cancel this order?', 'The payment held in escrow goes back to the buyer\'s wallet and the stock is restored.', 'Yes, cancel and refund', () => go('order_cancel', {'p_id': id}, 'Cancelled. The payment was refunded.'))),
          ],
          if (!sup && s == 'placed') PillButton(label: 'Cancel and refund', light: false, onPressed: () => confirm('Cancel this order?', 'Your payment held in escrow goes back to your wallet.', 'Yes, cancel and refund', () => go('order_cancel', {'p_id': id}, 'Cancelled. The payment was refunded.'))),
          if (!sup && ['accepted', 'delivered'].contains(s))
            PillButton(label: 'I received it, release payment', icon: Icons.check, onPressed: () => confirm('Release payment', 'This pays the supplier. You can\'t undo it, so only confirm if you have received the order and are happy with it.', 'Yes, release payment', () => go('order_receive', {'p_id': id}, 'Payment released.'))),
          if (['accepted', 'delivered'].contains(s)) PillButton(label: 'Report a problem', light: false, onPressed: () => _dispute(context, ref)),
        ];
        final done = s == 'completed', fee = o['commission_ghs'], net = o['net_ghs'];
        return [
          SurfaceCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Expanded(child: Text('${_kind['${o['kind']}'] ?? 'Order'} · ${sup ? 'Buyer' : 'Supplier'}', style: const TextStyle(fontSize: 12, color: AppColors.muted))), _orderPill(s)]),
              const SizedBox(height: 4),
              Text('${o['item_name'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              Text('${o['counterpart'] ?? '—'}', style: const TextStyle(fontSize: 13, color: AppColors.muted)),
              const SizedBox(height: 10),
              Text(sup ? 'Secured for you' : 'Held in escrow', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
              Text(money(o['amount_ghs']), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
              Text('${money(o['unit_price'])}${o['kind'] == 'equipment_rental' ? '/day' : ''} × ${o['quantity']}${o['days'] != null ? ' × ${o['days']} day${o['days'] == 1 ? '' : 's'}' : ''}', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
            ]),
          ),
          const SizedBox(height: 10),
          if (!gone)
            SurfaceCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _step('Order placed · payment held in escrow', true),
                _step(sup ? 'You accept the order' : 'Supplier accepts', o['accepted_at'] != null),
                _step(sup ? 'You deliver' : 'Supplier delivers', o['delivered_at'] != null),
                _step(sup ? 'Buyer confirms, you are paid' : 'You confirm receipt', done),
              ]),
            ),
          if (done && net != null) ...[
            const SizedBox(height: 10),
            SurfaceCard(child: Column(children: [
              KV('Order total', money(o['amount_ghs'])),
              if (sup) ...[KV('BAID X fee', '− ${money(fee)}'), KV('You received', money(net), strong: true)] else KV('Paid to supplier', money(o['amount_ghs'])),
            ])),
          ],
          const SizedBox(height: 10),
          SurfaceCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Deliver to', style: TextStyle(fontSize: 12, color: AppColors.muted)),
            Text('${o['delivery_address'] ?? '—'}', style: const TextStyle(fontSize: 13.5)),
            if ('${o['note'] ?? ''}'.isNotEmpty) ...[const SizedBox(height: 8), const Text('Note', style: TextStyle(fontSize: 12, color: AppColors.muted)), Text('${o['note']}')],
            if ('${o['delivery_note'] ?? ''}'.isNotEmpty) ...[const SizedBox(height: 8), const Text('Delivery note', style: TextStyle(fontSize: 12, color: AppColors.muted)), Text('${o['delivery_note']}')],
          ])),
          if (s == 'disputed') ...[const SizedBox(height: 10), Note('This is in dispute. The money stays safe in escrow while BAID X reviews it. ${o['dispute_reason'] ?? ''}')],
          if ('${o['resolution_note'] ?? ''}'.isNotEmpty) Note('BAID X decision: ${o['resolution_note']}'),
          if (gone) Note(sup ? 'This order did not go ahead. The buyer was refunded.' : 'This order did not go ahead. Your payment was refunded to your wallet.'),
          const SizedBox(height: 10),
          for (final a in acts) Padding(padding: const EdgeInsets.only(bottom: 8), child: a),
          Note(sup ? 'The buyer\'s payment is already held by BAID X. It is released to you when they confirm receipt, or 3 days after you mark it delivered.' : 'Your money is held by BAID X. The supplier only gets it when you confirm receipt, or 3 days after delivery if you do nothing.'),
          Text('Ref ${o['public_id'] ?? ''}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
        ];
      },
    );
  }

  Widget _step(String t, bool done) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          Icon(done ? Icons.check_circle : Icons.radio_button_unchecked, size: 18, color: done ? AppColors.green : AppColors.muted),
          const SizedBox(width: 10),
          Expanded(child: Text(t, style: TextStyle(fontSize: 13, color: done ? null : AppColors.muted))),
        ]),
      );

  void _dispute(BuildContext context, WidgetRef ref) {
    var reason = _reasons.first;
    final details = TextEditingController();
    showGlassSheet(
      context,
      title: 'Report a problem',
      child: StatefulBuilder(
        builder: (c, set) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('The money stays frozen in escrow while BAID X reviews. Be specific so we can decide quickly.', style: TextStyle(fontSize: 13, color: AppColors.muted, height: 1.4)),
          const SizedBox(height: 12),
          dropdown('What is the problem?', reason, [for (final r in _reasons) (r, r)], (v) => set(() => reason = v ?? reason)),
          field('Details', details, lines: 4),
          PillButton(label: 'Open dispute', onPressed: () async {
            Navigator.of(c).pop();
            if (await runAction(context, () => rpcCall('order_dispute', {'p_id': id, 'p_reason': reason, 'p_details': details.text.trim().isEmpty ? null : details.text.trim()}), ok: 'Dispute opened. BAID X will review.')) {
              ref.invalidate(ordersProvider);
            }
          }),
        ]),
      ),
    );
  }
}

// ======================================================================
// Organizations
// ======================================================================
String _initials(Object? n) => '${n ?? '?'}'.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).take(2).map((w) => w[0]).join().toUpperCase();
Widget _orgPill(Object? s) {
  final k = '$s';
  final kind = const {'ACTIVE': 'done', 'ACCEPTED': 'done', 'INVITED': 'pending', 'PENDING_VERIFICATION': 'pending', 'SUSPENDED': 'pending'}[k] ?? '';
  return StatusPill(kind, label: prettyText(k.toLowerCase()));
}

String _roleLabel(Json m, Object? key) => asList(m['roles']).where((r) => r['key'] == key).map((r) => '${r['label']}').firstOrNull ?? prettyText(key);

class OrgsScreen extends ConsumerStatefulWidget {
  const OrgsScreen({super.key});
  @override
  ConsumerState<OrgsScreen> createState() => _OrgsScreenState();
}

class _OrgsScreenState extends ConsumerState<OrgsScreen> {
  final _token = TextEditingController();

  @override
  void dispose() {
    _token.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    var t = _token.text.trim();
    final i = t.indexOf('/join/');
    if (i >= 0) t = t.substring(i + 6);
    if (t.isEmpty) return toast(context, 'Paste your invitation link or code.');
    try {
      final id = await rpcCall('accept_org_invitation', {'p_token': t});
      ref.invalidate(myOrgsProvider);
      if (mounted) context.push('${AppRoutes.orgs}/$id');
    } catch (_) {
      if (mounted) toast(context, 'This invitation is invalid, expired, used, or sent to a different account.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = ref.watch(accessMatrixProvider).asData?.value ?? const {};
    return DashPage<List<Json>>(
      head: backHead(context, 'Organizations', action: SmallButton('New', onPressed: _newOrg)),
      data: ref.watch(myOrgsProvider),
      onRefresh: () async {
        ref.invalidate(accessMatrixProvider);
        ref.invalidate(myOrgsProvider);
        await ref.read(myOrgsProvider.future);
      },
      builder: (list) => [
        if (list.isEmpty)
          const DashEmpty(icon: Icons.groups_outlined, title: 'No organization yet', text: 'Create one for your company or crew, then invite people with the right access. Or open an invitation link someone sent you.')
        else
          for (final o in list)
            DashRow(
              leading: Container(width: 38, height: 38, alignment: Alignment.center, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(11)), child: Text(_initials(o['name']), style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 13))),
              title: '${o['name'] ?? ''}',
              below: Padding(padding: const EdgeInsets.only(top: 3), child: Row(children: [CodeTag('${o['public_code'] ?? ''}'), const SizedBox(width: 6), Flexible(child: Text(_roleLabel(m, o['role_key']), style: const TextStyle(fontSize: 12, color: AppColors.muted)))])),
              trailing: _orgPill(o['status']),
              onTap: () => context.push('${AppRoutes.orgs}/${o['org_id']}'),
            ),
        const SizedBox(height: 6),
        SurfaceCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('Have an invitation?', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: TextField(controller: _token, decoration: const InputDecoration(hintText: 'Paste your invitation link or code', contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 13)))),
              const SizedBox(width: 8),
              SmallButton('Join', onPressed: _join),
            ]),
          ]),
        ),
      ],
    );
  }

  void _newOrg() {
    final name = TextEditingController();
    var type = 'company';
    showGlassSheet(
      context,
      title: 'New organization',
      child: StatefulBuilder(
        builder: (c, set) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          field('Organization name', name, hint: 'e.g. Mensah Builders Ltd'),
          dropdown('Type', type, const [('company', 'Company'), ('crew', 'Crew or contractor'), ('supplier', 'Supplier')], (v) => set(() => type = v ?? type)),
          PillButton(label: 'Create organization', onPressed: () async {
            if (name.text.trim().length < 2) return toast(context, 'Give it a name.');
            try {
              final id = await rpcCall('create_org', {'p_name': name.text.trim(), 'p_type': type});
              ref.invalidate(myOrgsProvider);
              if (c.mounted) Navigator.of(c).pop();
              if (mounted) {
                toast(context, 'Organization created');
                context.push('${AppRoutes.orgs}/$id');
              }
            } catch (e) {
              if (mounted) toast(context, friendlyError(e));
            }
          }),
        ]),
      ),
    );
  }
}

class OrgDetailScreen extends ConsumerStatefulWidget {
  const OrgDetailScreen({required this.id, super.key});
  final String id;
  @override
  ConsumerState<OrgDetailScreen> createState() => _OrgDetailScreenState();
}

class _OrgDetailScreenState extends ConsumerState<OrgDetailScreen> {
  var _tab = 'people';

  bool _can(Json m, Json org, String res, String act) => org['status'] == 'ACTIVE' && asList(m['grants']).any((g) => g['role'] == org['role_key'] && g['resource'] == res && g['action'] == act);

  @override
  Widget build(BuildContext context) {
    final orgs = ref.watch(myOrgsProvider).asData?.value;
    final m = ref.watch(accessMatrixProvider).asData?.value ?? const {};
    final org = orgs?.where((o) => '${o['org_id']}' == widget.id).firstOrNull;
    final data = _tab == 'roles' ? const AsyncValue<List<Json>>.data([]) : ref.watch(orgTabProvider((widget.id, _tab)));
    return DashPage<List<Json>>(
      head: backHead(context, '${org?['name'] ?? 'Organization'}'),
      top: [
        if (org != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [CodeTag('${org['public_code'] ?? ''}'), const SizedBox(width: 8), Text('You are ${_roleLabel(m, org['role_key'])}', style: const TextStyle(fontSize: 12.5, color: AppColors.muted))])),
        DashSegs(items: const [('people', 'People'), ('invites', 'Invitations'), ('roles', 'Roles & access'), ('audit', 'Activity')], active: _tab, onTap: (k) => setState(() => _tab = k)),
      ],
      data: orgs == null ? const AsyncValue<List<Json>>.loading() : data,
      onRefresh: () async {
        ref.invalidate(myOrgsProvider);
        ref.invalidate(orgTabProvider((widget.id, _tab)));
      },
      builder: (rows) {
        if (org == null) return [DashEmpty(icon: Icons.groups_outlined, title: 'Organization not found', text: 'You are not a member of this organization.', action: SmallButton('All organizations', onPressed: () => context.pop()))];
        if (org['status'] != 'ACTIVE') return [DashEmpty(icon: Icons.lock_outline, title: 'Access paused', text: 'Your access is ${'${org['status']}'.toLowerCase()}. Contact an organization owner.')];
        final invite = _can(m, org, 'invitations', 'CREATE') ? SmallButton('Invite person', onPressed: () => _invite(m, org)) : null;
        switch (_tab) {
          case 'roles':
            return [
              const Text('Every role below is a credential profile. Access is deny-by-default: anything not listed is blocked.', style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
              const SizedBox(height: 10),
              for (final r in asList(m['roles']).where((r) => r['tier'] == 'organization'))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SurfaceCard(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Text('${r['label']}', style: const TextStyle(fontWeight: FontWeight.w700))),
                        if (r['key'] == org['role_key']) const StatusPill('done', label: 'You'),
                      ]),
                      const SizedBox(height: 4),
                      Text('${r['description'] ?? ''}', style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
                    ]),
                  ),
                ),
            ];
          case 'invites':
            return [
              Row(children: [const Expanded(child: SecLabel('Invitations')), ?invite]),
              if (rows.isEmpty)
                const DashEmpty(icon: Icons.mail_outline, title: 'No invitations', text: 'Invite people with the role they need.')
              else
                for (final i in rows)
                  DashRow(
                    icon: Icons.mail_outline,
                    title: '${i['contact'] ?? ''}',
                    sub: '${i['role_label'] ?? ''} · expires ${_date(i['expires_at'])}',
                    trailing: _orgPill(i['status']),
                    below: i['status'] == 'INVITED' && _can(m, org, 'invitations', 'EDIT')
                        ? Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: SmallButton('Cancel', light: false, onPressed: () async {
                              if (await runAction(context, () => rpcCall('org_revoke_invitation', {'p_invitation': i['id']}), ok: 'Invitation cancelled')) ref.invalidate(orgTabProvider((widget.id, 'invites')));
                            }),
                          )
                        : null,
                  ),
            ];
          case 'audit':
            if (!_can(m, org, 'audit', 'VIEW')) return const [DashEmpty(icon: Icons.lock_outline, title: 'Not available', text: 'Your role does not include the activity log.')];
            return rows.isEmpty
                ? const [DashEmpty(icon: Icons.history, title: 'No activity yet', text: 'Every change to people, roles and access is recorded here.')]
                : [for (final a in rows) DashRow(icon: Icons.history, title: prettyText('${a['action']}'.replaceAll('.', ' · ')), sub: '${a['actor'] ?? ''} · ${ago(a['at'])}')];
          default:
            return [
              Row(children: [Expanded(child: SecLabel('${rows.length} ${rows.length == 1 ? 'person' : 'people'}')), ?invite]),
              for (final p in rows)
                DashRow(
                  leading: InitialsAvatar(name: '${p['name'] ?? ''}', size: 38, radius: 19),
                  title: '${p['name'] ?? ''}${p['user_id'] == myId ? ' (you)' : ''}',
                  sub: '${p['role_label'] ?? ''}',
                  trailing: _orgPill(p['status']),
                  onTap: p['user_id'] == myId ? null : () => _member(m, org, p),
                ),
            ];
        }
      },
    );
  }

  void _invite(Json m, Json org) {
    final contact = TextEditingController();
    final mine = asList(m['roles']).where((r) => r['key'] == org['role_key']).firstOrNull;
    final roles = asList(m['roles']).where((r) => r['tier'] == 'organization' && (org['role_key'] == 'org_owner' || (num.tryParse('${r['rank']}') ?? 0) > (num.tryParse('${mine?['rank'] ?? 99}') ?? 99))).toList();
    var role = roles.isEmpty ? null : '${roles.first['key']}';
    showGlassSheet(
      context,
      title: 'Invite person',
      child: StatefulBuilder(
        builder: (c, set) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          field('Email or phone', contact, hint: 'name@email.com or 055…', helper: 'They must sign in with this email or phone to accept.'),
          dropdown('Role', role, [for (final r in roles) ('${r['key']}', '${r['label']}')], (v) => set(() => role = v)),
          PillButton(label: 'Create invitation', onPressed: () async {
            if (contact.text.trim().isEmpty || role == null) return toast(context, 'Add their email or phone.');
            try {
              final token = await rpcCall('org_invite', {'p_org': widget.id, 'p_contact': contact.text.trim(), 'p_role': role});
              ref.invalidate(orgTabProvider((widget.id, 'invites')));
              if (c.mounted) Navigator.of(c).pop();
              final link = '${AppConfig.webBase}/#/join/$token';
              await Clipboard.setData(ClipboardData(text: link));
              if (mounted) toast(context, 'Invitation link copied. It works once and expires in 7 days.');
            } catch (e) {
              if (mounted) toast(context, friendlyError(e));
            }
          }),
        ]),
      ),
    );
  }

  void _member(Json m, Json org, Json p) {
    final roles = asList(m['roles']).where((r) => r['tier'] == 'organization').toList();
    var role = '${p['role_key'] ?? (roles.isEmpty ? '' : roles.first['key'])}';
    Future<void> status(String s) async {
      Navigator.of(context).pop();
      if (await runAction(context, () => rpcCall('org_set_member_status', {'p_member': p['member_id'], 'p_status': s, 'p_reason': null}), ok: s == 'ACTIVE' ? 'Access restored' : 'Access changed immediately')) {
        ref.invalidate(orgTabProvider((widget.id, 'people')));
      }
    }

    showGlassSheet(
      context,
      title: '${p['name'] ?? 'Member'}',
      child: StatefulBuilder(
        builder: (c, set) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          KV('Role', '${p['role_label'] ?? ''}'),
          KV('Status', prettyText('${p['status']}'.toLowerCase())),
          const SizedBox(height: 10),
          if (roles.any((r) => r['key'] == role)) dropdown('Change role', role, [for (final r in roles) ('${r['key']}', '${r['label']}')], (v) => set(() => role = v ?? role)),
          PillButton(label: 'Save role', onPressed: () async {
            Navigator.of(c).pop();
            if (await runAction(context, () => rpcCall('org_set_member_role', {'p_member': p['member_id'], 'p_role': role}), ok: 'Role updated')) ref.invalidate(orgTabProvider((widget.id, 'people')));
          }),
          const SizedBox(height: 8),
          if (p['status'] == 'ACTIVE') PillButton(label: 'Suspend', light: false, onPressed: () => status('SUSPENDED')),
          if (p['status'] != 'ACTIVE' && p['status'] != 'REVOKED') PillButton(label: 'Reactivate', light: false, onPressed: () => status('ACTIVE')),
          if (p['status'] != 'REVOKED') ...[const SizedBox(height: 8), PillButton(label: 'Remove access', light: false, onPressed: () => status('REVOKED'))],
        ]),
      ),
    );
  }
}
