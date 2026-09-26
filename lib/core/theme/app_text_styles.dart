import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class AppTextStyles {
  static const display = TextStyle(
    fontSize: 32,
    height: 1.15,
    fontWeight: FontWeight.w800,
    color: AppColors.text,
    letterSpacing: -0.5,
  );

  static const headline = TextStyle(
    fontSize: 26,
    height: 1.2,
    fontWeight: FontWeight.w700,
    color: AppColors.text,
    letterSpacing: -0.4,
  );

  static const title = TextStyle(
    fontSize: 22,
    height: 1.25,
    fontWeight: FontWeight.w700,
    color: AppColors.text,
    letterSpacing: -0.2,
  );

  static const section = TextStyle(
    fontSize: 18,
    height: 1.3,
    fontWeight: FontWeight.w700,
    color: AppColors.text,
  );

  static const body = TextStyle(
    fontSize: 16,
    height: 1.45,
    fontWeight: FontWeight.w500,
    color: AppColors.text,
  );

  static const bodyMuted = TextStyle(
    fontSize: 15,
    height: 1.45,
    fontWeight: FontWeight.w500,
    color: AppColors.textMuted,
  );

  static const caption = TextStyle(
    fontSize: 13,
    height: 1.35,
    fontWeight: FontWeight.w500,
    color: AppColors.textMuted,
  );

  static const numeric = TextStyle(
    fontFeatures: [FontFeature.tabularFigures()],
    fontSize: 20,
    height: 1.2,
    fontWeight: FontWeight.w700,
    color: AppColors.text,
    letterSpacing: -0.3,
  );

  static const label = TextStyle(
    fontSize: 14,
    height: 1.3,
    fontWeight: FontWeight.w700,
    color: AppColors.text,
  );

  static const button = TextStyle(
    fontSize: 16,
    height: 1.2,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.2,
  );
}
