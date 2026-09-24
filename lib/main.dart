import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/config/supabase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = FlutterError.presentError;
  PlatformDispatcher.instance.onError = (error, stack) => true;
  ErrorWidget.builder = (details) {
    return const Directionality(
      textDirection: TextDirection.ltr,
      child: Center(child: Text('Something went wrong. Go back and try again.')),
    );
  };
  await SupabaseConfig.initialize();
  runApp(const ProviderScope(child: BaidXApp()));
}
