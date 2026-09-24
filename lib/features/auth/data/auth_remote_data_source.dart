import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

import '../../../core/config/supabase_config.dart';
import '../../../core/errors/app_exception.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_user.dart';

class AuthRemoteDataSource {
  static const passwordRedirect = 'com.baidx.baid_x_mobile://login-callback';

  SupabaseClient get _client {
    final client = SupabaseConfig.client;
    if (client == null) {
      throw const ConfigurationException(
        'BAID X is not connected yet. Add the Supabase URL and publishable key to .env.',
      );
    }
    return client;
  }

  AuthUser? get currentUser => _map(_safeUser());

  Stream<AuthUser?> authStateChanges() {
    final client = SupabaseConfig.client;
    if (client == null) return Stream.value(null);
    return client.auth.onAuthStateChange.map(
      (event) => _map(event.session?.user),
    );
  }

  Future<AuthUser?> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    return _map(response.user);
  }

  Future<AuthUser?> signUp({
    required String displayName,
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {'display_name': displayName},
      emailRedirectTo: passwordRedirect,
    );
    final user = _map(response.user);
    if (user != null && user.emailConfirmed) {
      await _saveDisplayName(user.id, displayName);
    }
    return user;
  }

  Future<AuthUser?> refreshUser() async {
    final response = await _client.auth.getUser();
    final user = _map(response.user);
    final pending = response.user?.userMetadata?['display_name'];
    if (user != null && user.emailConfirmed && pending is String && pending.trim().isNotEmpty) {
      await _saveDisplayName(user.id, pending.trim());
    }
    return user;
  }

  Future<void> setAccountType(String dbValue) {
    return _client.rpc('set_account_type', params: {'selected': dbValue});
  }

  Future<AccountProfile?> loadProfile() async {
    final user = _safeUser();
    if (user == null) return null;
    final row = await _client
        .from('profiles')
        .select('id, display_name, account_type')
        .eq('id', user.id)
        .maybeSingle();
    if (row == null) return null;
    final id = row['id'] as String;
    if (id != user.id) {
      throw const AuthFlowException('This profile does not match the signed-in account.');
    }
    return AccountProfile(
      id: id,
      displayName: (row['display_name'] as String?) ?? '',
      accountType: row['account_type'] as String?,
    );
  }

  Future<void> sendPasswordReset(String email) {
    return _client.auth.resetPasswordForEmail(
      email,
      redirectTo: passwordRedirect,
    );
  }

  Future<void> updatePassword(String password) {
    return _client.auth.updateUser(UserAttributes(password: password));
  }

  Future<void> resendVerification(String email) {
    return _client.auth.resend(
      type: OtpType.signup,
      email: email,
      emailRedirectTo: passwordRedirect,
    );
  }

  Future<void> signOut() => _client.auth.signOut();

  Future<void> _saveDisplayName(String id, String name) {
    return _client.from('profiles').update({'display_name': name}).eq('id', id);
  }

  User? _safeUser() {
    if (SupabaseConfig.client == null) return null;
    return _client.auth.currentUser;
  }

  AuthUser? _map(User? user) {
    if (user == null) return null;
    return AuthUser(
      id: user.id,
      email: user.email ?? '',
      emailConfirmed: user.emailConfirmedAt != null,
    );
  }
}
