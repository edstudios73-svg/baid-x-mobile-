import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/errors/error_handler.dart';
import '../../../core/services/storage_service.dart';
import '../../features/auth/data/auth_remote_data_source.dart';
import '../../features/auth/data/auth_repository_impl.dart';
import '../../features/auth/domain/auth_repository.dart';
import '../../features/auth/domain/auth_user.dart';

final keyValueStoreProvider = Provider<KeyValueStore>(
  (ref) => SecureKeyValueStore(),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepositoryImpl(AuthRemoteDataSource()),
);

final authStateProvider = StreamProvider<AuthUser?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
});

final accountProfileProvider = FutureProvider<AccountProfile?>((ref) async {
  final user = ref.watch(authStateProvider).asData?.value;
  if (user == null || !user.emailConfirmed) return null;
  return ref.read(authRepositoryProvider).loadProfile();
});

/// The number a member just verified during sign-up, so account setup can put it
/// on their profile (phone accounts sign in with an internal placeholder email).
final pendingPhoneProvider = NotifierProvider<PendingPhone, String>(PendingPhone.new);

class PendingPhone extends Notifier<String> {
  @override
  String build() => '';
  void set(String phone) => state = phone;
}

final onboardingCompleteProvider =
    AsyncNotifierProvider<OnboardingController, bool>(OnboardingController.new);

class OnboardingController extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final value = await ref
        .read(keyValueStoreProvider)
        .read(AppConstants.onboardingStorageKey);
    return value == 'true';
  }

  Future<void> complete() async {
    await ref
        .read(keyValueStoreProvider)
        .write(AppConstants.onboardingStorageKey, 'true');
    state = const AsyncData(true);
  }
}

final authActionProvider =
    NotifierProvider<AuthActionController, AsyncValue<void>>(
      AuthActionController.new,
    );

class AuthActionController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<bool> run(Future<void> Function() action) async {
    state = const AsyncLoading();
    try {
      await action();
      state = const AsyncData(null);
      return true;
    } catch (error) {
      state = AsyncError(ErrorHandler.toAppException(error), StackTrace.current);
      return false;
    }
  }
}
