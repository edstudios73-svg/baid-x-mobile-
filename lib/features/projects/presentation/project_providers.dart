import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../shared/providers/app_providers.dart';
import '../data/project_repository.dart';
import '../domain/project_rules.dart';

final projectRepositoryProvider = Provider<ProjectRepository>((ref) => SupabaseProjectRepository());

final myCompanyProvider = FutureProvider.autoDispose<CompanyRecord?>((ref) async {
  final user = ref.watch(authStateProvider).asData?.value;
  if (user == null) throw const AuthFlowException('Sign in again to see your company.');
  return ref.watch(projectRepositoryProvider).myCompany(user.id);
});

final projectListProvider = FutureProvider.autoDispose<List<ProjectRecord>>((ref) async {
  final user = ref.watch(authStateProvider).asData?.value;
  if (user == null) throw const AuthFlowException("We couldn't load your projects.");
  final company = await ref.watch(myCompanyProvider.future);
  return ref.watch(projectRepositoryProvider).projectsFor(userId: user.id, companyId: company?.id);
});

final projectDetailProvider = FutureProvider.autoDispose.family<ProjectRecord?, String>((ref, id) {
  return ref.watch(projectRepositoryProvider).project(id);
});

final accessRequestsProvider = FutureProvider.autoDispose<List<AccessRequestRecord>>((ref) async {
  final user = ref.watch(authStateProvider).asData?.value;
  final type = ref.watch(accountProfileProvider).asData?.value?.accountType;
  if (user == null) return const [];
  final repo = ref.watch(projectRepositoryProvider);
  if (canReviewCompanyAccess(type)) {
    final company = await ref.watch(myCompanyProvider.future);
    if (company == null) return const [];
    return repo.requestsFor(company.id);
  }
  return repo.myRequests(user.id);
});
