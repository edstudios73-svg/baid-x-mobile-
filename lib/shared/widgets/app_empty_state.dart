import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';

class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    required this.title,
    required this.message,
    super.key,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(color: AppColors.line),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.title),
              const SizedBox(height: AppSpacing.xs),
              Text(message, style: AppTextStyles.bodyMuted),
            ],
          ),
        ),
      ),
    );
  }
}
