import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../shared/providers/app_providers.dart';
import '../data/dashboard_repository.dart';
import '../domain/role_dashboard.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>(
  (ref) => SupabaseDashboardRepository(),
);

final workerDashboardProvider = FutureProvider<RoleDashboard>((ref) {
  return _load(ref, (repo, id) => repo.loadWorker(id));
});

final employerDashboardProvider = FutureProvider<RoleDashboard>((ref) {
  return _load(ref, (repo, id) => repo.loadEmployer(id));
});

final businessDashboardProvider = FutureProvider<RoleDashboard>((ref) {
  return _load(ref, (repo, id) => repo.loadBusiness(id));
});

final projectManagerDashboardProvider = FutureProvider<RoleDashboard>((ref) {
  return _load(ref, (repo, id) => repo.loadProjectManager(id));
});

final companyDashboardProvider = FutureProvider<RoleDashboard>((ref) {
  return _load(ref, (repo, id) => repo.loadCompany(id));
});

Future<RoleDashboard> _load(
  Ref ref,
  Future<RoleDashboard> Function(DashboardRepository repo, String userId) read,
) async {
  final user = ref.watch(authStateProvider).asData?.value;
  if (user == null || !user.emailConfirmed) {
    throw const AuthFlowException('Sign in again to load your dashboard.');
  }
  return read(ref.watch(dashboardRepositoryProvider), user.id);
}
