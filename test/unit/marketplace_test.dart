import 'package:flutter_test/flutter_test.dart';

import 'package:baid_x_mobile/core/constants/app_routes.dart';
import 'package:baid_x_mobile/core/router/route_guards.dart';
import 'package:baid_x_mobile/features/marketplace/domain/listing_rules.dart';

void main() {
  test('a visitor can open a public listing', () {
    expect(
      guardRedirect(
        authLoading: false,
        gate: SessionGate.signedOut,
        profileLoading: false,
        accountType: null,
        path: '/listings/1',
      ),
      isNull,
    );
  });

  test('a visitor cannot create a listing', () {
    expect(
      guardRedirect(
        authLoading: false,
        gate: SessionGate.signedOut,
        profileLoading: false,
        accountType: null,
        path: AppRoutes.createListing,
      ),
      AppRoutes.signIn,
    );
  });

  test('only a business account can manage listings', () {
    expect(canManageListings('business'), isTrue);
    expect(canManageListings('worker'), isFalse);
    expect(canManageListings('employer'), isFalse);
    expect(canManageListings('company'), isFalse);
  });

  test('a new listing is owned by the signed-in business', () {
    final row = newListingRow(
      userId: 'business-1',
      title: ' Cement ',
      summary: 'Bags',
      kind: 'product',
      price: 80,
      currency: '',
      isPublic: true,
    );
    expect(row['business_profile_id'], 'business-1');
    expect(row['currency'], 'GHS');
    expect(listingUpdateRow(title: 'Cement', summary: '', kind: 'product', price: null, currency: 'GHS', isPublic: false).containsKey('business_profile_id'), isFalse);
  });

  test('listing validation rejects a blank title and a bad price', () {
    expect(validateListing(title: ' ', summary: '', kind: 'product', price: '', currency: 'GHS'), 'Add a listing title.');
    expect(validateListing(title: 'Mixer', summary: '', kind: 'rental', price: '-1', currency: 'GHS'), contains('price'));
    expect(validateListing(title: 'Mixer', summary: '', kind: 'equipment', price: '', currency: 'GHS'), isNull);
  });

  test('marketplace pages stay at 20 listings', () {
    expect(listingPageSize, 20);
  });
}
