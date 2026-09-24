/// Public app identity. Secrets never live here.
abstract final class AppConfig {
  static const name = 'BAID X';
  static const tagline = 'Trust infrastructure for Africa\'s workforce.';
  static const positioning =
      'The future of work in Africa isn\'t about connections — it\'s about capability.';

  static const supabaseUrlKey = 'SUPABASE_URL';
  static const supabasePublishableKey = 'SUPABASE_PUBLISHABLE_KEY';

  /// Paystack test publishable key. The secret stays in the Edge Function.
  static const paystackPublicKey = 'pk_test_959c233e44480100f43e0c4272b2501a4d64b341';
}
