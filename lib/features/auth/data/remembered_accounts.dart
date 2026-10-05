import 'dart:convert';

import '../../../core/services/storage_service.dart';

/// Accounts used on this device, for the website's "Continue with" chooser
/// (js/common.js BX.accounts). Only display details are kept: no password and
/// no session token, so picking one still asks for the password.
class RememberedAccount {
  const RememberedAccount({required this.id, required this.name, required this.role, this.phone = '', this.photo});

  final String id;
  final String name;
  final String role; // AccountType.dbValue
  final String phone;
  final String? photo;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'role': role, 'phone': phone, 'photo': photo};

  static RememberedAccount? fromJson(Object? j) {
    if (j is! Map || j['id'] is! String || j['role'] is! String) return null;
    return RememberedAccount(id: j['id'] as String, name: (j['name'] as String?) ?? 'Account', role: j['role'] as String, phone: (j['phone'] as String?) ?? '', photo: j['photo'] as String?);
  }
}

class RememberedAccounts {
  RememberedAccounts(this._store);
  final KeyValueStore _store;
  static const _key = 'baidx_accounts';
  static const _max = 5;

  Future<List<RememberedAccount>> list() async {
    try {
      final raw = await _store.read(_key);
      if (raw == null || raw.isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return [for (final j in decoded) ?RememberedAccount.fromJson(j)];
    } catch (_) {
      return const []; // unreadable storage just means no chooser
    }
  }

  /// Most recent first, one entry per account.
  Future<void> remember(RememberedAccount a) async {
    final rest = (await list()).where((x) => x.id != a.id);
    await _write([a, ...rest].take(_max).toList());
  }

  Future<void> forget(String id) async => _write((await list()).where((x) => x.id != id).toList());

  Future<void> _write(List<RememberedAccount> items) async {
    try {
      await _store.write(_key, jsonEncode([for (final a in items) a.toJson()]));
    } catch (_) {
      // best effort: the chooser is a convenience
    }
  }
}
