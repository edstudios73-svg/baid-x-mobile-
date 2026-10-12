import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/supabase_config.dart';
import '../../../core/errors/app_exception.dart';
import '../../account_type/domain/role_categories.dart';

/// One card in the member directory (website: js/app.js SOURCES → cardHTML).
class DirectoryMember {
  const DirectoryMember({
    required this.group,
    required this.kind,
    required this.id,
    required this.name,
    required this.tag,
    required this.place,
    required this.desc,
    required this.stats,
    this.image,
    this.cover,
    this.badge,
    this.region,
    this.catId,
    this.joined,
    this.rate,
    this.plan,
    this.boosted = false,
  });

  final String group; // companies | professionals | managers | businesses
  final String kind; // company | worker | pm | business
  final String id;
  final String name;
  final String tag;
  final String place;
  final String desc;
  final List<(String, String)> stats;
  final String? image;
  final String? cover;
  final String? badge; // verified | identity | professional | advanced
  final String? region;
  final String? catId; // what Discover's Category filter matches (website catId)
  final DateTime? joined;
  final double? rate; // a professional's daily rate in GH₵, for the price guide
  final String? plan; // pro | premium | enterprise while they pay for a plan (the card's plan mark)
  final bool boosted; // a paid profile boost is running (Featured)

  DirectoryMember withJoined(DateTime? at) => copyWith(joined: at);

  DirectoryMember copyWith({DateTime? joined, String? plan, bool? boosted}) => DirectoryMember(
        group: group, kind: kind, id: id, name: name, tag: tag, place: place, desc: desc, stats: stats, image: image, cover: cover, badge: badge,
        region: region, catId: catId, joined: joined ?? this.joined, rate: rate, plan: plan ?? this.plan, boosted: boosted ?? this.boosted);

  /// "Pro", "Premium" or "Enterprise" for the plan mark beside the name.
  String? get planLabel => plan == null ? null : '${plan![0].toUpperCase()}${plan!.substring(1)}';

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  /// "Joined Sep 2026", as the website card shows it.
  String? get joinedLabel => joined == null ? null : 'Joined ${_months[joined!.month - 1]} ${joined!.year}';

  String get kindLabel => const {'worker': 'Professional', 'company': 'Company', 'pm': 'Project manager', 'business': 'Supplier'}[kind] ?? 'Member';
}

const directoryChips = [('all', 'Everyone'), ('companies', 'Companies'), ('professionals', 'Professionals'), ('managers', 'Project Managers'), ('businesses', 'Businesses')];

String _pretty(Object? v) => (v ?? '').toString().replaceAll('_', ' ').trim().replaceAllMapped(RegExp(r'\b\w'), (m) => m[0]!.toUpperCase());
bool _real(Object? v) => v is String && v.trim().isNotEmpty && !v.toLowerCase().endsWith('.invalid');
String _place(Map r) => [r['city_town'], r['region']].where(_real).join(', ').ifEmpty('Ghana');
String _num(Object? n, [int d = 0]) {
  final v = num.tryParse('${n ?? ''}');
  return v == null ? '—' : v.toStringAsFixed(d);
}

String? _badge(Map r) => r['verification_status'] == 'verified' ? ((r['badge_tier'] as String?) ?? 'verified') : null;

extension on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}

final _tradeById = {for (final c in jobCategories) c.id: c.name};

class _Source {
  const _Source(this.table, this.cols, this.map);
  final String table;
  final String cols;
  final DirectoryMember Function(Map<String, dynamic>) map;
}

