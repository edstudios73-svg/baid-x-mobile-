import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/app_config.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'shared/widgets/baid_ui.dart';

class BaidXApp extends ConsumerWidget {
  const BaidXApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: AppConfig.name,
      theme: AppTheme.website,
      themeMode: ThemeMode.dark,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      // every screen sits on the website's backdrop (black, grid, top glow)
      builder: (context, child) => AppBackdrop(child: child),
    );
  }
}
