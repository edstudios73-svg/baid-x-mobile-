import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';

/// Inline form feedback. Errors by default; pass [success] for confirmations.
class FormMessage extends StatelessWidget {
  const FormMessage(this.message, {this.success = false, super.key});

  final String message;
  final bool success;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final fg = success ? palette.success : palette.danger;
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: success ? palette.successBg : palette.dangerBg,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(success ? Icons.check_circle_outline : Icons.error_outline, size: 20, color: fg),
              const SizedBox(width: AppSpacing.xs),
              Expanded(child: Text(message, style: AppTextStyles.body.copyWith(color: fg, fontSize: 15))),
            ],
          ),
        ),
      ),
    );
  }
}

/// Neutral information, e.g. what a payment does and does not do.
class InfoNote extends StatelessWidget {
  const InfoNote(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.infoBg,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, size: 20, color: palette.info),
            const SizedBox(width: AppSpacing.xs),
            Expanded(child: Text(message, style: AppTextStyles.caption.copyWith(color: palette.text, fontSize: 14))),
          ],
        ),
      ),
    );
  }
}
