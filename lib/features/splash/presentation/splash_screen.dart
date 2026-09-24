import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _fade;

  @override
  void initState() {
    super.initState();
    _fade = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fade.forward();
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ink,
      body: SafeArea(
        child: FadeTransition(
          opacity: CurvedAnimation(parent: _fade, curve: Curves.easeOut),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: [
                const Spacer(),
                Image.asset('assets/images/logo/baid_x_logo.png', width: 220),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  AppConfig.tagline,
                  style: AppTextStyles.body.copyWith(color: AppColors.white),
                  textAlign: TextAlign.center,
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
