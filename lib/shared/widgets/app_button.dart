import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';

class AppButton extends StatelessWidget {
  const AppButton({
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.outlined = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final child = isLoading
        ? const SizedBox(
            height: 22,
            width: 22,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          )
        : Text(label, style: AppTextStyles.button);

    if (outlined) {
      return OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        child: child,
      );
    }
    return FilledButton(
      onPressed: isLoading ? null : onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
        child: child,
      ),
    );
  }
}
