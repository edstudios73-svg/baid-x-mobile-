import 'package:flutter/material.dart';

/// Colors taken from the BAID X logo: black, white, and signal yellow.
/// Blue is the secondary brand color from the written BAID X direction.
///
/// Roles (Phase 14 design system, mirrored in the Figma "BAID X Color" variables):
/// - orange: primary action fill (buttons), always with ink text.
/// - yellow: brand and selection — nav indicator, selected chips, progress, own messages.
/// - blue: trust — verification, links, information.
abstract final class AppColors {
  static const ink = Color(0xFF111111);
  static const inkSoft = Color(0xFF2A2A2A);
  static const yellow = Color(0xFFFFD100);
  static const yellowPressed = Color(0xFFE6BC00);
  static const orange = Color(0xFFFF7A1A);
  static const orangePressed = Color(0xFFD96816);
  static const blue = Color(0xFF0E3A5D);
  static const darkCanvas = Color(0xFF0F0F0F);
  static const darkSurface = Color(0xFF1A1A1A);
  static const darkSubtle = Color(0xFF222222);
  static const darkLine = Color(0xFF2E2E2E);
  static const darkTextMuted = Color(0xFF9A968F);
  static const darkBlue = Color(0xFF5B9BD5);
  static const darkSuccess = Color(0xFF22C55E);
  static const darkDanger = Color(0xFFF97066);
  static const white = Color(0xFFFFFFFF);
  static const canvas = Color(0xFFF6F5F2);
  static const surface = Color(0xFFFFFFFF);
  static const subtle = Color(0xFFEFEDE8);
  static const line = Color(0xFFE4E1DA);
  static const text = Color(0xFF161616);
  static const textMuted = Color(0xFF5E5A54);
  static const textDisabled = Color(0xFF8F8A82);
  static const danger = Color(0xFFB42318);
  static const dangerBg = Color(0xFFFDECEA);
  static const success = Color(0xFF067647);
  static const successBg = Color(0xFFE7F4EE);
  static const warning = Color(0xFFB54708);
  static const warningBg = Color(0xFFFDF1E7);
  static const info = Color(0xFF0E3A5D);
  static const infoBg = Color(0xFFE8EEF4);
  static const elevated = Color(0xFFFFFFFF);

  /// Text on the ink home header band. Same in light and dark.
  static const onInk = Color(0xFFFFFFFF);
  static const onInkMuted = Color(0xFFB8B3AA);
}
