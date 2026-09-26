import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/brand_logo.dart';

class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.ink,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - AppSpacing.lg * 2),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Spacer(),
                      const BrandLogo(width: 180),
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        AppConfig.positioning,
                        style: AppTextStyles.headline.copyWith(color: AppColors.onInk),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Container(width: 36, height: 3, color: AppColors.yellow),
                      const SizedBox(height: AppSpacing.lg),
                      const _Point(icon: Icons.search, text: 'Find work, people, and materials.'),
                      const _Point(icon: Icons.verified_outlined, text: 'Keep a record of completed work.'),
                      const _Point(
                        icon: Icons.public,
                        text: 'Ghana first. The same account works on the website and this app.',
                        muted: true,
                      ),
                      const Spacer(),
                      const SizedBox(height: AppSpacing.lg),
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
            ),
          ),
        ),
      ),
    );
  }
}

class _Point extends StatelessWidget {
  const _Point({required this.icon, required this.text, this.muted = false});

  final IconData icon;
  final String text;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.yellow),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: (muted ? AppTextStyles.bodyMuted : AppTextStyles.body).copyWith(
                color: muted ? AppColors.onInkMuted : AppColors.onInk,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