final _sources = <String, _Source>{
  'companies': _Source(
    'company_profiles',
    'id,company_name,industry_sector,company_size,city_town,region,company_logo_url,cover_url,company_overview,trust_score,verification_status,badge_tier',
    (r) => DirectoryMember(
      group: 'companies', kind: 'company', id: r['id'], name: r['company_name'] ?? 'Company', image: r['company_logo_url'], cover: r['cover_url'],
      badge: _badge(r), desc: (r['company_overview'] as String?) ?? 'Company on BAID X.', tag: _pretty(r['industry_sector']), place: _place(r), region: r['region'], catId: r['industry_sector'],
      stats: [(_num(r['trust_score'], 1), 'Trust'), (_pretty(r['company_size']).ifEmpty('—'), 'Size')],
    ),
  ),
  'professionals': _Source(
    'worker_profiles',
    'id,full_name,specialty,short_bio,primary_job_category_id,years_of_experience,daily_rate_ghs,city_town,region,profile_photo_url,cover_url,portfolio_photo_urls,rank_tier,verification_status,badge_tier',
    (r) {
      final trade = _tradeById[r['primary_job_category_id']] ?? r['specialty'] as String?;
      final yrs = r['years_of_experience'];
      final photos = (r['portfolio_photo_urls'] as List?)?.whereType<String>().toList() ?? const [];
      return DirectoryMember(
        group: 'professionals', kind: 'worker', id: r['id'], name: r['full_name'] ?? 'Professional', image: r['profile_photo_url'], rate: num.tryParse('${r['daily_rate_ghs'] ?? ''}')?.toDouble(),
        cover: (r['cover_url'] as String?) ?? (photos.isEmpty ? null : photos.first), badge: _badge(r), region: r['region'], catId: r['primary_job_category_id'],
        desc: (r['short_bio'] as String?) ?? (trade != null ? '$trade based in ${r['city_town'] ?? 'Ghana'}.' : 'Skilled professional on BAID X.'),
        tag: trade ?? (_pretty(r['rank_tier']).ifEmpty('Professional')), place: _place(r),
        stats: [
          (r['daily_rate_ghs'] != null ? 'GH₵${_num(r['daily_rate_ghs'])}' : 'On request', 'Daily rate'),
          (yrs != null && '$yrs'.isNotEmpty ? '${_pretty(yrs)}${RegExp(r'^\d').hasMatch('$yrs') ? ' yrs' : ''}' : 'New', 'Experience'),
        ],
      );
    },
  ),
  'managers': _Source(
    'project_manager_profiles',
    'id,full_name,specialization,specialization_tags,years_managing_projects,projects_managed_count,city_town,region,profile_photo_url,cover_url,verification_status,badge_tier',
    (r) => DirectoryMember(
      group: 'managers', kind: 'pm', id: r['id'], name: r['full_name'] ?? 'Project manager', image: r['profile_photo_url'], cover: r['cover_url'],
      badge: _badge(r), region: r['region'], catId: r['specialization'],
      desc: ((r['specialization_tags'] as List?)?.whereType<String>().take(3).join(' · ')).let((s) => s == null || s.isEmpty ? 'Project manager on BAID X.' : s),
      tag: _pretty(r['specialization']).ifEmpty('Project Manager'), place: _place(r),
      stats: [('${r['projects_managed_count'] ?? 0}', 'Projects'), ('${r['years_managing_projects'] ?? 0}', 'Years')],
    ),
  ),
  'businesses': _Source(
    'business_profiles',
    'id,business_name,specialty,short_bio,years_in_operation,crew_size,city_town,region,logo_url,cover_url,portfolio_photo_urls,verification_status,badge_tier',
    (r) {
      final photos = (r['portfolio_photo_urls'] as List?)?.whereType<String>().toList() ?? const [];
      return DirectoryMember(
        group: 'businesses', kind: 'business', id: r['id'], name: r['business_name'] ?? 'Supplier', image: r['logo_url'],
        cover: (r['cover_url'] as String?) ?? (photos.isEmpty ? null : photos.first), badge: _badge(r), region: r['region'], catId: r['specialty'],
        desc: (r['short_bio'] as String?) ?? 'Supplier of products, equipment and materials.', tag: (r['specialty'] as String?) ?? 'Supplier', place: _place(r),
        stats: [('${r['crew_size'] ?? 0}', 'Crew'), ('${r['years_in_operation'] ?? 0}', 'Years')],
      );
    },
  ),
};

extension _Let<T> on T {
  R let<R>(R Function(T) f) => f(this);
}

const _planRank = {'enterprise': 3, 'premium': 2, 'pro': 1};

/// Discover order, same as the website's rankMembers: boosted profiles, then paid
/// plans (Enterprise, Premium, Pro), then verified members, then the earliest to join.
/// [promo] is the public `promoted()` result: {members: [{id, tier}], boosts: [{type, id}]}.
List<DirectoryMember> rankMembers(List<DirectoryMember> list, Map promo) {
  final plans = {for (final m in (promo['members'] as List? ?? const [])) if (m is Map) '${m['id']}': '${m['tier']}'};
  final boosted = {
    for (final b in (promo['boosts'] as List? ?? const []))
      if (b is Map && !const ['job', 'project', 'business_listing'].contains(b['type'])) '${b['id']}',
  };
  final out = [for (final m in list) m.copyWith(plan: plans[m.id], boosted: boosted.contains(m.id))];
  int cmp(DirectoryMember a, DirectoryMember b) {
    if (a.boosted != b.boosted) return a.boosted ? -1 : 1;
    final p = (_planRank[b.plan] ?? 0) - (_planRank[a.plan] ?? 0);
    if (p != 0) return p;
    if ((a.badge != null) != (b.badge != null)) return a.badge != null ? -1 : 1;
    return (a.joined ?? DateTime(2100)).compareTo(b.joined ?? DateTime(2100));
  }
  // List.sort isn't stable; ties keep their place by index
  final idx = {for (final (i, m) in out.indexed) m: i};
  out.sort((a, b) { final c = cmp(a, b); return c != 0 ? c : idx[a]! - idx[b]!; });
  return out;
}

/// Who pays for a plan and what is boosted right now (public by design: it is what
/// the Pro mark and Featured placement show). Empty on any error.
Future<Map> fetchPromoted() async {
  try {
    final r = await SupabaseConfig.client?.rpc('promoted');
    return r is Map ? r : const {};
  } catch (_) {
    return const {};
  }
}

