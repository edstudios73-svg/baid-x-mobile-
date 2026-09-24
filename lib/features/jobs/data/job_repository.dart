import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';
import '../../../core/errors/app_exception.dart';
import '../domain/job_rules.dart';

const jobPageSize = 20;

abstract class JobRepository {
  Future<List<JobRecord>> listOpen({String search = '', String location = '', int offset = 0});
  Future<JobRecord?> getJob(String id);
  Future<List<JobRecord>> listOwned(String userId);
  Future<String> createJob({
    required String userId,
    required String title,
    required String description,
    required String location,
  });
}

abstract class ApplicationRepository {
  Future<List<ApplicationRecord>> listMine(String userId);
  Future<List<ApplicationRecord>> listForJob(String jobId);
  Future<bool> hasApplied({required String jobId, required String userId});
  Future<void> submit({required String jobId, required String userId, required String message});
}

class SupabaseJobRepository implements JobRepository {
  SupabaseClient get _client => _required();

  @override
  Future<List<JobRecord>> listOpen({String search = '', String location = '', int offset = 0}) async {
    var query = _client
        .from('jobs')
        .select('id, title, description, location_label, status, is_public, owner_profile_id, created_at')
        .eq('is_public', true)
        .eq('status', 'open');
    final title = _like(search);
    final place = _like(location);
    if (title != null) query = query.ilike('title', title);
    if (place != null) query = query.ilike('location_label', place);
    final rows = await query.order('created_at', ascending: false).range(offset, offset + jobPageSize - 1);
    return [for (final row in rows as List) _job(Map<String, dynamic>.from(row as Map))];
  }

  @override
  Future<JobRecord?> getJob(String id) async {
    final row = await _client
        .from('jobs')
        .select('id, title, description, location_label, status, is_public, owner_profile_id, created_at')
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    return _job(Map<String, dynamic>.from(row));
  }

  @override
  Future<List<JobRecord>> listOwned(String userId) async {
    final rows = await _client
        .from('jobs')
        .select('id, title, description, location_label, status, is_public, owner_profile_id, created_at')
        .eq('owner_profile_id', userId)
        .order('created_at', ascending: false)
        .limit(jobPageSize);
    final jobs = [for (final row in rows as List) _job(Map<String, dynamic>.from(row as Map))];
    if (jobs.isEmpty) return jobs;
    final apps = await _client.from('job_applications').select('job_id').inFilter('job_id', jobs.map((job) => job.id).toList());
    final counts = <String, int>{};
    for (final row in apps as List) {
      final id = Map<String, dynamic>.from(row as Map)['job_id'] as String;
      counts[id] = (counts[id] ?? 0) + 1;
    }
    return [
      for (final job in jobs)
        JobRecord(
          id: job.id,
          title: job.title,
          description: job.description,
          locationLabel: job.locationLabel,
          status: job.status,
          isPublic: job.isPublic,
          ownerId: job.ownerId,
          createdAt: job.createdAt,
          applicationCount: counts[job.id] ?? 0,
        ),
    ];
  }

  @override
  Future<String> createJob({
    required String userId,
    required String title,
    required String description,
    required String location,
  }) async {
    final row = await _client.from('jobs').insert({
      'owner_profile_id': userId,
      'title': title.trim(),
      'description': description.trim(),
      'location_label': location.trim(),
      'status': 'open',
      'is_public': true,
    }).select('id').single();
    return row['id'] as String;
  }
}

class SupabaseApplicationRepository implements ApplicationRepository {
  SupabaseClient get _client => _required();

  @override
  Future<List<ApplicationRecord>> listMine(String userId) async {
    final rows = await _client
        .from('job_applications')
        .select('id, job_id, worker_profile_id, status, message, created_at, jobs(title, owner_profile_id)')
        .eq('worker_profile_id', userId)
        .order('created_at', ascending: false)
        .limit(jobPageSize);
    return [for (final row in rows as List) _application(Map<String, dynamic>.from(row as Map))];
  }

  @override
  Future<List<ApplicationRecord>> listForJob(String jobId) async {
    final rows = await _client
        .from('job_applications')
        .select('id, job_id, worker_profile_id, status, message, created_at')
        .eq('job_id', jobId)
        .order('created_at', ascending: false)
        .limit(jobPageSize);
    return [for (final row in rows as List) _application(Map<String, dynamic>.from(row as Map))];
  }

  @override
  Future<bool> hasApplied({required String jobId, required String userId}) async {
    final rows = await _client.from('job_applications').select('id').eq('job_id', jobId).eq('worker_profile_id', userId).limit(1);
    return (rows as List).isNotEmpty;
  }

  @override
  Future<void> submit({required String jobId, required String userId, required String message}) {
    return _client.from('job_applications').insert({
      'job_id': jobId,
      'worker_profile_id': userId,
      'status': 'submitted',
      'message': message.trim(),
    });
  }
}

SupabaseClient _required() {
  final client = SupabaseConfig.client;
  if (client == null) {
    throw const ConfigurationException('BAID X is not connected yet. Add the Supabase URL and publishable key to .env.');
  }
  return client;
}

String? _like(String value) {
  final cleaned = value.replaceAll('%', '').replaceAll('_', '').trim();
  if (cleaned.isEmpty) return null;
  return '%$cleaned%';
}

JobRecord _job(Map<String, dynamic> row) {
  return JobRecord(
    id: row['id'] as String,
    title: (row['title'] as String?) ?? '',
    description: (row['description'] as String?) ?? '',
    locationLabel: (row['location_label'] as String?) ?? '',
    status: (row['status'] as String?) ?? '',
    isPublic: row['is_public'] == true,
    ownerId: (row['owner_profile_id'] as String?) ?? '',
    createdAt: DateTime.tryParse('${row['created_at'] ?? ''}'),
  );
}

ApplicationRecord _application(Map<String, dynamic> row) {
  final job = row['jobs'];
  final title = job is Map ? '${job['title'] ?? ''}' : '';
  final owner = job is Map ? '${job['owner_profile_id'] ?? ''}' : '';
  return ApplicationRecord(
    id: row['id'] as String,
    jobId: row['job_id'] as String,
    status: (row['status'] as String?) ?? '',
    message: (row['message'] as String?) ?? '',
    workerProfileId: '${row['worker_profile_id'] ?? ''}',
    ownerProfileId: owner,
    jobTitle: title,
    createdAt: DateTime.tryParse('${row['created_at'] ?? ''}'),
  );
}
