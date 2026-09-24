import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../shared/providers/app_providers.dart';
import '../data/job_repository.dart';
import '../domain/job_rules.dart';

final jobRepositoryProvider = Provider<JobRepository>((ref) => SupabaseJobRepository());
final applicationRepositoryProvider = Provider<ApplicationRepository>((ref) => SupabaseApplicationRepository());

typedef JobQuery = ({String search, String location, int offset});

final openJobsProvider = FutureProvider.autoDispose.family<List<JobRecord>, JobQuery>((ref, query) {
  return ref.watch(jobRepositoryProvider).listOpen(search: query.search, location: query.location, offset: query.offset);
});

final jobDetailProvider = FutureProvider.autoDispose.family<JobRecord?, String>((ref, id) {
  return ref.watch(jobRepositoryProvider).getJob(id);
});

final myJobsProvider = FutureProvider.autoDispose<List<JobRecord>>((ref) async {
  final user = ref.watch(authStateProvider).asData?.value;
  if (user == null) throw const AuthFlowException('Sign in again to see your jobs.');
  return ref.watch(jobRepositoryProvider).listOwned(user.id);
});

final myApplicationsProvider = FutureProvider.autoDispose<List<ApplicationRecord>>((ref) async {
  final user = ref.watch(authStateProvider).asData?.value;
  if (user == null) throw const AuthFlowException('Sign in again to see your applications.');
  return ref.watch(applicationRepositoryProvider).listMine(user.id);
});

final jobApplicationsProvider = FutureProvider.autoDispose.family<List<ApplicationRecord>, String>((ref, jobId) {
  return ref.watch(applicationRepositoryProvider).listForJob(jobId);
});

final hasAppliedProvider = FutureProvider.autoDispose.family<bool, String>((ref, jobId) async {
  final user = ref.watch(authStateProvider).asData?.value;
  if (user == null) return false;
  return ref.watch(applicationRepositoryProvider).hasApplied(jobId: jobId, userId: user.id);
});
