import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_constants.dart';
import '../../shared/providers/app_providers.dart';

final themeModeProvider = AsyncNotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);

class ThemeModeController extends AsyncNotifier<ThemeMode> {
  static String storageKey(String userId) =>
      '${AppConstants.themeModeStorageKeyPrefix}$userId';

  @override
  Future<ThemeMode> build() async {
    final user = ref.watch(authStateProvider).asData?.value;
    if (user == null) return ThemeMode.dark;
    final stored = await ref.read(keyValueStoreProvider).read(storageKey(user.id));
    return stored == 'light' ? ThemeMode.light : ThemeMode.dark;
  }

  Future<void> useLight() => _store(ThemeMode.light);

  Future<void> useDark() => _store(ThemeMode.dark);

  Future<void> _store(ThemeMode mode) async {
    final user = ref.read(authStateProvider).asData?.value;
    if (user == null) return;
    await ref.read(keyValueStoreProvider).write(
      storageKey(user.id),
      mode == ThemeMode.light ? 'light' : 'dark',
    );
    state = AsyncData(mode);
  }
}
