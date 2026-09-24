import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_config.dart';

/// Connects to the existing BAID X Supabase project.
///
/// The service-role key is never read. A missing or placeholder publishable
/// key leaves the app unconnected instead of inventing a backend.
abstract final class SupabaseConfig {
  static bool initialized = false;

  static Future<void> initialize() async {
    await dotenv.load(fileName: '.env');
    final url = dotenv.env[AppConfig.supabaseUrlKey]?.trim() ?? '';
    final key = dotenv.env[AppConfig.supabasePublishableKey]?.trim() ?? '';
    if (!_isConfigured(url) || !_isConfigured(key)) {
      initialized = false;
      return;
    }

    await Supabase.initialize(url: url, publishableKey: key);
    initialized = true;
  }

  static SupabaseClient? get client =>
      initialized ? Supabase.instance.client : null;

  static bool _isConfigured(String value) {
    if (value.isEmpty) return false;
    final normalized = value.toUpperCase();
    return !normalized.contains('YOUR_') && !normalized.contains('PLACEHOLDER');
  }
}
