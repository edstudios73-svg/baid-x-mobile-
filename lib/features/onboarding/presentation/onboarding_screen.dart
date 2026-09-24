import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/app_button.dart';

class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              Text(AppConfig.name, style: AppTextStyles.display),
              const SizedBox(height: AppSpacing.md),
              const Text(AppConfig.positioning, style: AppTextStyles.body),
              const SizedBox(height: AppSpacing.lg),
              const Text(
                'Ghana first. The same BAID X account works on the website and this app.',
                style: AppTextStyles.bodyMuted,
              ),
              const Spacer(),
              AppButton(
                label: 'Get started',
                onPressed: () async {
                  await ref.read(onboardingCompleteProvider.notifier).complete();
                  if (context.mounted) context.go(AppRoutes.home);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
