import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import 'app_button.dart';

class AppErrorView extends StatelessWidget {
  const AppErrorView({
    required this.message,
    this.onRetry,
    super.key,
  });

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 32, color: AppColors.ink),
            const SizedBox(height: AppSpacing.md),
            Text('Something went wrong.', style: AppTextStyles.section, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.xs),
            Text(message, style: AppTextStyles.bodyMuted, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.lg),
              AppButton(label: 'Try again', onPressed: onRetry),
            ],
          ],
        ),
      ),
    );
  }
}
