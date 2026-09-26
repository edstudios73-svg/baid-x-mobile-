import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';

class QuickAction {
  const QuickAction({required this.label, required this.icon, required this.onTap});

  final String label;
  final IconData icon;
  final VoidCallback onTap;
}

/// Two columns on phones, four on tablets and web.
class QuickActionGrid extends StatelessWidget {
  const QuickActionGrid({required this.actions, super.key});

  final List<QuickAction> actions;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 560 ? 4 : 2;
        const gap = AppSpacing.xs;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final action in actions) SizedBox(width: width, child: _Tile(action: action)),
          ],
        );
      },
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.action});

  final QuickAction action;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Material(
      color: palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        side: BorderSide(color: palette.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: action.onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.yellow.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: Icon(action.icon, size: 18, color: palette.text),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    action.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.label.copyWith(color: palette.text),
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
