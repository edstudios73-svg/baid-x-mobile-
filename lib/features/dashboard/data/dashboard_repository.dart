import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';
import '../../../core/errors/app_exception.dart';
import '../domain/role_dashboard.dart';

abstract class DashboardRepository {
  Future<RoleDashboard> loadWorker(String userId);
  Future<RoleDashboard> loadEmployer(String userId);
  Future<RoleDashboard> loadBusiness(String userId);
  Future<RoleDashboard> loadProjectManager(String userId);
  Future<RoleDashboard> loadCompany(String userId);
}

class SupabaseDashboardRepository implements DashboardRepository {
  SupabaseClient get _client {
    final client = SupabaseConfig.client;
    if (client == null) {
      throw const ConfigurationException(
        'BAID X is not connected yet. Add the Supabase URL and publishable key to .env.',
      );
    }
    return client;
  }

  @override
  Future<RoleDashboard> loadWorker(String userId) async {
    final profile = await _one('profiles', 'id', userId);
    final worker = await _one('worker_profiles', 'profile_id', userId);
    final jobs = await _rows(
      'jobs',
      columns: 'title, location_label',
      filters: {'is_public': true, 'status': 'open'},
    );
    final applications = await _rows(
      'job_applications',
      columns: 'status',
      filters: {'worker_profile_id': userId},
    );
    final name = _text(profile, 'display_name');
    final location = _text(profile, 'location_label');
    final trade = _text(worker, 'trade');
    final availability = _text(worker, 'availability');
    final summary = _text(worker, 'summary');
    return RoleDashboard(
      name: name,
      location: location,
      headline: summary,
      trade: trade,
      availability: availability,
      completionPercent: completionOf([name, location, trade, availability, summary]),
      verified: await _verified(userId),
      reviewCount: await _reviewCount(userId),
      jobs: _items(jobs, 'title', 'location_label'),
      applications: [
        for (final row in applications) ListedItem(title: _label(row['status']), detail: 'Application'),
      ],
    );
  }

  @override
  Future<RoleDashboard> loadEmployer(String userId) async {
    final profile = await _one('profiles', 'id', userId);
    final jobs = await _rows('jobs', columns: 'title, status', filters: {'owner_profile_id': userId});
    final people = await _rows(
      'profiles',
      columns: 'display_name, location_label',
      filters: {'is_listed': true, 'account_type': 'worker'},
    );
    final name = _text(profile, 'display_name');
    final location = _text(profile, 'location_label');
    final headline = _text(profile, 'headline');
    return RoleDashboard(
      name: name,
      location: location,
      headline: headline,
      completionPercent: completionOf([name, location, headline]),
      verified: await _verified(userId),
      jobs: _items(jobs, 'title', 'status'),
      people: _items(people, 'display_name', 'location_label'),
    );
  }

  @override
  Future<RoleDashboard> loadBusiness(String userId) async {
    final profile = await _one('profiles', 'id', userId);
    final business = await _one('business_profiles', 'profile_id', userId);
    final listings = await _rows(
      'business_listings',
      columns: 'title, listing_kind',
      filters: {'business_profile_id': userId},
    );
    final businessName = _text(business, 'business_name');
    final name = businessName.isEmpty ? _text(profile, 'display_name') : businessName;
    final businessLocation = _text(business, 'location_label');
    final location = businessLocation.isEmpty ? _text(profile, 'location_label') : businessLocation;
    final category = _text(business, 'category');
    final summary = _text(business, 'summary');
    return RoleDashboard(
      name: name,
      location: location,
      headline: summary,
      trade: category,
      completionPercent: completionOf([name, category, location, summary]),
      verified: await _verified(userId),
      listings: _items(listings, 'title', 'listing_kind'),
    );
  }

