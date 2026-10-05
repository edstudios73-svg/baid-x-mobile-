import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// The website's verification seal. Colour shows how the member was verified:
/// blue reviewed by BAID X, green identity, purple professional, gold advanced.
class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge(this.tier, {this.size = 17, super.key});

  final String? tier;
  final double size;

  static const labels = {
    'verified': 'Verified',
    'identity': 'Identity verified',
    'professional': 'Professional verified',
    'advanced': 'Advanced verified',
  };

  static Color colorOf(String? tier) => switch (tier) {
        'identity' => AppColors.green,
        'professional' => AppColors.violet,
        'advanced' => AppColors.gold,
        _ => AppColors.verified,
      };

  @override
  Widget build(BuildContext context) {
    if (tier == null) return const SizedBox.shrink();
    final c = colorOf(tier);
    return Tooltip(
      message: labels[tier] ?? 'Verified',
      child: Icon(Icons.verified, size: size, color: c, shadows: [Shadow(color: c.withValues(alpha: .55), blurRadius: 8)]),
    );
  }
}
