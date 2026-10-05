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

  String get kindLabel => const {'worker': 'Professional', 'company': 'Company', 'pm': 'Project manager', 'business': 'Supplier'}[kind] ?? 'Member';
}

const directoryChips = [('all', 'All'), ('companies', 'Companies'), ('professionals', 'Professionals'), ('managers', 'Project Managers'), ('businesses', 'Businesses')];

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
        group: 'professionals', kind: 'worker', id: r['id'], name: r['full_name'] ?? 'Professional', image: r['profile_photo_url'],
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

/// Every active member, the earliest to join first: people who came to BAID X
/// first are shown first (same order as the website).
final directoryProvider = FutureProvider<List<DirectoryMember>>((ref) async {
  final client = SupabaseConfig.client;
  if (client == null) throw const ConfigurationException('BAID X is not connected yet.');
  final parts = await Future.wait(_sources.values.map((s) async {
    final rows = await client.from(s.table).select('${s.cols},created_at').or('account_status.is.null,account_status.eq.active').order('created_at', ascending: true).limit(100);
    return [for (final r in rows) (DateTime.tryParse('${r['created_at'] ?? ''}'), s.map(r))];
  }));
  final all = parts.expand((e) => e).toList()
    ..sort((a, b) => (a.$1 ?? DateTime(2100)).compareTo(b.$1 ?? DateTime(2100)));
  return [for (final e in all) e.$2];
});
