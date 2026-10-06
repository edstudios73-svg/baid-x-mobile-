import 'package:flutter/material.dart';

/// The BAID X website palette (css/theme.css): near-black canvas, frosted glass
/// surfaces, white "ember" actions with a soft glow, and a few status colours.
/// The app is dark only, like the website.
///
/// Older names (ink, orange, yellow, blue...) are kept so existing screens keep
/// compiling; they now point at the website colours.
abstract final class AppColors {
  // website tokens
  static const bg = Color(0xFF050505); // --bg
  static const card = Color(0xFF0E0E0E); // --card
  static const tile = Color(0xFF151515); // --tile
  static const lineGlass = Color(0x13FFFFFF); // --line rgba(255,255,255,.075)
  static const glass = Color(0x0BFFFFFF); // rgba(255,255,255,.045)
  static const glassHi = Color(0x14FFFFFF); // rgba(255,255,255,.08)
  static const textLight = Color(0xFFF6F6F7); // --text
  static const muted = Color(0xFF8C8C8C); // --muted
  static const verified = Color(0xFF38BDF8); // --verified (admin badge)
  static const green = Color(0xFF34D399); // --green (identity badge, ok pills)
  static const violet = Color(0xFFA78BFA); // professional badge
  static const gold = Colors.white; // advanced badge: white, like the logo
  static const red = Color(0xFFF87171);

  // legacy names, mapped to the website palette
  static const ink = bg;
  static const inkSoft = tile;
  static const yellow = Colors.white;
  static const yellowPressed = Color(0xFFE4E4E4);
  static const orange = Colors.white;
  static const orangePressed = Color(0xFFE4E4E4);
  static const blue = verified;
  static const darkCanvas = bg;
  static const darkSurface = card;
  static const darkSubtle = tile;
  static const darkLine = lineGlass;
  static const darkTextMuted = muted;
  static const darkBlue = verified;
  static const darkSuccess = green;
  static const darkDanger = red;
  static const white = Colors.white;
  static const canvas = bg;
  static const surface = card;
  static const subtle = tile;
  static const line = lineGlass;
  static const text = textLight;
  static const textMuted = muted;
  static const textDisabled = Color(0xFF5C5C5C);
  static const danger = red;
  static const dangerBg = Color(0x24F87171);
  static const success = green;
  static const successBg = Color(0x2434D399);
  static const warning = Color(0xFFD6D6D6);
  static const warningBg = Color(0x24FFFFFF);
  static const info = verified;
  static const infoBg = Color(0x2438BDF8);
  static const elevated = tile;
  static const onInk = Colors.white;
  static const onInkMuted = muted;
}
