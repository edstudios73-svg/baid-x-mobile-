import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/services/web_api.dart';
import '../../../shared/providers/app_providers.dart';
import '../../tabs/data/tabs_data.dart';

/// Data behind the Profile menu pages, read and written exactly like the
/// website (js/wallet.js, js/billing.js, js/orgs.js, js/orders.js,
/// js/market.js, js/features.js). Every money action is a database function
/// or a website server route; the app never decides a payment itself.

SupabaseClient get sb {
  final c = SupabaseConfig.client;
  if (c == null) throw const ConfigurationException('BAID X is not connected yet.');
  return c;
}

String get myId {
  final u = sb.auth.currentUser;
  if (u == null) throw const AuthFlowException('Your session expired. Sign in again.');
  return u.id;
}

/// Calls a database function and turns its error into the plain sentence the
/// function raised (the website shows the same text).
Future<dynamic> rpcCall(String fn, [Map<String, dynamic>? params]) async {
  try {
    return await sb.rpc(fn, params: params);
  } on PostgrestException catch (e) {
    final m = e.message.trim();
    throw AuthFlowException(m.isEmpty ? 'Something went wrong. Try again.' : m[0].toUpperCase() + m.substring(1));
  }
}

List<Json> asList(Object? v) => [for (final e in (v is List ? v : const [])) if (e is Map) Map<String, dynamic>.from(e)];
Json asMap(Object? v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

void _follow(Ref ref) => ref.watch(authStateProvider.select((a) => a.asData?.value?.id));

// ---------- Wallet ----------
class WalletData {
  const WalletData({required this.caps, required this.account, required this.tx, required this.withdrawals, required this.waiting});
  final Json? caps;
  final Json account;
  final List<Json> tx, withdrawals;
  final bool waiting; // a Paystack deposit is still being confirmed
}

final walletProvider = FutureProvider<WalletData>((ref) async {
  _follow(ref);
  final caps = await sb.rpc('wallet_caps').then(asMap, onError: (_) => <String, dynamic>{});
  if (caps.isEmpty) return const WalletData(caps: null, account: {}, tx: [], withdrawals: [], waiting: false);
  final uid = myId;
  final r = await Future.wait(<Future<dynamic>>[
    sb.from('wallet_accounts').select('available_ghs,pending_ghs,lifetime_earned_ghs,lifetime_spent_ghs').eq('owner_id', uid).maybeSingle(),
    sb.from('wallet_transactions').select('id,type,amount_ghs,net_ghs,status,description,created_at').eq('owner_id', uid).order('created_at', ascending: false).limit(30),
    caps['can_withdraw'] == true ? sb.from('withdrawal_requests').select('id,public_id,amount_ghs,status,admin_note,destination_network,destination_account,created_at,processed_at').eq('owner_id', uid).order('created_at', ascending: false).limit(10) : Future.value(<Json>[]),
    caps['can_deposit'] == true ? sb.rpc('my_payments').then((v) => v, onError: (_) => <Json>[]) : Future.value(<Json>[]),
  ]);
  final pays = asList(r[3]);
  final waiting = pays.any((p) => p['purpose'] == 'wallet_deposit' && ['pending', 'processing'].contains(p['status']) && DateTime.now().difference(DateTime.tryParse('${p['created_at']}') ?? DateTime(2000)).inMinutes < 60);
  return WalletData(caps: caps, account: asMap(r[0]), tx: asList(r[1]), withdrawals: asList(r[2]), waiting: waiting);
});

/// Starts a Paystack checkout for a reference made by a database function and
/// returns the secure payment page to open.
Future<String> paystackUrl(String reference) async {
  final token = sb.auth.currentSession?.accessToken;
  final j = await WebApi().post('/api/paystack-initialize', {'reference': reference}, token: token);
  final url = j['authorization_url'];
  if (url is! String || url.isEmpty) throw const AuthFlowException('Couldn\'t reach Paystack. Nothing was charged.');
  return url;
}

Future<String> requestWithdrawal({required num amount, required String network, required String account, required String name, required String password}) async {
  final token = sb.auth.currentSession?.accessToken;
  final j = await WebApi().post('/api/wallet-withdraw', {'amount': amount, 'network': network, 'account': account, 'name': name, 'password': password}, token: token);
  return '${j['reference'] ?? ''}';
}

// ---------- Career growth ----------
final xpEventsProvider = FutureProvider<List<Json>>((ref) async {
  _follow(ref);
  return sb.from('worker_xp_events').select('id,kind,points,created_at').eq('worker_id', myId).order('created_at', ascending: false).limit(20);
});

// ---------- Certifications ----------
final certsProvider = FutureProvider<List<Json>>((ref) async {
  _follow(ref);
  return sb.from('worker_certifications').select('id,cert_name,issuing_body,verified,created_at').eq('worker_id', myId).order('created_at', ascending: false);
});

// ---------- Team & join code / Link a company ----------
final pmLinksProvider = FutureProvider<List<Json>>((ref) async {
  _follow(ref);
  return asList(await sb.rpc('my_pm_links'));
});

// ---------- Company payments ----------
final companyPaymentsProvider = FutureProvider<List<Json>>((ref) async {
  _follow(ref);
  return asList(await sb.rpc('company_payments'));
});

// ---------- Equipment and materials from suppliers ----------
final supplierCatalogProvider = FutureProvider.family<List<Json>, String>((ref, kind) async {
  _follow(ref);
  return asList(await sb.rpc('supplier_catalog', params: {'p_kind': kind}));
});

// ---------- Orders ----------
final ordersProvider = FutureProvider<List<Json>>((ref) async {
  _follow(ref);
  return asList(await sb.rpc('my_orders'));
});

// ---------- Plans & billing ----------
class BillingData {
  const BillingData({required this.plans, required this.slots, required this.summary, required this.payments, required this.services});
  final List<Json> plans, payments, services;
  final Json? slots;
  final Json summary;
}

final billingProvider = FutureProvider<BillingData>((ref) async {
  _follow(ref);
  final role = (await ref.watch(accountProfileProvider.future))?.type?.webRole ?? '';
  final r = await Future.wait(<Future<dynamic>>[
    sb.from('membership_plans').select('*').eq('role', role).eq('is_active', true),
    sb.from('founding_slots').select('*').eq('role', role).maybeSingle(),
    sb.rpc('billing_summary').then((v) => v, onError: (_) => {'subscribed': false}),
    sb.rpc('my_payments').then((v) => v, onError: (_) => <Json>[]),
    sb.from('service_catalog').select('id,kind,code,label,price_minor,currency,duration_hours,metadata,role').eq('is_active', true).order('price_minor', ascending: true),
  ]);
  final services = [for (final s in asList(r[4])) if (s['role'] == null || s['role'] == role) s];
  return BillingData(plans: asList(r[0]), slots: r[1] == null ? null : asMap(r[1]), summary: asMap(r[2]), payments: asList(r[3]), services: services);
});

// ---------- Organizations ----------
final myOrgsProvider = FutureProvider<List<Json>>((ref) async {
  _follow(ref);
  return asList(await sb.rpc('my_orgs'));
});

final accessMatrixProvider = FutureProvider<Json>((ref) async {
  _follow(ref);
  return asMap(await sb.rpc('access_matrix'));
});

final orgTabProvider = FutureProvider.family<List<Json>, (String, String)>((ref, key) async {
  _follow(ref);
  final (org, tab) = key;
  final fn = switch (tab) { 'invites' => 'org_invitations_list', 'audit' => 'org_audit', _ => 'org_members_list' };
  return asList(await sb.rpc(fn, params: {'p_org': org}));
});
