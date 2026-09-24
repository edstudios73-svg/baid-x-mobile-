abstract final class Formatters {
  static String phone(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return '';
    return digits;
  }

  static String greetingName(String? name) {
    final text = name?.trim() ?? '';
    if (text.isEmpty) return 'there';
    return text.split(' ').first;
  }
}
