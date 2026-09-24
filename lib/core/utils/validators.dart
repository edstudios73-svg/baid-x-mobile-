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
}
