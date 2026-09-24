import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/providers/app_providers.dart';
import '../data/trust_repository.dart';
import '../domain/trust_rules.dart';

final trustRepositoryProvider = Provider<TrustRepository>((ref) => SupabaseTrustRepository());

final myVerificationProvider = FutureProvider.autoDispose<VerificationRecord?>((ref) async {
  final user = ref.watch(authStateProvider).asData?.value;
  final type = ref.watch(accountProfileProvider).asData?.value?.accountType;
  final kind = verificationKindFor(type);
  if (user == null || kind == null) return null;
  return ref.watch(trustRepositoryProvider).mine(user.id, kind);
});

final subjectReviewsProvider = FutureProvider.autoDispose.family<List<ReviewRecord>, String>((ref, subjectId) {
  return ref.watch(trustRepositoryProvider).reviewsFor(subjectId);
});
