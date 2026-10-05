import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/app_config.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'shared/providers/app_providers.dart';
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
      builder: (context, child) {
        // A large system font size scaled every screen past the website's layout
        // (overlapping cards); allow a little growth for readability, no more.
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(textScaler: mq.textScaler.clamp(minScaleFactor: 1, maxScaleFactor: 1.1)),
          // signed-in screens get the drifting glass art; one backdrop group lets every glass card share a blur pass
          child: BackdropGroup(child: AppBackdrop(art: ref.watch(authStateProvider).asData?.value != null, child: child)),
        );
      },
    );
  }
}
