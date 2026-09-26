import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';

/// Initials avatar for people and businesses, or an icon tile for things.
class AppAvatar extends StatelessWidget {
  const AppAvatar({required this.name, this.size = 44, super.key}) : icon = null, square = false;

  const AppAvatar.icon(IconData this.icon, {this.size = 44, super.key}) : name = '', square = true;

  final String name;
  final IconData? icon;
  final double size;
  final bool square;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: palette.subtle,
        borderRadius: BorderRadius.circular(square ? AppSpacing.radiusSm : size / 2),
      ),
      child: icon != null
          ? Icon(icon, size: size * 0.5, color: palette.textMuted)
          : Text(
              initialsOf(name),
              style: AppTextStyles.label.copyWith(color: palette.text, fontSize: size * 0.32),
            ),
    );
  }
}

String initialsOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  final first = parts.first[0];
  final second = parts.length > 1 ? parts[1][0] : (parts.first.length > 1 ? parts.first[1] : '');
  return (first + second).toUpperCase();
}
