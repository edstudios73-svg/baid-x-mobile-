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

  static const light = AppPalette(
    canvas: AppColors.canvas,
    surface: AppColors.surface,
    subtle: AppColors.subtle,
    line: AppColors.line,
    text: AppColors.text,
    textMuted: AppColors.textMuted,
    link: AppColors.blue,
    success: AppColors.success,
    successBg: AppColors.successBg,
    warning: AppColors.warning,
    warningBg: AppColors.warningBg,
    danger: AppColors.danger,
    dangerBg: AppColors.dangerBg,
    info: AppColors.info,
    infoBg: AppColors.infoBg,
  );

  static const dark = AppPalette(
    canvas: AppColors.darkCanvas,
    surface: AppColors.darkSurface,
    subtle: AppColors.darkSubtle,
    line: AppColors.darkLine,
    text: AppColors.white,
    textMuted: AppColors.darkTextMuted,
    link: AppColors.darkBlue,
    success: AppColors.darkSuccess,
    successBg: Color(0xFF10281B),
    warning: Color(0xFFF79009),
    warningBg: Color(0xFF2B1C0E),
    danger: AppColors.darkDanger,
    dangerBg: Color(0xFF2C1412),
    info: AppColors.darkBlue,
    infoBg: Color(0xFF0F1E2B),
  );

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
  /// Falls back to the light palette when a test pumps a bare MaterialApp.
  AppPalette get palette => Theme.of(this).extension<AppPalette>() ?? AppPalette.light;
}
