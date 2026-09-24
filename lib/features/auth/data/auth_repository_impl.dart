import '../domain/auth_repository.dart';
import '../domain/auth_user.dart';
import 'auth_remote_data_source.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._remote);

  final AuthRemoteDataSource _remote;

  @override
  AuthUser? get currentUser => _remote.currentUser;

  @override
  Stream<AuthUser?> authStateChanges() => _remote.authStateChanges();

  @override
  Future<AuthUser?> signIn({required String email, required String password}) {
    return _remote.signIn(email: email, password: password);
  }

  @override
  Future<AuthUser?> signUp({
    required String displayName,
    required String email,
    required String password,
  }) {
    return _remote.signUp(
      displayName: displayName,
      email: email,
      password: password,
    );
  }

  @override
  Future<AuthUser?> refreshUser() => _remote.refreshUser();

  @override
  Future<AccountProfile?> loadProfile() => _remote.loadProfile();

  @override
  Future<void> setAccountType(String dbValue) => _remote.setAccountType(dbValue);

  @override
  Future<void> sendPasswordReset(String email) => _remote.sendPasswordReset(email);

  @override
  Future<void> updatePassword(String password) => _remote.updatePassword(password);

  @override
  Future<void> resendVerification(String email) => _remote.resendVerification(email);

  @override
  Future<void> signOut() => _remote.signOut();
}