  @override
  Future<RoleDashboard> loadProjectManager(String userId) async {
    final profile = await _one('profiles', 'id', userId);
    final projects = await _rows(
      'projects',
      columns: 'title, status',
      filters: {'owner_profile_id': userId},
    );
    final tasks = await _rows('project_tasks', columns: 'title, is_done');
    final reports = await _rows(
      'project_reports',
      columns: 'body',
      filters: {'author_profile_id': userId},
    );
    final expenses = await _rows(
      'project_expenses',
      columns: 'description, amount',
      filters: {'submitted_by': userId},
    );
    final name = _text(profile, 'display_name');
    final location = _text(profile, 'location_label');
    final title = _text(profile, 'headline');
    return RoleDashboard(
      name: name,
      location: location,
      headline: title,
      completionPercent: completionOf([name, location, title]),
      verified: await _verified(userId),
      projects: _items(projects, 'title', 'status'),
      tasks: [
        for (final row in tasks)
          ListedItem(title: _text(row, 'title'), detail: row['is_done'] == true ? 'Done' : 'Open'),
      ],
      reports: [
        for (final row in reports)
          if (_text(row, 'body').isNotEmpty) ListedItem(title: _text(row, 'body')),
      ],
      expenses: [
        for (final row in expenses)
          ListedItem(title: _text(row, 'description'), detail: '${row['amount'] ?? ''}'),
      ],
    );
  }

  @override
  Future<RoleDashboard> loadCompany(String userId) async {
    final profile = await _one('profiles', 'id', userId);
    final companies = await _rows(
      'companies',
      columns: 'id, name, industry',
      filters: {'owner_profile_id': userId},
    );
    final jobs = await _rows('jobs', columns: 'title, status', filters: {'owner_profile_id': userId});
    final company = companies.isEmpty ? null : companies.first;
    final companyId = company?['id'] as String?;
    final projects = companyId == null
        ? <Map<String, dynamic>>[]
        : await _rows('projects', columns: 'title, status', filters: {'company_id': companyId});
    final team = companyId == null
        ? <Map<String, dynamic>>[]
        : await _rows(
            'company_members',
            columns: 'member_role, status',
            filters: {'company_id': companyId},
          );
    final companyName = _text(company, 'name');
    final name = companyName.isEmpty ? _text(profile, 'display_name') : companyName;
    final industry = _text(company, 'industry');
    final location = _text(profile, 'location_label');
    return RoleDashboard(
      name: name,
      location: location,
      headline: industry,
      trade: industry,
      completionPercent: completionOf([name, industry, location]),
      verified: await _verified(userId),
      jobs: _items(jobs, 'title', 'status'),
      projects: _items(projects, 'title', 'status'),
      team: _items(team, 'member_role', 'status'),
    );
  }

  Future<bool> _verified(String userId) async {
    final rows = await _client
        .from('verifications')
        .select('id')
        .eq('profile_id', userId)
        .eq('status', 'verified')
        .limit(1);
    return (rows as List).isNotEmpty;
  }

  Future<int> _reviewCount(String userId) async {
    final rows = await _client.from('reviews').select('id').eq('subject_profile_id', userId).limit(21);
    return (rows as List).length;
  }

  Future<Map<String, dynamic>?> _one(String table, String column, String value) async {
    final row = await _client.from(table).select().eq(column, value).maybeSingle();
    if (row == null) return null;
    return Map<String, dynamic>.from(row);
  }

  Future<List<Map<String, dynamic>>> _rows(
    String table, {
    required String columns,
    Map<String, Object> filters = const {},
  }) async {
    var query = _client.from(table).select(columns);
    for (final entry in filters.entries) {
      query = query.eq(entry.key, entry.value);
    }
    final rows = await query.limit(5);
    return [for (final row in rows as List) Map<String, dynamic>.from(row as Map)];
  }

  List<ListedItem> _items(List<Map<String, dynamic>> rows, String title, String detail) {
    return [
      for (final row in rows)
        if (_text(row, title).isNotEmpty)
          ListedItem(title: _text(row, title), detail: _label(row[detail])),
    ];
  }

  String _text(Map<String, dynamic>? row, String key) {
    final value = row?[key];
    return value == null ? '' : value.toString().trim();
  }

  String _label(Object? value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) return '';
    return text[0].toUpperCase() + text.substring(1).replaceAll('_', ' ');
  }
}
