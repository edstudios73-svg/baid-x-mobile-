import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// The website's verification seal. Colour shows how the member was verified:
/// blue reviewed by BAID X, green identity, purple professional, white advanced.
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

/// A paid member's plan mark beside the name (website `.m-plan`): solid white with
/// black text, so it reads apart from the verification seal. It says the member
/// pays for BAID X, not that BAID X checked them.
class PlanMark extends StatelessWidget {
  const PlanMark(this.label, {super.key});

  final String label; // Pro | Premium | Enterprise

  @override
  Widget build(BuildContext context) => Semantics(
        label: '$label member',
        child: Container(
          height: 19,
          padding: const EdgeInsets.symmetric(horizontal: 7),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
          child: Text(label.toUpperCase(), style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: .6, height: 1)),
        ),
      );
}
