import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';
import '../../../core/errors/app_exception.dart';
import '../../jobs/data/job_repository.dart';
import '../../jobs/domain/job_rules.dart';

abstract class WorkerRepository {
  Future<List<WorkerCard>> search({String query = '', String location = '', int offset = 0});
  Future<Map<String, dynamic>?> publicProfile(String id);
  Future<void> saveProfile({
    required String userId,
    required String name,
    required String location,
    required String headline,
    required String trade,
    required String availability,
    required String summary,
    required int? years,
    required bool listed,
    required List<String> skills,
  });
}

class SupabaseWorkerRepository implements WorkerRepository {
  SupabaseClient get _client {
    final client = SupabaseConfig.client;
    if (client == null) {
      throw const ConfigurationException('BAID X is not connected yet. Add the Supabase URL and publishable key to .env.');
    }
    return client;
  }

  @override
  Future<List<WorkerCard>> search({String query = '', String location = '', int offset = 0}) async {
    var filter = _client
        .from('worker_profiles')
        .select('profile_id, trade, summary, profiles!inner(display_name, location_label, is_listed)')
        .eq('profiles.is_listed', true);
    final place = _like(location);
    final term = _like(query);
    if (place != null) filter = filter.ilike('profiles.location_label', place);
    if (term != null) {
      filter = filter.or('trade.ilike.$term,summary.ilike.$term,profiles.display_name.ilike.$term');
    }
    final rows = [
      for (final raw in await filter.range(offset, offset + jobPageSize - 1) as List)
        Map<String, dynamic>.from(raw as Map),
    ];
    final ids = [for (final row in rows) '${row['profile_id']}'];
    final verifiedIds = <String>{};
    if (ids.isNotEmpty) {
      final marks = await _client.from('verifications').select('profile_id').inFilter('profile_id', ids).eq('status', 'verified');
      for (final raw in marks as List) {
        verifiedIds.add('${Map<String, dynamic>.from(raw as Map)['profile_id']}');
      }
    }
    return [for (final row in rows) _card(row, verifiedIds.contains('${row['profile_id']}'))];
  }

  @override
  Future<Map<String, dynamic>?> publicProfile(String id) async {
    final profile = await _client.from('profiles').select('id, display_name, headline, location_label').eq('id', id).maybeSingle();
    if (profile == null) return null;
    final worker = await _client.from('worker_profiles').select('trade, availability, summary, years_experience').eq('profile_id', id).maybeSingle();
    final skills = await _client.from('worker_skills').select('skill_name').eq('profile_id', id).limit(20);
    final experience = await _client.from('worker_experience').select('title, organization, summary').eq('profile_id', id).limit(10);
    final verified = await _client.from('verifications').select('id').eq('profile_id', id).eq('status', 'verified').limit(1);
    return {
      'profile': Map<String, dynamic>.from(profile),
      'worker': worker == null ? null : Map<String, dynamic>.from(worker),
      'skills': [for (final row in skills as List) '${Map<String, dynamic>.from(row as Map)['skill_name']}'],
      'experience': [for (final row in experience as List) Map<String, dynamic>.from(row as Map)],
      'verified': (verified as List).isNotEmpty,
    };
  }

  @override
  Future<void> saveProfile({
    required String userId,
    required String name,
    required String location,
    required String headline,
    required String trade,
    required String availability,
    required String summary,
    required int? years,
    required bool listed,
    required List<String> skills,
  }) async {
    await _client.from('profiles').update({
      'display_name': name.trim(),
      'location_label': location.trim(),
      'headline': headline.trim(),
      'is_listed': listed,
    }).eq('id', userId);
    await _client.from('worker_profiles').upsert({
      'profile_id': userId,
      'trade': trade.trim(),
      'availability': availability.trim(),
      'summary': summary.trim(),
      'years_experience': ?years,
    });
    for (final skill in skills) {
      final trimmed = skill.trim();
      if (trimmed.isEmpty || trimmed.length > 80) continue;
      await _client.from('worker_skills').upsert({
        'profile_id': userId,
        'skill_name': trimmed,
      }, onConflict: 'profile_id,skill_name');
    }
  }
}

WorkerCard _card(Map<String, dynamic> row, bool verified) {
  final profile = row['profiles'];
  final map = profile is Map ? Map<String, dynamic>.from(profile) : <String, dynamic>{};
  return WorkerCard(
    id: row['profile_id'] as String,
    name: '${map['display_name'] ?? ''}',
    trade: '${row['trade'] ?? ''}',
    location: '${map['location_label'] ?? ''}',
    summary: '${row['summary'] ?? ''}',
    verified: verified,
  );
}

String? _like(String value) {
  final cleaned = value.replaceAll('%', '').replaceAll('_', '').trim();
  if (cleaned.isEmpty) return null;
  return '%$cleaned%';
}
