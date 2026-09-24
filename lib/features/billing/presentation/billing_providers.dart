import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/providers/app_providers.dart';
import '../data/billing_repository.dart';
import '../domain/billing_rules.dart';

final billingRepositoryProvider = Provider<BillingRepository>((ref) => SupabaseBillingRepository());

final billingSnapshotProvider = FutureProvider.autoDispose<BillingSnapshot>((ref) async {
  final user = ref.watch(authStateProvider).asData?.value;
  if (user == null) throw StateError('Not signed in');
  return ref.watch(billingRepositoryProvider).mine();
});

final rolePlansProvider = FutureProvider.autoDispose<List<PlanOffer>>((ref) async {
  final type = ref.watch(accountProfileProvider).asData?.value?.accountType;
  if (type == null) return const [];
  return ref.watch(billingRepositoryProvider).plansFor(type);
});

final paymentHistoryProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final user = ref.watch(authStateProvider).asData?.value;
  if (user == null) return const [];
  return ref.watch(billingRepositoryProvider).payments();
});

final verificationProductsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final type = ref.watch(accountProfileProvider).asData?.value?.accountType;
  if (type == null) return const [];
  return ref.watch(billingRepositoryProvider).catalog('verification_products', type);
});

final myVerificationsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final user = ref.watch(authStateProvider).asData?.value;
  if (user == null) return const [];
  return ref.watch(billingRepositoryProvider).myVerifications();
});

final reviewerFlagProvider = FutureProvider.autoDispose<bool>((ref) async {
  final user = ref.watch(authStateProvider).asData?.value;
  if (user == null) return false;
  return ref.watch(billingRepositoryProvider).amReviewer();
});
