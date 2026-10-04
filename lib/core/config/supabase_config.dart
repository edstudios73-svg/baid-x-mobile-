import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_config.dart';

/// Connects to the shared BAID X Supabase project (the same one the website uses).
///
/// The service-role key is never read. A missing or placeholder publishable key
/// leaves the app unconnected instead of inventing a backend.
abstract final class SupabaseConfig {
  static bool initialized = false;

  static Future<void> initialize() async {
    const url = AppConfig.supabaseUrl;
    const key = AppConfig.supabasePublishableKey;
    if (!isConfigured(url) || !isConfigured(key)) {
      initialized = false;
      return;
    }
    await Supabase.initialize(url: url, publishableKey: key);
    initialized = true;
  }

  static SupabaseClient? get client =>
      initialized ? Supabase.instance.client : null;

  static bool isConfigured(String value) {
    if (value.trim().isEmpty) return false;
    final normalized = value.toUpperCase();
    return !normalized.contains('YOUR_') && !normalized.contains('PLACEHOLDER');
  }
}
