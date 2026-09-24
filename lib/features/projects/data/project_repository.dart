import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';
import '../../../core/errors/app_exception.dart';
import '../domain/project_rules.dart';

abstract class ProjectRepository {
  Future<CompanyRecord?> myCompany(String userId);
  Future<List<Map<String, dynamic>>> members(String companyId);
  Future<List<AccessRequestRecord>> requestsFor(String companyId);
  Future<List<AccessRequestRecord>> myRequests(String userId);
  Future<void> requestAccess({required String userId, required String publicCode});
  Future<void> reviewRequest({required String requestId, required bool approve});
  Future<List<ProjectRecord>> projectsFor({required String userId, String? companyId});
  Future<ProjectRecord?> project(String id);
  Future<String> createProject(Map<String, dynamic> row);
  Future<void> addMember(Map<String, dynamic> row);
  Future<List<Map<String, dynamic>>> projectMembers(String projectId);
  Future<List<Map<String, dynamic>>> tasks(String projectId);
  Future<void> addTask({required String projectId, required String title});
  Future<void> setTaskDone({required String taskId, required bool done});
  Future<List<Map<String, dynamic>>> reports(String projectId);
  Future<void> addReport({required String projectId, required String userId, required String body});
  Future<List<Map<String, dynamic>>> expenses(String projectId);
  Future<void> addExpense({
    required String projectId,
    required String userId,
    required String description,
    required double amount,
    required String currency,
  });
}

class SupabaseProjectRepository implements ProjectRepository {
  SupabaseClient get _client {
    final client = SupabaseConfig.client;
    if (client == null) {
      throw const ConfigurationException('BAID X is not connected yet. Add the Supabase URL and publishable key to .env.');
    }
    return client;
  }

  @override
  Future<CompanyRecord?> myCompany(String userId) async {
    final owned = await _client.from('companies').select('id, name, industry, public_code').eq('owner_profile_id', userId).limit(1);
    if ((owned as List).isNotEmpty) return _company(Map<String, dynamic>.from(owned.first as Map));
    final memberships = await _client.from('company_members').select('company_id').eq('profile_id', userId).eq('status', 'active').limit(1);
    if ((memberships as List).isEmpty) return null;
    final companyId = Map<String, dynamic>.from(memberships.first as Map)['company_id'] as String;
    final company = await _client.from('companies').select('id, name, industry, public_code').eq('id', companyId).maybeSingle();
    if (company == null) return null;
    return _company(Map<String, dynamic>.from(company));
  }

  @override
  Future<List<Map<String, dynamic>>> members(String companyId) async {
    final rows = await _client.from('company_members').select('profile_id, member_role, status').eq('company_id', companyId).limit(20);
    return [for (final row in rows as List) Map<String, dynamic>.from(row as Map)];
  }

  @override
  Future<List<AccessRequestRecord>> requestsFor(String companyId) async {
    final rows = await _client.from('company_access_requests').select('id, company_id, status').eq('company_id', companyId).limit(20);
    return [for (final row in rows as List) _request(Map<String, dynamic>.from(row as Map))];
  }

  @override
  Future<List<AccessRequestRecord>> myRequests(String userId) async {
    final rows = await _client.from('company_access_requests').select('id, company_id, status').eq('requester_profile_id', userId).limit(20);
    return [for (final row in rows as List) _request(Map<String, dynamic>.from(row as Map))];
  }

  @override
  Future<void> requestAccess({required String userId, required String publicCode}) async {
    final code = publicCode.trim().toUpperCase();
    if (code.isEmpty) throw const AuthFlowException('Enter the company code.');
    final company = await _client.from('companies').select('id').eq('public_code', code).maybeSingle();
    if (company == null) throw const AuthFlowException('No company was found with that code.');
    try {
      await _client.from('company_access_requests').insert({
        'company_id': company['id'],
        'requester_profile_id': userId,
        'status': 'pending',
      });
    } catch (error) {
      final text = error.toString().toLowerCase();
      if (text.contains('duplicate') || text.contains('23505')) {
        throw const AuthFlowException('You already sent a request to this company.');
      }
      rethrow;
    }
  }

  @override
  Future<void> reviewRequest({required String requestId, required bool approve}) {
    return _client.rpc('review_company_access', params: {'request_id': requestId, 'approve': approve});
  }

