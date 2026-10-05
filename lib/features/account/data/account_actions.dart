import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';
import '../../../core/errors/app_exception.dart';
import '../../account_type/domain/account_type.dart';

/// Writes to the member's own profile on the shared backend, the same way the
/// website does (js/features.js save/upload/addEmail).
class AccountActions {
  SupabaseClient get _c {
    final c = SupabaseConfig.client;
    if (c == null) throw const ConfigurationException('BAID X is not connected yet.');
    return c;
  }

  String get _uid {
    final u = _c.auth.currentUser;
    if (u == null) throw const AuthFlowException('Your session expired. Sign in again.');
    return u.id;
  }

  Future<void> save(AccountType type, Map<String, dynamic> patch) async {
    if (patch.isEmpty) throw const AuthFlowException('Fill in this step first.');
    await _c.from(type.table).update(patch).eq('id', _uid);
  }

  static const _okExt = {'jpg', 'jpeg', 'png', 'webp', 'heic', 'pdf'};

  /// Uploads to `<uid>/<tag>-<time>.<ext>` and returns the storage path.
  Future<String> upload(String bucket, Uint8List bytes, String fileName, String tag) async {
    if (bytes.length > 8 * 1024 * 1024) throw const AuthFlowException('That file is over 8 MB. Choose a smaller one.');
    final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : 'jpg';
    if (!_okExt.contains(ext)) throw const AuthFlowException('Use a photo (JPG, PNG, WebP) or a PDF.');
    final path = '$_uid/$tag-${DateTime.now().millisecondsSinceEpoch}.$ext';
    final mime = ext == 'pdf' ? 'application/pdf' : 'image/${ext == 'jpg' ? 'jpeg' : ext}';
    await _c.storage.from(bucket).uploadBinary(path, bytes, fileOptions: FileOptions(contentType: mime, upsert: false));
    return path;
  }

  String publicUrl(String bucket, String path) => _c.storage.from(bucket).getPublicUrl(path);

  /// The profile column that holds the member's email, per account type.
  static String emailColumn(AccountType t) => switch (t) {
        AccountType.company || AccountType.business => 'contact_email',
        _ => 'email',
      };

  /// Adds the member's own email. Nobody gets an email at sign-up; the member
  /// types it here, it is saved on their profile, and Supabase sends a link so
  /// it can also be used to sign in (website: js/features.js addEmail).
  Future<void> addEmail(String raw, {AccountType? type}) async {
    final email = raw.trim().toLowerCase();
    if (!RegExp(r'^\S+@\S+\.\S+$').hasMatch(email) || email.length > 160) throw const AuthFlowException('Enter a valid email address.');
    if (email.endsWith('.invalid')) throw const AuthFlowException('Use your own email address.');
    try {
      // flagged so the website mirrors only an email the member added themselves
      await _c.auth.updateUser(UserAttributes(email: email, data: {'email_added': true}), emailRedirectTo: 'https://baid-x-website.vercel.app/index.html');
    } on AuthException catch (e) {
      final m = e.message.toLowerCase();
      if (m.contains('already') || m.contains('registered') || m.contains('exists')) throw const AuthFlowException('That email is already used by another account.');
      if (m.contains('rate') || m.contains('seconds')) throw const AuthFlowException('Please wait a minute before asking for another link.');
      throw AuthFlowException(e.message);
    }
    if (type != null) await save(type, {emailColumn(type): email});
  }

  /// (current confirmed email, email waiting for confirmation)
  (String, String) emailState() {
    final u = _c.auth.currentUser;
    final cur = (u?.email ?? '').toLowerCase().endsWith('.invalid') ? '' : (u?.email ?? '');
    return (cur, u?.newEmail ?? '');
  }

  /// Head count of rows matching [filter] (no rows are downloaded).
  Future<int?> count(String table, PostgrestFilterBuilder<PostgrestList> Function(PostgrestFilterBuilder<PostgrestList>) filter) async {
    try {
      final r = await filter(_c.from(table).select('id')).count(CountOption.exact);
      return r.count;
    } catch (_) {
      return null; // shown as "—", never a made-up number
    }
  }

  Future<List<Map<String, dynamic>>> rows(String table, String cols, PostgrestTransformBuilder<PostgrestList> Function(PostgrestFilterBuilder<PostgrestList>) filter) async {
    try {
      return await filter(_c.from(table).select(cols));
    } catch (_) {
      return const [];
    }
  }
}
