import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../shared/providers/app_providers.dart';
import '../data/marketplace_repository.dart';
import '../domain/listing_rules.dart';

final marketplaceRepositoryProvider = Provider<MarketplaceRepository>((ref) => SupabaseMarketplaceRepository());

typedef ListingQuery = ({String search, String? kind, String location, double? maxPrice, int offset});

final publicListingsProvider = FutureProvider.autoDispose.family<List<ListingRecord>, ListingQuery>((ref, query) {
  return ref.watch(marketplaceRepositoryProvider).listPublic(
    search: query.search,
    kind: query.kind,
    location: query.location,
    maxPrice: query.maxPrice,
    offset: query.offset,
  );
});

final listingDetailProvider = FutureProvider.autoDispose.family<ListingRecord?, String>((ref, id) {
  return ref.watch(marketplaceRepositoryProvider).getListing(id);
});

final myListingsProvider = FutureProvider.autoDispose<List<ListingRecord>>((ref) async {
  final user = ref.watch(authStateProvider).asData?.value;
  if (user == null) throw const AuthFlowException('Sign in again to see your listings.');
  return ref.watch(marketplaceRepositoryProvider).listMine(user.id);
});

final businessProfileProvider = FutureProvider.autoDispose.family<Map<String, dynamic>?, String>((ref, id) {
  return ref.watch(marketplaceRepositoryProvider).publicBusiness(id);
});
