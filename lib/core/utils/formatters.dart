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

  /// "Today", "Yesterday", "3 days ago", then a plain date after a month.
  static String relativeDate(DateTime date, {DateTime? now}) {
    final today = now ?? DateTime.now();
    final local = date.toLocal();
    final days = DateTime(today.year, today.month, today.day)
        .difference(DateTime(local.year, local.month, local.day))
        .inDays;
    if (days <= 0) return 'Today';
    if (days == 1) return 'Yesterday';
    if (days < 7) return '$days days ago';
    if (days < 30) return days < 14 ? '1 week ago' : '${days ~/ 7} weeks ago';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final base = '${local.day} ${months[local.month - 1]}';
    return local.year == today.year ? base : '$base ${local.year}';
  }

  /// "GH₵ 1,150" or "GH₵ 98.50". Unknown currencies keep their code.
  static String price(double amount, String currency) {
    final symbol = switch (currency.trim().toUpperCase()) {
      'GHS' || 'GHC' || '' => 'GH₵',
      'USD' => r'$',
      final code => code,
    };
    final totalCents = (amount.abs() * 100).round();
    final whole = totalCents ~/ 100;
    final cents = totalCents % 100;
    final grouped = whole.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
    final sign = amount < 0 ? '-' : '';
    return '$symbol $sign$grouped${cents == 0 ? '' : '.${cents.toString().padLeft(2, '0')}'}';
  }
}
