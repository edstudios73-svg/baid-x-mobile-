import '../../account_type/domain/account_type.dart';
import '../../account_type/domain/role_categories.dart';
import 'auth_user.dart';

/// The signed-in member's account on the shared BAID X backend.
class AccountProfile {
  const AccountProfile({
    required this.id,
    required this.displayName,
    required this.accountType,
    this.phone = '',
    this.verificationStatus = 'unverified',
    this.badgeTier,
    this.accountStatus = 'active',
    this.row = const {},
  });

  final String id;
  final String displayName;

  /// App value: worker, employer, business, project_manager or company.
  /// Null means the member hasn't chosen an account type yet.
  final String? accountType;
  final String phone;
  final String verificationStatus;
  final String? badgeTier;
  final String accountStatus;

  /// The member's full profile row (role-specific columns).
  final Map<String, dynamic> row;

  AccountType? get type => AccountType.fromDatabase(accountType);
  bool get isVerified => verificationStatus == 'verified';
}

/// What a phone code was sent for.
enum PhoneCodePurpose { signup, reset }

abstract class AuthRepository {
  AuthUser? get currentUser;
  Stream<AuthUser?> authStateChanges();

  Future<void> signInWithEmail({required String email, required String password});
  Future<void> signInWithPhone({required String phone, required String password});

  /// Sends a one-time code by SMS through the website's server.
  Future<void> startPhoneCode({required String phone, required PhoneCodePurpose purpose});

  /// Checks the code and signs the member in (a brand-new account for sign-up).
  Future<void> verifyPhoneCode({required String phone, required String code});

  /// Sets the password right after a verified code (sign-up or reset).
  Future<void> setPhonePassword(String password);

  Future<AuthUser?> refreshUser();
  Future<AccountProfile?> loadProfile();

  /// Creates the member's profile row for their account type. The database adds
  /// the account role, so the website sees the same account straight away.
  Future<void> createRoleProfile({
    required AccountType type,
    required String name,
    RoleCategory? category,
    String phone,
  });

  Future<void> sendPasswordReset(String email);
  Future<void> updatePassword(String password);
  Future<void> resendVerification(String email);
  Future<void> signOut();
}
