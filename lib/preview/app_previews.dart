import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../features/auth/presentation/screens/sign_in_screen.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import '../features/splash/presentation/splash_screen.dart';

/// Phone frame used by the Flutter Widget Previewer.
const phone = Size(390, 844);

Widget previewApp(Widget child) {
  return ProviderScope(
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: child,
    ),
  );
}

@Preview(name: 'Splash', group: 'BAID X', size: phone, wrapper: previewApp)
Widget splashPreview() => const SplashScreen();

@Preview(name: 'Get started', group: 'BAID X', size: phone, wrapper: previewApp)
Widget onboardingPreview() => const OnboardingScreen();

@Preview(name: 'Sign in', group: 'BAID X', size: phone, wrapper: previewApp)
Widget signInPreview() => const SignInScreen();