  @override
  Future<List<ProjectRecord>> projectsFor({required String userId, String? companyId}) async {
    final owned = await _client.from('projects').select('id, title, summary, status, owner_profile_id, company_id, public_code').eq('owner_profile_id', userId).limit(20);
    final memberRows = await _client.from('project_members').select('project_id').eq('profile_id', userId).limit(20);
    final memberIds = [for (final row in memberRows as List) '${Map<String, dynamic>.from(row as Map)['project_id']}'];
    final memberProjects = memberIds.isEmpty
        ? <dynamic>[]
        : await _client.from('projects').select('id, title, summary, status, owner_profile_id, company_id, public_code').inFilter('id', memberIds);
    final companyProjects = companyId == null
        ? <dynamic>[]
        : await _client.from('projects').select('id, title, summary, status, owner_profile_id, company_id, public_code').eq('company_id', companyId).limit(20);
    final seen = <String>{};
    final projects = <ProjectRecord>[];
    for (final raw in [...owned as List, ...memberProjects, ...companyProjects]) {
      final project = _project(Map<String, dynamic>.from(raw as Map));
      if (seen.add(project.id)) projects.add(project);
    }
    return projects;
  }

  @override
  Future<ProjectRecord?> project(String id) async {
    final row = await _client.from('projects').select('id, title, summary, status, owner_profile_id, company_id, public_code').eq('id', id).maybeSingle();
    if (row == null) return null;
    return _project(Map<String, dynamic>.from(row));
  }

  @override
  Future<String> createProject(Map<String, dynamic> row) async {
    final inserted = await _client.from('projects').insert(row).select('id').single();
    return inserted['id'] as String;
  }

  @override
  Future<void> addMember(Map<String, dynamic> row) => _client.from('project_members').insert(row);

  @override
  Future<List<Map<String, dynamic>>> projectMembers(String projectId) async {
    final rows = await _client.from('project_members').select('profile_id, member_role').eq('project_id', projectId).limit(20);
    final members = [for (final row in rows as List) Map<String, dynamic>.from(row as Map)];
    final ids = [for (final member in members) '${member['profile_id']}'];
    if (ids.isEmpty) return members;
    final listed = await _client.from('profiles').select('id, display_name').inFilter('id', ids);
    final names = <String, String>{};
    for (final row in listed as List) {
      final map = Map<String, dynamic>.from(row as Map);
      names['${map['id']}'] = '${map['display_name'] ?? ''}';
    }
    return [
      for (final member in members)
        {
          ...member,
          if ((names['${member['profile_id']}'] ?? '').isNotEmpty) 'display_name': names['${member['profile_id']}'],
        },
    ];
  }

  @override
  Future<List<Map<String, dynamic>>> tasks(String projectId) async {
    final rows = await _client.from('project_tasks').select('id, title, is_done').eq('project_id', projectId).limit(20);
    return [for (final row in rows as List) Map<String, dynamic>.from(row as Map)];
  }

  @override
  Future<void> addTask({required String projectId, required String title}) {
    return _client.from('project_tasks').insert({'project_id': projectId, 'title': title.trim(), 'is_done': false});
  }

  @override
  Future<void> setTaskDone({required String taskId, required bool done}) {
    return _client.from('project_tasks').update({'is_done': done}).eq('id', taskId);
  }

  @override
  Future<List<Map<String, dynamic>>> reports(String projectId) async {
    final rows = await _client.from('project_reports').select('id, body, created_at').eq('project_id', projectId).limit(20);
    return [for (final row in rows as List) Map<String, dynamic>.from(row as Map)];
  }

  @override
  Future<void> addReport({required String projectId, required String userId, required String body}) {
    return _client.from('project_reports').insert({'project_id': projectId, 'author_profile_id': userId, 'body': body.trim()});
  }

  @override
  Future<List<Map<String, dynamic>>> expenses(String projectId) async {
    final rows = await _client.from('project_expenses').select('id, description, amount, currency').eq('project_id', projectId).limit(20);
    return [for (final row in rows as List) Map<String, dynamic>.from(row as Map)];
  }

  @override
  Future<void> addExpense({
    required String projectId,
    required String userId,
    required String description,
    required double amount,
    required String currency,
  }) {
    return _client.from('project_expenses').insert({
      'project_id': projectId,
      'submitted_by': userId,
      'description': description.trim(),
      'amount': amount,
      'currency': currency.trim().isEmpty ? 'GHS' : currency.trim(),
    });
  }
}

CompanyRecord _company(Map<String, dynamic> row) => CompanyRecord(
  id: row['id'] as String,
  name: '${row['name'] ?? ''}',
  industry: '${row['industry'] ?? ''}',
  publicCode: '${row['public_code'] ?? ''}',
);

AccessRequestRecord _request(Map<String, dynamic> row) => AccessRequestRecord(
  id: row['id'] as String,
  companyId: row['company_id'] as String,
  status: '${row['status'] ?? ''}',
);

ProjectRecord _project(Map<String, dynamic> row) => ProjectRecord(
  id: row['id'] as String,
  title: '${row['title'] ?? ''}',
  summary: '${row['summary'] ?? ''}',
  status: '${row['status'] ?? ''}',
  ownerId: '${row['owner_profile_id'] ?? ''}',
  companyId: row['company_id'] as String?,
  publicCode: '${row['public_code'] ?? ''}',
);
