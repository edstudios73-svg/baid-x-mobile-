import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';
import '../../../core/errors/app_exception.dart';
import '../domain/listing_rules.dart';

abstract class MarketplaceRepository {
  Future<List<ListingRecord>> listPublic({
    String search = '',
    String? kind,
    String location = '',
    double? maxPrice,
    int offset = 0,
  });
  Future<ListingRecord?> getListing(String id);
  Future<List<ListingRecord>> listMine(String userId);
  Future<String> createListing(Map<String, dynamic> row);
  Future<void> updateListing(String id, Map<String, dynamic> row);
  Future<void> deleteListing(String id);
  Future<Map<String, dynamic>?> publicBusiness(String id);
}

class SupabaseMarketplaceRepository implements MarketplaceRepository {
  SupabaseClient get _client {
    final client = SupabaseConfig.client;
    if (client == null) {
      throw const ConfigurationException('BAID X is not connected yet. Add the Supabase URL and publishable key to .env.');
    }
    return client;
  }

  static const _columns =
      'id, business_profile_id, title, listing_kind, summary, price_amount, currency, is_public, created_at, business_profiles(business_name, summary, location_label)';

  @override
  Future<List<ListingRecord>> listPublic({
    String search = '',
    String? kind,
    String location = '',
    double? maxPrice,
    int offset = 0,
  }) async {
    var query = _client.from('business_listings').select(_columns).eq('is_public', true);
    final title = _like(search);
    final place = _like(location);
    if (title != null) query = query.ilike('title', title);
    if (kind != null && listingKinds.contains(kind)) query = query.eq('listing_kind', kind);
    if (place != null) query = query.ilike('business_profiles.location_label', place);
    if (maxPrice != null) query = query.lte('price_amount', maxPrice);
    final rows = await query.order('created_at', ascending: false).range(offset, offset + listingPageSize - 1);
    return [for (final row in rows as List) _listing(Map<String, dynamic>.from(row as Map))];
  }

  @override
  Future<ListingRecord?> getListing(String id) async {
    final row = await _client.from('business_listings').select(_columns).eq('id', id).maybeSingle();
    if (row == null) return null;
    return _listing(Map<String, dynamic>.from(row));
  }

  @override
  Future<List<ListingRecord>> listMine(String userId) async {
    final rows = await _client
        .from('business_listings')
        .select(_columns)
        .eq('business_profile_id', userId)
        .order('created_at', ascending: false)
        .limit(listingPageSize);
    return [for (final row in rows as List) _listing(Map<String, dynamic>.from(row as Map))];
  }

  @override
  Future<String> createListing(Map<String, dynamic> row) async {
    final inserted = await _client.from('business_listings').insert(row).select('id').single();
    return inserted['id'] as String;
  }

  @override
  Future<void> updateListing(String id, Map<String, dynamic> row) {
    return _client.from('business_listings').update(row).eq('id', id);
  }

  @override
  Future<void> deleteListing(String id) {
    return _client.from('business_listings').delete().eq('id', id);
  }

  @override
  Future<Map<String, dynamic>?> publicBusiness(String id) async {
    final profile = await _client
        .from('business_profiles')
        .select('profile_id, business_name, category, summary, location_label')
        .eq('profile_id', id)
        .maybeSingle();
    if (profile == null) return null;
    final verified = await _client.from('verifications').select('id').eq('profile_id', id).eq('status', 'verified').limit(1);
    return {
      'profile': Map<String, dynamic>.from(profile),
      'verified': (verified as List).isNotEmpty,
    };
  }
}

String? _like(String value) {
  final cleaned = value.replaceAll('%', '').replaceAll('_', '').trim();
  if (cleaned.isEmpty) return null;
  return '%$cleaned%';
}

ListingRecord _listing(Map<String, dynamic> row) {
  final business = row['business_profiles'];
  final map = business is Map ? Map<String, dynamic>.from(business) : <String, dynamic>{};
  final price = row['price_amount'];
  return ListingRecord(
    id: row['id'] as String,
    businessId: row['business_profile_id'] as String,
    title: '${row['title'] ?? ''}',
    kind: '${row['listing_kind'] ?? ''}',
    summary: '${row['summary'] ?? ''}',
    price: price == null ? null : double.tryParse('$price'),
    currency: '${row['currency'] ?? ''}',
    isPublic: row['is_public'] == true,
    businessName: '${map['business_name'] ?? ''}',
    businessLocation: '${map['location_label'] ?? ''}',
    businessSummary: '${map['summary'] ?? ''}',
    createdAt: DateTime.tryParse('${row['created_at'] ?? ''}'),
  );
}
