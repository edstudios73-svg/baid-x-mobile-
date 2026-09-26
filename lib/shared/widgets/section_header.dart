import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({required this.title, this.actionLabel, this.onAction, super.key});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(child: Text(title, style: AppTextStyles.section.copyWith(color: palette.text))),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                minimumSize: const Size(48, 40),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                foregroundColor: palette.link,
              ),
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}
