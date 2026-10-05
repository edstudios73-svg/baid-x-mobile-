import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Inter, like the website. Sizes follow the website's mobile layout.
abstract final class AppTextStyles {
  static const family = 'Inter';
  static const display = TextStyle(
    fontFamily: family,
    fontSize: 32,
    height: 1.15,
    fontWeight: FontWeight.w800,
    color: AppColors.text,
    letterSpacing: -0.5,
  );

  static const headline = TextStyle(
    fontFamily: family,
    fontSize: 28,
    height: 1.15,
    fontWeight: FontWeight.w800,
    color: AppColors.text,
    letterSpacing: -0.4,
  );

  static const title = TextStyle(
    fontFamily: family,
    fontSize: 22,
    height: 1.2,
    fontWeight: FontWeight.w800,
    color: AppColors.text,
    letterSpacing: -0.2,
  );

  static const section = TextStyle(
    fontFamily: family,
    fontSize: 18,
    height: 1.3,
    fontWeight: FontWeight.w700,
    color: AppColors.text,
  );

  static const body = TextStyle(
    fontFamily: family,
    fontSize: 16,
    height: 1.45,
    fontWeight: FontWeight.w500,
    color: AppColors.text,
  );

  static const bodyMuted = TextStyle(
    fontFamily: family,
    fontSize: 15,
    height: 1.45,
    fontWeight: FontWeight.w500,
    color: AppColors.textMuted,
  );

  static const caption = TextStyle(
    fontFamily: family,
    fontSize: 13,
    height: 1.35,
    fontWeight: FontWeight.w500,
    color: AppColors.textMuted,
  );

  static const numeric = TextStyle(
    fontFamily: family,
    fontFeatures: [FontFeature.tabularFigures()],
    fontSize: 20,
    height: 1.2,
    fontWeight: FontWeight.w700,
    color: AppColors.text,
    letterSpacing: -0.3,
  );

  static const label = TextStyle(
    fontFamily: family,
    fontSize: 14,
    height: 1.3,
    fontWeight: FontWeight.w700,
    color: AppColors.text,
  );

  static const button = TextStyle(
    fontFamily: family,
    fontSize: 16,
    height: 1.2,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.1,
  );
}
