import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';

/// A bordered group of [AppListRow]s separated by hairline dividers.
/// BAID X lists use divided rows instead of stacks of separate cards.
class AppListGroup extends StatelessWidget {
  const AppListGroup({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: palette.line),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg - 1),
        child: Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) Divider(height: 1, color: palette.line),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}

class AppListRow extends StatelessWidget {
  const AppListRow({
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.badge,
    this.onTap,
    this.subtitleLines = 1,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;

  /// Shown at the end. Defaults to a chevron when the row is tappable.
  final Widget? trailing;
  final Widget? badge;
  final VoidCallback? onTap;
  final int subtitleLines;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final end = trailing ?? (onTap == null ? null : Icon(Icons.chevron_right, color: palette.textMuted));
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            child: Row(
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: AppSpacing.sm)],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.label.copyWith(color: palette.text),
                            ),
                          ),
                          if (badge != null) ...[const SizedBox(width: 6), badge!],
                        ],
                      ),
                      if (subtitle != null && subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          maxLines: subtitleLines,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption.copyWith(color: palette.textMuted),
                        ),
                      ],
                    ],
                  ),
                ),
                if (end != null) ...[const SizedBox(width: AppSpacing.xs), end],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
