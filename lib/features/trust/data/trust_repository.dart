import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';
import '../../../core/errors/app_exception.dart';
import '../domain/trust_rules.dart';

abstract class TrustRepository {
  Future<VerificationRecord?> mine(String userId, String kind);
  Future<void> submit({required String userId, required String kind});
  Future<List<ReviewRecord>> reviewsFor(String subjectId);
  Future<void> addReview({
    required String userId,
    required String subjectId,
    required int rating,
    required String body,
    String? projectId,
  });
}

class SupabaseTrustRepository implements TrustRepository {
  SupabaseClient get _client {
    final client = SupabaseConfig.client;
    if (client == null) {
      throw const ConfigurationException('BAID X is not connected yet. Add the Supabase URL and publishable key to .env.');
    }
    return client;
  }

  @override
  Future<VerificationRecord?> mine(String userId, String kind) async {
    final row = await _client
        .from('verifications')
        .select('id, verification_kind, status, created_at')
        .eq('profile_id', userId)
        .eq('verification_kind', kind)
        .maybeSingle();
    if (row == null) return null;
    return VerificationRecord(
      id: '${row['id']}',
      kind: '${row['verification_kind']}',
      status: '${row['status']}',
      createdAt: DateTime.tryParse('${row['created_at']}') ?? DateTime.now().toUtc(),
    );
  }

  @override
  Future<void> submit({required String userId, required String kind}) {
    return _client.from('verifications').insert({
      'profile_id': userId,
      'verification_kind': kind,
      'status': 'pending',
    });
  }

  @override
  Future<List<ReviewRecord>> reviewsFor(String subjectId) async {
    final rows = await _client
        .from('reviews')
        .select('id, rating, body, created_at')
        .eq('subject_profile_id', subjectId)
        .order('created_at', ascending: false)
        .limit(10);
    return [
      for (final raw in rows as List)
        ReviewRecord(
          id: '${(raw as Map)['id']}',
          rating: (raw['rating'] as num).toInt(),
          body: '${raw['body']}',
          createdAt: DateTime.tryParse('${raw['created_at']}') ?? DateTime.now().toUtc(),
        ),
    ];
  }

  @override
  Future<void> addReview({
    required String userId,
    required String subjectId,
    required int rating,
    required String body,
    String? projectId,
  }) {
    final problem = validateReview(body: body, rating: '$rating');
    if (problem != null) throw AuthFlowException(problem);
    return _client.from('reviews').insert({
      'author_profile_id': userId,
      'subject_profile_id': subjectId,
      'project_id': projectId,
      'rating': rating,
      'body': body.trim(),
    });
  }
}
