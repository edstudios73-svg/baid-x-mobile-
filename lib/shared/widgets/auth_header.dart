import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import 'brand_logo.dart';

/// Ink header for sign-in and account screens: logo, title, one-line help.
class AuthHeader extends StatelessWidget {
  const AuthHeader({required this.title, this.subtitle, super.key});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final canPop = GoRouter.maybeOf(context)?.canPop() ?? Navigator.of(context).canPop();
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: ColoredBox(
        color: AppColors.ink,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.xs, AppSpacing.lg, AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 48,
                  child: canPop
                      ? Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            alignment: Alignment.centerLeft,
                            tooltip: 'Back',
                            color: AppColors.onInk,
                            icon: const Icon(Icons.arrow_back),
                            onPressed: () => Navigator.of(context).maybePop(),
                          ),
                        )
                      : null,
                ),
                const BrandLogo(width: 132),
                const SizedBox(height: AppSpacing.lg),
                Text(title, style: AppTextStyles.headline.copyWith(color: AppColors.onInk)),
                if (subtitle != null) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(subtitle!, style: AppTextStyles.bodyMuted.copyWith(color: AppColors.onInkMuted)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
