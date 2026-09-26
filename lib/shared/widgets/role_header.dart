import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import 'status_badge.dart';

/// The BAID X home header: an ink band with the person's name, trust status
/// and a thin yellow profile-completion rule. Ink in both light and dark mode.
class RoleHeader extends StatelessWidget {
  const RoleHeader({
    required this.greeting,
    required this.name,
    required this.subtitle,
    required this.completionPercent,
    this.verified = false,
    this.actions = const [],
    super.key,
  });

  final String greeting;
  final String name;
  final String subtitle;
  final int completionPercent;
  final bool verified;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final percent = completionPercent.clamp(0, 100);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: ColoredBox(
        color: AppColors.ink,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.xs, AppSpacing.xs, AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(greeting, style: AppTextStyles.caption.copyWith(color: AppColors.onInkMuted)),
                    ),
                    IconTheme.merge(
                      data: const IconThemeData(color: AppColors.onInk),
                      child: Row(mainAxisSize: MainAxisSize.min, children: actions),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xxs,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.headline.copyWith(color: AppColors.onInk),
                          ),
                          if (verified) const StatusBadge.verified(),
                        ],
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodyMuted.copyWith(color: AppColors.onInkMuted),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Profile $percent% complete',
                        style: AppTextStyles.caption.copyWith(color: AppColors.onInkMuted),
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          minHeight: 4,
                          value: percent / 100,
                          color: AppColors.yellow,
                          backgroundColor: AppColors.onInk.withValues(alpha: 0.18),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