/// Every active member in Discover order (see [rankMembers]); same as the website.
final directoryProvider = FutureProvider<List<DirectoryMember>>((ref) async {
  final client = SupabaseConfig.client;
  if (client == null) throw const ConfigurationException('BAID X is not connected yet.');
  final promo = fetchPromoted();
  final parts = await Future.wait(_sources.values.map((s) async {
    final rows = await client.from(s.table).select('${s.cols},created_at').or('account_status.is.null,account_status.eq.active').order('created_at', ascending: true).limit(100);
    return [for (final r in rows) (DateTime.tryParse('${r['created_at'] ?? ''}'), s.map(r))];
  })).timeout(const Duration(seconds: 8)); // a slow network shows "couldn't load", not a spinner for ever
  final all = [for (final e in parts.expand((e) => e)) e.$2.withJoined(e.$1)];
  return rankMembers(all, await promo);
});

/// What signed-out visitors see on Home: up to [perGroup] members of each type, only
/// verified ones with a profile photo and a cover photo, those with a written
/// description first. Everyone else opens after signing in (Discover).
List<DirectoryMember> guestShowcase(List<DirectoryMember> list, {int perGroup = 4}) {
  bool has(String? s) => s != null && s.trim().isNotEmpty;
  final ready = [
    for (final (i, m) in list.indexed)
      if (m.badge != null && has(m.image) && has(m.cover)) (i, m),
  ];
  // a real description reads better than the default line; keep join order otherwise
  int rank((int, DirectoryMember) e) => e.$2.desc.trim().length >= 25 ? 0 : 1;
  ready.sort((a, b) => rank(a) != rank(b) ? rank(a) - rank(b) : a.$1 - b.$1);
  final taken = <String, int>{};
  final out = <DirectoryMember>[];
  for (final (_, m) in ready) {
    final n = taken[m.group] ?? 0;
    if (n >= perGroup) continue;
    taken[m.group] = n + 1;
    out.add(m);
  }
  return out;
}

/// One line of the price guide: what professionals in a trade charge per day.
class TradeRate {
  const TradeRate({required this.trade, required this.median, required this.low, required this.high});
  final String trade;
  final double median;
  final double low;
  final double high;
}

/// A trade shows in the price guide only with at least this many rates, after rates far
/// from the middle (under a third or over three times it) are dropped, so one odd rate
/// can't set the guide. Same rule as the website's js/landing.js.
const minRateSamples = 3;

double _middle(List<double> v) => v.length.isOdd ? v[v.length ~/ 2] : (v[v.length ~/ 2 - 1] + v[v.length ~/ 2]) / 2;

/// Daily rates by trade from what professionals set on BAID X, optionally in one
/// region. Shows the middle rate and the range; never how many people are behind it.
List<TradeRate> tradeRates(List<DirectoryMember> all, {String? region}) {
  final by = <String, List<double>>{};
  for (final m in all) {
    final r = m.rate;
    if (m.kind != 'worker' || r == null || r <= 0 || m.tag.trim().isEmpty) continue;
    if (region != null && (m.region ?? '').toLowerCase() != region.toLowerCase()) continue;
    by.putIfAbsent(m.tag, () => []).add(r);
  }
  final out = <TradeRate>[
    for (final e in by.entries)
      if (_steady(e.value) case final v? when v.length >= minRateSamples)
        TradeRate(trade: e.key, median: _middle(v), low: v.first, high: v.last),
  ]..sort((a, b) => a.trade.toLowerCase().compareTo(b.trade.toLowerCase()));
  return out;
}

List<double>? _steady(List<double> rates) {
  final all = [...rates]..sort();
  if (all.isEmpty) return null;
  final m0 = _middle(all);
  return all.where((r) => r >= m0 / 3 && r <= m0 * 3).toList();
}

/// Regions with at least one trade in the price guide, for the guide's filter.
List<String> rateRegions(List<DirectoryMember> all) => {
      for (final m in all)
        if (m.kind == 'worker' && (m.rate ?? 0) > 0 && (m.region ?? '').trim().isNotEmpty) m.region!.trim()
    }.where((r) => tradeRates(all, region: r).isNotEmpty).toList()
      ..sort();

/// The badge check: verified members whose name matches what was typed (three letters
/// or more). It answers "has BAID X verified this person?", not "who is on BAID X".
List<DirectoryMember> checkMembers(List<DirectoryMember> all, String query) {
  final q = query.trim().toLowerCase();
  if (q.length < 3) return const [];
  final hits = all.where((m) => m.badge != null && m.name.toLowerCase().contains(q)).toList()
    ..sort((a, b) => (a.name.toLowerCase().startsWith(q) ? 0 : 1) - (b.name.toLowerCase().startsWith(q) ? 0 : 1));
  return hits.take(8).toList();
}
