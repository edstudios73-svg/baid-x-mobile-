import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';
import '../../../core/errors/app_exception.dart';
import '../domain/billing_rules.dart';

abstract class BillingRepository {
  Future<List<PlanOffer>> plansFor(String accountType);
  Future<BillingSnapshot> mine();
  Future<Map<String, dynamic>> startCheckout(Map<String, dynamic> args);
  Future<Map<String, dynamic>> beginPaystack(String reference);
  Future<void> startTrial();
  Future<void> requestCancellation();
  Future<void> scheduleDowngrade(String planId);
  Future<List<Map<String, dynamic>>> payments();
  Future<List<Map<String, dynamic>>> catalog(String table, String accountType);
  Future<List<Map<String, dynamic>>> myVerifications();
  Future<List<Map<String, dynamic>>> boostsFor(String targetId);
  Future<List<Map<String, dynamic>>> myListings();
  Future<Map<String, dynamic>?> activePromotion();
  Future<List<Map<String, dynamic>>> myXid();
  Future<Map<String, dynamic>> companyBilling();
  Future<bool> amReviewer();
  Future<List<Map<String, dynamic>>> pendingReviews();
  Future<void> decideVerification(String id, String decision);
}

class SupabaseBillingRepository implements BillingRepository {
  SupabaseClient get _client {
    final client = SupabaseConfig.client;
    if (client == null) {
      throw const ConfigurationException('BAID X is not connected yet. Add the Supabase URL and publishable key to .env.');
    }
    return client;
  }

  @override
  Future<List<PlanOffer>> plansFor(String accountType) async {
    final rows = await _client
        .from('plans')
        .select('id, tier, monthly_amount, annual_amount, founding_monthly_amount, founding_annual_amount, currency_code, entitlements, currencies(symbol)')
        .eq('account_type', accountType);
    return [for (final raw in rows as List) _plan(Map<String, dynamic>.from(raw as Map))];
  }

  @override
  Future<BillingSnapshot> mine() async {
    final row = await _client.rpc('my_billing');
    final map = Map<String, dynamic>.from(row as Map);
    final subscription = map['subscription'];
    return BillingSnapshot(
      accountType: '${map['account_type'] ?? ''}',
      subscription: subscription is Map ? Map<String, dynamic>.from(subscription) : null,
      entitlements: map['entitlements'] is Map ? Map<String, dynamic>.from(map['entitlements'] as Map) : const {},
      foundingEligible: map['founding_eligible'] == true,
      protectedPaymentsEnabled: map['protected_payments_enabled'] == true,
      refundDeadline: DateTime.tryParse('${map['refund_deadline'] ?? ''}'),
    );
  }

  @override
  Future<Map<String, dynamic>> startCheckout(Map<String, dynamic> args) async {
    final row = await _client.rpc('start_checkout', params: args);
    return Map<String, dynamic>.from(row as Map);
  }

  @override
  Future<Map<String, dynamic>> beginPaystack(String reference) async {
    final response = await _client.functions.invoke('paystack-initialize', body: {'reference': reference});
    final data = response.data;
    if (data is! Map) {
      throw const AuthFlowException('Paystack did not start the payment.');
    }
    return Map<String, dynamic>.from(data);
  }

  @override
  Future<void> startTrial() => _client.rpc('start_trial');

  @override
  Future<void> requestCancellation() => _client.rpc('request_cancellation');

  @override
  Future<void> scheduleDowngrade(String planId) {
    return _client.rpc('schedule_downgrade', params: {'p_plan_id': planId});
  }

  @override
  Future<List<Map<String, dynamic>>> payments() async {
    final rows = await _client
        .from('payments')
        .select('id, amount_minor, currency_code, status, purpose, invoice_reference, created_at')
        .order('created_at', ascending: false)
        .limit(20);
    return [for (final raw in rows as List) Map<String, dynamic>.from(raw as Map)];
  }

  @override
  Future<List<Map<String, dynamic>>> catalog(String table, String accountType) async {
    final rows = table == 'verification_products'
        ? await _client.from(table).select().eq('account_type', accountType)
        : await _client.from(table).select();
    return [for (final raw in rows as List) Map<String, dynamic>.from(raw as Map)];
  }

  @override
  Future<List<Map<String, dynamic>>> myVerifications() async {
    final rows = await _client.from('verifications').select('id, verification_kind, status, created_at, reviewed_at');
    return [for (final raw in rows as List) Map<String, dynamic>.from(raw as Map)];
  }

  @override
  Future<List<Map<String, dynamic>>> boostsFor(String targetId) async {
    final rows = await _client
        .from('boosts')
        .select('duration_key, starts_at, ends_at')
        .eq('target_id', targetId)
        .order('ends_at', ascending: false)
        .limit(5);
    return [for (final raw in rows as List) Map<String, dynamic>.from(raw as Map)];
  }

  @override
  Future<List<Map<String, dynamic>>> myListings() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const [];
    final rows = await _client
        .from('business_listings')
        .select('id, title')
        .eq('business_profile_id', userId)
        .order('created_at', ascending: false);
    return [for (final raw in rows as List) Map<String, dynamic>.from(raw as Map)];
  }

  @override
  Future<Map<String, dynamic>?> activePromotion() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    final rows = await _client
        .from('promotions')
        .select('package, listing_limit, starts_at, ends_at')
        .eq('business_profile_id', userId)
        .order('ends_at', ascending: false)
        .limit(1);
    if (rows.isEmpty) return null;
    return Map<String, dynamic>.from(rows.first as Map);
  }

  @override
  Future<List<Map<String, dynamic>>> myXid() async {
    final rows = await _client.from('xid_services').select('service, starts_at, ends_at').order('ends_at', ascending: false);
    return [for (final raw in rows as List) Map<String, dynamic>.from(raw as Map)];
  }

  @override
  Future<Map<String, dynamic>> companyBilling() async {
    final row = await _client.rpc('company_billing');
    return Map<String, dynamic>.from(row as Map);
  }

  @override
  Future<bool> amReviewer() async {
    final row = await _client.rpc('am_verification_reviewer');
    return row == true;
  }

  @override
  Future<List<Map<String, dynamic>>> pendingReviews() async {
    final rows = await _client.rpc('pending_verifications');
    return [for (final raw in rows as List) Map<String, dynamic>.from(raw as Map)];
  }

  @override
  Future<void> decideVerification(String id, String decision) {
    return _client.rpc('decide_verification', params: {'p_id': id, 'p_decision': decision});
  }
}

PlanOffer _plan(Map<String, dynamic> row) {
  final currency = row['currencies'];
  final symbol = currency is Map ? '${currency['symbol'] ?? ''}' : '';
  return PlanOffer(
    id: '${row['id']}',
    tier: '${row['tier']}',
    monthlyAmount: row['monthly_amount'] as int?,
    annualAmount: row['annual_amount'] as int?,
    foundingMonthlyAmount: row['founding_monthly_amount'] as int?,
    foundingAnnualAmount: row['founding_annual_amount'] as int?,
    currencyCode: '${row['currency_code'] ?? ''}',
    symbol: symbol,
    entitlements: row['entitlements'] is Map ? Map<String, dynamic>.from(row['entitlements'] as Map) : const {},
  );
}
