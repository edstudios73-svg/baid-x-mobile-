/// Public app identity and the shared BAID X backend. Secrets never live here.
///
/// The app and the website share one Supabase project, so one account works on
/// both. The URL and publishable key are public (the website ships them too);
/// override them at build time with --dart-define if you point at another project.
abstract final class AppConfig {
  static const name = 'BAID X';
  static const tagline = 'Ghana\'s work network.';
  static const positioning =
      'Verified people, clear approvals and payments held safely until the work is done.';

  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://igfmmprlrybxsdzehwid.supabase.co',
  );
  static const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_lOw6Te3MRrvkpHt1V-WTmg_Albcae3P',
  );

  /// The BAID X website. Phone codes, phone sign-in and Paystack checkout run on
  /// its server so the app never holds a secret.
  static const webBase = String.fromEnvironment(
    'BAIDX_WEB_URL',
    defaultValue: 'https://baid-x-website.vercel.app',
  );

  /// Paystack test publishable key used by the old in-app checkout. Phase 6 moves
  /// checkout to the website's server like the website does.
  static const paystackPublicKey = 'pk_test_959c233e44480100f43e0c4272b2501a4d64b341';
}
