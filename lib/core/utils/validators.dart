abstract final class Validators {
  static final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String? name(String? value) {
    final text = value?.trim() ?? '';
    if (text.length < 2) return 'Enter your name.';
    return null;
  }

  static String? email(String? value) {
    final text = value?.trim() ?? '';
    if (!_email.hasMatch(text)) return 'Enter a valid email.';
    return null;
  }

  static String? password(String? value) {
    final text = value ?? '';
    if (text.length < 8) return 'Use at least 8 characters.';
    return null;
  }

  static String? confirmPassword(String? value, String original) {
    if (value == null || value.isEmpty) return 'Confirm your password.';
    if (value != original) return 'Passwords do not match.';
    return null;
  }

  static String? contact(String? value) {
    final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.length < 9) return 'Enter a phone number.';
    return null;
  }

  /// A Ghana number as +233XXXXXXXXX, or null. Accepts 020 607 1106, 20 607 1106,
  /// +233 20 607 1106, 233…, 00233… and +233 0…; the 9 digits after 233 start with 2, 3 or 5,
  /// the same rule as the website (js/auth.js) and the server (api/_lib/sasusync/phone.js).
  static String? ghanaE164(String? value) {
    var d = (value ?? '').replaceAll(RegExp(r'\D'), '').replaceFirst(RegExp(r'^00'), '');
    if (d.startsWith('233') && d.length > 10) d = d.substring(3);
    d = d.replaceFirst(RegExp(r'^0+'), '');
    return RegExp(r'^[235]\d{8}$').hasMatch(d) ? '+233$d' : null;
  }

  /// Ghana mobile number in any of the forms [ghanaE164] accepts.
  static String? ghanaPhone(String? value) => ghanaE164(value) == null ? 'Enter a valid Ghana mobile number.' : null;

  /// The symbols the sign-in service (Supabase Auth) counts.
  static final passwordSymbol = RegExp(r'''[!@#$%^&*()_+\-=\[\]{};'\\:"|<>?,./`~]''');

  /// Supabase Auth's own rule, as on the website: 8+ characters with a small letter, a capital,
  /// a number and a symbol. Anything looser is refused by Auth when the password is saved.
  static String? strongPassword(String? value) {
    final p = value ?? '';
    if (p.length < 8) return 'Use at least 8 characters.';
    if (!RegExp(r'[a-z]').hasMatch(p)) return 'Add a small letter.';
    if (!RegExp(r'[A-Z]').hasMatch(p)) return 'Add a capital letter.';
    if (!RegExp(r'\d').hasMatch(p)) return 'Add a number.';
    if (!passwordSymbol.hasMatch(p)) return 'Add a symbol, like ! @ # ?';
    return null;
  }

  static String? code(String? value) {
    final digits = (value ?? '').trim();
    if (!RegExp(r'^\d{4,8}$').hasMatch(digits)) return 'Enter the code you received.';
    return null;
  }
}
