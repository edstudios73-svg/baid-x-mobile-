import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/app_spacing.dart';

/// Sticky footer for a screen's main action, e.g. "Apply" on a job.
/// Use as `Scaffold.bottomNavigationBar` so it stays above the keyboard inset.
class BottomActionBar extends StatelessWidget {
  const BottomActionBar({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(top: BorderSide(color: palette.line)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
          child: child,
        ),
      ),
    );
  }
}
