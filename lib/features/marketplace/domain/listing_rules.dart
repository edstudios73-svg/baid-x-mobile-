const listingPageSize = 20;

const listingKinds = ['product', 'equipment', 'rental', 'service'];

String listingKindLabel(String kind) {
  return switch (kind) {
    'product' => 'Products',
    'equipment' => 'Equipment',
    'rental' => 'Rentals',
    'service' => 'Services',
    _ => kind,
  };
}

bool canManageListings(String? accountType) => accountType == 'business';

String? validateListing({
  required String title,
  required String summary,
  required String kind,
  required String price,
  required String currency,
}) {
  if (title.trim().isEmpty) return 'Add a listing title.';
  if (title.trim().length > 120) return 'Keep the title under 120 characters.';
  if (!listingKinds.contains(kind)) return 'Choose a listing type.';
  if (summary.trim().length > 4000) return 'Keep the description under 4000 characters.';
  if (price.trim().isNotEmpty) {
    final amount = double.tryParse(price.trim());
    if (amount == null || amount < 0) return 'Enter a price of zero or more, or leave it blank.';
  }
  if (currency.trim().length > 8) return 'Use a short currency code.';
  return null;
}

Map<String, dynamic> newListingRow({
  required String userId,
  required String title,
  required String summary,
  required String kind,
  required double? price,
  required String currency,
  required bool isPublic,
}) {
  return {
    'business_profile_id': userId,
    'title': title.trim(),
    'summary': summary.trim(),
    'listing_kind': kind,
    'price_amount': price,
    'currency': currency.trim().isEmpty ? 'GHS' : currency.trim(),
    'is_public': isPublic,
  };
}

Map<String, dynamic> listingUpdateRow({
  required String title,
  required String summary,
  required String kind,
  required double? price,
  required String currency,
  required bool isPublic,
}) {
  return {
    'title': title.trim(),
    'summary': summary.trim(),
    'listing_kind': kind,
    'price_amount': price,
    'currency': currency.trim().isEmpty ? 'GHS' : currency.trim(),
    'is_public': isPublic,
  };
}

class ListingRecord {
  const ListingRecord({
    required this.id,
    required this.businessId,
    required this.title,
    required this.kind,
    required this.summary,
    required this.currency,
    required this.isPublic,
    this.price,
    this.businessName = '',
    this.businessLocation = '',
    this.businessSummary = '',
    this.createdAt,
  });

  final String id;
  final String businessId;
  final String title;
  final String kind;
  final String summary;
  final double? price;
  final String currency;
  final bool isPublic;
  final String businessName;
  final String businessLocation;
  final String businessSummary;
  final DateTime? createdAt;
}
