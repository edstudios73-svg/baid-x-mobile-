import 'auth_user.dart';

class AccountProfile {
  const AccountProfile({
    required this.id,
    required this.displayName,
    required this.accountType,
  });

  final String id;
  final String displayName;

  /// Database value: worker, employer, business, project_manager, or company.
  /// Null means Phase 4 has not chosen a type yet.
  final String? accountType;
}

abstract class AuthRepository {
  AuthUser? get currentUser;
  Stream<AuthUser?> authStateChanges();
  Future<AuthUser?> signIn({required String email, required String password});
  Future<AuthUser?> signUp({
    required String displayName,
    required String email,
    required String password,
  });
  Future<AuthUser?> refreshUser();
  Future<AccountProfile?> loadProfile();
  Future<void> setAccountType(String dbValue);
  Future<void> sendPasswordReset(String email);
  Future<void> updatePassword(String password);
  Future<void> resendVerification(String email);
  Future<void> signOut();
}
