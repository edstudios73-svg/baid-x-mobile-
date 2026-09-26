import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';

/// Scrollable page content with phone gutters, capped at a readable width
/// on tablets and web so layouts are not simply stretched.
class PageBody extends StatelessWidget {
  const PageBody({required this.children, this.maxWidth = 720, super.key});

  final List<Widget> children;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xs, AppSpacing.md, AppSpacing.xl),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
          ),
        ),
      ],
    );
  }
}
