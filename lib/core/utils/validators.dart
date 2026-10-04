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

  /// Ghana mobile number: 0XXXXXXXXX or +233XXXXXXXXX (the server normalises it).
  static String? ghanaPhone(String? value) {
    final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
    final ok = (digits.length == 10 && digits.startsWith('0')) ||
        (digits.length == 12 && digits.startsWith('233')) ||
        digits.length == 9;
    return ok ? null : 'Enter a valid Ghana mobile number.';
  }

  /// Same rule as the website: 8+ characters, a letter, a number, and a capital letter or a symbol.
  static String? strongPassword(String? value) {
    final p = value ?? '';
    if (p.length < 8) return 'Use at least 8 characters.';
    if (!RegExp(r'[A-Za-z]').hasMatch(p)) return 'Add a letter.';
    if (!RegExp(r'\d').hasMatch(p)) return 'Add a number.';
    if (!RegExp(r'[A-Z]').hasMatch(p) && !RegExp(r'[^A-Za-z0-9]').hasMatch(p)) {
      return 'Add a capital letter or a symbol.';
    }
    return null;
  }

  static String? code(String? value) {
    final digits = (value ?? '').trim();
    if (!RegExp(r'^\d{4,8}$').hasMatch(digits)) return 'Enter the code you received.';
    return null;
  }
}
