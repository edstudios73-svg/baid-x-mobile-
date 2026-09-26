import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_text_styles.dart';

enum BadgeTone { neutral, success, warning, danger, info, brand }

/// Small status label. The text always states the status; color only supports it.
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    required this.label,
    this.tone = BadgeTone.neutral,
    this.icon,
    super.key,
  });

  const StatusBadge.verified({super.key})
    : label = 'Verified',
      tone = BadgeTone.info,
      icon = Icons.verified_outlined;

  /// Maps a stored status value (job, application, access, verification) to a badge.
  factory StatusBadge.forStatus(String status, {Key? key}) {
    final value = status.trim().toLowerCase();
    final tone = switch (value) {
      'open' || 'active' || 'accepted' || 'approved' || 'verified' || 'hired' || 'paid' || 'completed' => BadgeTone.success,
      'pending' || 'submitted' || 'in_review' || 'under_review' || 'expiring' => BadgeTone.warning,
      'closed' || 'rejected' || 'cancelled' || 'canceled' || 'failed' || 'expired' => BadgeTone.danger,
      _ => BadgeTone.neutral,
    };
    return StatusBadge(label: statusLabel(value), tone: tone, key: key);
  }

  final String label;
  final BadgeTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final (bg, fg) = switch (tone) {
      BadgeTone.neutral => (palette.subtle, palette.textMuted),
      BadgeTone.success => (palette.successBg, palette.success),
      BadgeTone.warning => (palette.warningBg, palette.warning),
      BadgeTone.danger => (palette.dangerBg, palette.danger),
      BadgeTone.info => (palette.infoBg, palette.info),
      BadgeTone.brand => (AppColors.yellow, AppColors.ink),
    };
    return DecoratedBox(
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: fg),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: AppTextStyles.caption.copyWith(color: fg, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

/// "in_review" -> "In review".
String statusLabel(String status) {
  final words = status.replaceAll('_', ' ').trim();
  if (words.isEmpty) return '';
  return words[0].toUpperCase() + words.substring(1);
}
