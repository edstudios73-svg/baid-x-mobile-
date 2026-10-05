import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Semantic colors that follow light/dark mode. Shared widgets read these
/// through `context.palette` instead of hard-coding light-only [AppColors].
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.canvas,
    required this.surface,
    required this.subtle,
    required this.line,
    required this.text,
    required this.textMuted,
    required this.link,
    required this.success,
    required this.successBg,
    required this.warning,
    required this.warningBg,
    required this.danger,
    required this.dangerBg,
    required this.info,
    required this.infoBg,
  });

  /// The website has one look, so light and dark are the same palette.
  static const dark = AppPalette(
    canvas: AppColors.bg,
    surface: AppColors.card,
    subtle: AppColors.tile,
    line: AppColors.lineGlass,
    text: AppColors.textLight,
    textMuted: AppColors.muted,
    link: Colors.white,
    success: AppColors.green,
    successBg: AppColors.successBg,
    warning: AppColors.warning,
    warningBg: AppColors.warningBg,
    danger: AppColors.red,
    dangerBg: AppColors.dangerBg,
    info: AppColors.verified,
    infoBg: AppColors.infoBg,
  );
  static const light = dark;

  final Color canvas;
  final Color surface;
  final Color subtle;
  final Color line;
  final Color text;
  final Color textMuted;
  final Color link;
  final Color success;
  final Color successBg;
  final Color warning;
  final Color warningBg;
  final Color danger;
  final Color dangerBg;
  final Color info;
  final Color infoBg;

  @override
  AppPalette copyWith() => this;

  @override
  AppPalette lerp(AppPalette? other, double t) => t < 0.5 || other == null ? this : other;
}

extension AppPaletteContext on BuildContext {
  AppPalette get palette => Theme.of(this).extension<AppPalette>() ?? AppPalette.dark;
}
