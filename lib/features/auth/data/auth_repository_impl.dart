import '../../account_type/domain/account_type.dart';
import '../../account_type/domain/role_categories.dart';
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
  Future<void> signInWithEmail({required String email, required String password}) =>
      _remote.signInWithEmail(email: email, password: password);

  @override
  Future<void> signInWithPhone({required String phone, required String password}) =>
      _remote.signInWithPhone(phone: phone, password: password);

  @override
  Future<void> startPhoneCode({required String phone, required PhoneCodePurpose purpose}) =>
      _remote.startPhoneCode(phone: phone, purpose: purpose);

  @override
  Future<void> verifyPhoneCode({required String phone, required String code}) =>
      _remote.verifyPhoneCode(phone: phone, code: code);

  @override
  Future<void> setPhonePassword(String password) => _remote.setPhonePassword(password);

  @override
  Future<AuthUser?> refreshUser() => _remote.refreshUser();

  @override
  Future<AccountProfile?> loadProfile() => _remote.loadProfile();

  @override
  Future<void> createRoleProfile({
    required AccountType type,
    required String name,
    RoleCategory? category,
    String phone = '',
  }) =>
      _remote.createRoleProfile(type: type, name: name, category: category, phone: phone);

  @override
  Future<void> sendPasswordReset(String email) => _remote.sendPasswordReset(email);

  @override
  Future<void> updatePassword(String password) => _remote.updatePassword(password);

  @override
  Future<void> resendVerification(String email) => _remote.resendVerification(email);

  @override
  Future<void> signOut() => _remote.signOut();
}
