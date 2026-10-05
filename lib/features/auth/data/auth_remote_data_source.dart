import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

import '../../../core/config/supabase_config.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/services/web_api.dart';
import '../../account_type/domain/account_type.dart';
import '../../account_type/domain/role_categories.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_user.dart';

/// Sign-in and accounts on the shared BAID X backend, the same way the website
/// does it: phone codes and phone sign-in go through the website's server; email
/// sign-in uses Supabase directly.
class AuthRemoteDataSource {
  AuthRemoteDataSource({WebApi? api}) : _api = api ?? WebApi();

  static const passwordRedirect = 'com.baidx.baid_x_mobile://login-callback';
  final WebApi _api;

  SupabaseClient get _client {
    final client = SupabaseConfig.client;
    if (client == null) {
      throw const ConfigurationException('BAID X is not connected yet. Try again shortly.');
    }
    return client;
  }

  AuthUser? get currentUser => _map(_safeUser());

  Stream<AuthUser?> authStateChanges() {
    final client = SupabaseConfig.client;
    if (client == null) return Stream.value(null);
    return client.auth.onAuthStateChange.map((event) => _map(event.session?.user));
  }

  Future<void> signInWithEmail({required String email, required String password}) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signInWithPhone({required String phone, required String password}) async {
    final res = await _api.post('/api/auth/phone/login', {'phone': phone, 'password': password});
    await _adopt(res);
  }

  Future<void> startPhoneCode({required String phone, required PhoneCodePurpose purpose}) async {
    await _api.post('/api/auth/phone/start', {'phone': phone, 'purpose': purpose.name});
  }

  Future<void> verifyPhoneCode({required String phone, required String code}) async {
    final res = await _api.post('/api/auth/phone/verify', {'phone': phone, 'code': code.trim()});
    await _adopt(res);
  }

  Future<void> setPhonePassword(String password) async {
    final token = _client.auth.currentSession?.accessToken;
    if (token == null) throw const AuthFlowException('Please verify your number again.');
    final res = await _api.post('/api/auth/phone/password', {'password': password}, token: token);
    // the server ends old sessions when a password changes and returns a fresh one
    if (res['session'] is Map) await _adopt(res);
  }

  Future<AuthUser?> refreshUser() async {
    final response = await _client.auth.getUser();
    return _map(response.user);
  }

  Future<AccountProfile?> loadProfile() async {
    final user = _safeUser();
    if (user == null) return null;
    // On a fresh open the saved access token is often expired and refreshes in
    // the background; reading with it fails, which used to look like "no account
    // type yet" and flashed role selection before the dashboard.
    final session = _client.auth.currentSession;
    if (session != null && session.isExpired) {
      await _client.auth.refreshSession();
    }
    final role = await _client
        .from('account_roles')
        .select('role, account_status')
        .eq('user_id', user.id)
        .maybeSingle();
    final type = AccountType.fromDatabase(role?['role'] as String?);
    if (type == null) {
      return AccountProfile(id: user.id, displayName: '', accountType: null);
    }
    final row = await _client.from(type.table).select().eq('id', user.id).maybeSingle() ?? const <String, dynamic>{};
    return AccountProfile(
      id: user.id,
      displayName: (row[type.nameColumn] as String?) ?? '',
      accountType: type.dbValue,
      phone: (row[type.phoneColumn] as String?) ?? '',
      verificationStatus: (row['verification_status'] as String?) ?? 'unverified',
      badgeTier: row['badge_tier'] as String?,
      accountStatus: (role?['account_status'] as String?) ?? 'active',
      row: row,
    );
  }

  Future<void> createRoleProfile({
    required AccountType type,
    required String name,
    RoleCategory? category,
    String phone = '',
  }) async {
    final user = _safeUser();
    if (user == null) throw const AuthFlowException('Your session expired. Sign in again.');
    // no email is assigned at sign-up: members add their own from the profile
    final values = switch (type) {
      AccountType.worker => {'full_name': name, 'phone_number': phone, 'primary_job_category_id': ?category?.id},
      AccountType.company => {'company_name': name, 'contact_phone': phone, 'industry_sector': ?category?.id},
      AccountType.projectManager => {'full_name': name, 'phone_number': phone, 'specialization': ?category?.id},
      AccountType.business => {'business_name': name, 'contact_person_name': name, 'contact_phone': phone, 'specialty': ?category?.name},
      AccountType.employer => {'full_name': name, 'phone_number': phone, 'profile_sections': {'need_category': ?category?.name}},
    };
    try {
      await _client.from(type.table).insert({'id': user.id, ...values});
    } on PostgrestException catch (e) {
      if (e.code != '23505') rethrow; // a retry after a dropped connection: the profile already exists
    }
  }

  Future<void> sendPasswordReset(String email) {
    return _client.auth.resetPasswordForEmail(email, redirectTo: passwordRedirect);
  }

  Future<void> updatePassword(String password) {
    return _client.auth.updateUser(UserAttributes(password: password));
  }

  Future<void> resendVerification(String email) {
    return _client.auth.resend(type: OtpType.signup, email: email, emailRedirectTo: passwordRedirect);
  }

  Future<void> signOut() => _client.auth.signOut();

  Future<void> _adopt(Map<String, dynamic> res) async {
    final session = res['session'];
    final refresh = session is Map ? session['refresh_token'] : null;
    if (refresh is! String || refresh.isEmpty) {
      throw const AuthFlowException('Couldn\'t sign you in. Try again.');
    }
    await _client.auth.setSession(refresh);
  }

  User? _safeUser() {
    if (SupabaseConfig.client == null) return null;
    return _client.auth.currentUser;
  }

  AuthUser? _map(User? user) {
    if (user == null) return null;
    final placeholder = (user.email ?? '').toLowerCase().endsWith('.invalid');
    return AuthUser(
      id: user.id,
      email: placeholder ? '' : (user.email ?? ''),
      // phone accounts proved control of their number with a code
      emailConfirmed: placeholder || user.emailConfirmedAt != null,
    );
  }
}
