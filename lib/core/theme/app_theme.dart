import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_palette.dart';
import 'app_spacing.dart';
import 'app_text_styles.dart';

/// The BAID X website look (css/theme.css + css/app.css), as a Material theme.
/// Screens sit on a transparent scaffold over the shared backdrop (grid, glow
/// and soft shapes), see [AppBackdrop].
abstract final class AppTheme {
  static ThemeData get light => website;
  static ThemeData get dark => website;

  static ThemeData get website {
    const scheme = ColorScheme.dark(
      primary: Colors.white,
      onPrimary: Colors.black,
      secondary: Colors.white,
      onSecondary: Colors.black,
      surface: AppColors.card,
      onSurface: AppColors.textLight,
      surfaceContainerHighest: AppColors.tile,
      error: AppColors.red,
      onError: Colors.black,
      outline: AppColors.lineGlass,
      outlineVariant: AppColors.lineGlass,
    );
    final pill = RoundedRectangleBorder(borderRadius: BorderRadius.circular(99));
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      fontFamily: AppTextStyles.family,
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: AppColors.bg,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.white10,
      textTheme: ThemeData.dark().textTheme.apply(fontFamily: AppTextStyles.family, bodyColor: AppColors.textLight, displayColor: AppColors.textLight),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textLight,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: AppTextStyles.section.copyWith(fontWeight: FontWeight.w800),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.glass,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
        hintStyle: AppTextStyles.body.copyWith(color: AppColors.muted, fontWeight: FontWeight.w400),
        labelStyle: AppTextStyles.body.copyWith(color: AppColors.muted),
        floatingLabelStyle: AppTextStyles.label.copyWith(color: AppColors.textLight),
        border: _border(const Color(0x1FFFFFFF)),
        enabledBorder: _border(const Color(0x1FFFFFFF)),
        focusedBorder: _border(const Color(0x99FFFFFF), width: 1.4),
        errorBorder: _border(AppColors.red),
        focusedErrorBorder: _border(AppColors.red, width: 1.4),
        errorStyle: AppTextStyles.caption.copyWith(color: AppColors.red),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          disabledBackgroundColor: const Color(0x24FFFFFF),
          disabledForegroundColor: const Color(0x80FFFFFF),
          minimumSize: const Size.fromHeight(AppSpacing.buttonHeight),
          textStyle: AppTextStyles.button,
          elevation: 0,
          shadowColor: Colors.white,
          shape: pill,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textLight,
          backgroundColor: const Color(0x0AFFFFFF),
          minimumSize: const Size.fromHeight(AppSpacing.buttonHeight),
          textStyle: AppTextStyles.button,
          side: const BorderSide(color: Color(0x1FFFFFFF)),
          shape: pill,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.textLight,
          textStyle: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700),
          shape: pill,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(foregroundColor: AppColors.textLight)),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : const Color(0x0AFFFFFF)),
          foregroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.black : AppColors.textLight),
          side: const WidgetStatePropertyAll(BorderSide(color: Color(0x1FFFFFFF))),
          textStyle: WidgetStatePropertyAll(AppTextStyles.label.copyWith(fontWeight: FontWeight.w700)),
          shape: WidgetStatePropertyAll(pill),
        ),
        selectedIcon: const SizedBox.shrink(),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.lineGlass, space: 1, thickness: 1),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        minVerticalPadding: AppSpacing.sm,
        titleTextStyle: AppTextStyles.label.copyWith(color: AppColors.textLight),
        subtitleTextStyle: AppTextStyles.caption.copyWith(color: AppColors.muted),
        iconColor: AppColors.textLight,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0x0AFFFFFF),
        selectedColor: Colors.white,
        disabledColor: AppColors.tile,
        side: const BorderSide(color: AppColors.lineGlass),
        labelStyle: AppTextStyles.label.copyWith(color: const Color(0xFFCFD2D8), fontWeight: FontWeight.w600),
        secondaryLabelStyle: AppTextStyles.label.copyWith(color: Colors.black, fontWeight: FontWeight.w700),
        checkmarkColor: Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        shape: pill,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: Colors.white, linearTrackColor: Color(0x12FFFFFF), circularTrackColor: Colors.transparent),
      extensions: const [AppPalette.dark],
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: const BorderSide(color: AppColors.lineGlass)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xC70E0F12),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        indicatorColor: Colors.transparent,
        height: 66,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(size: 23, color: selected ? Colors.white : const Color(0xFF7C818A));
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return AppTextStyles.caption.copyWith(fontSize: 11.5, fontWeight: selected ? FontWeight.w700 : FontWeight.w500, color: selected ? Colors.white : const Color(0xFF7C818A));
        }),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Color(0xFF101010),
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: Color(0x40FFFFFF),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28)), side: BorderSide(color: AppColors.lineGlass)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFF101010),
        surfaceTintColor: Colors.transparent,
        titleTextStyle: AppTextStyles.section.copyWith(color: AppColors.textLight, fontWeight: FontWeight.w800),
        contentTextStyle: AppTextStyles.bodyMuted,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: const BorderSide(color: AppColors.lineGlass)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1A1A1A),
        contentTextStyle: AppTextStyles.body.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0x33FFFFFF))),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: Colors.black,
        unselectedLabelColor: const Color(0xFFCFD2D8),
        labelStyle: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700),
        indicator: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(99)),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        tabAlignment: TabAlignment.start,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.black : const Color(0xFF9A9A9A)),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : const Color(0x1FFFFFFF)),
      ),
      textSelectionTheme: const TextSelectionThemeData(cursorColor: Colors.white, selectionColor: Color(0x59FFFFFF)),
    );
  }

  static OutlineInputBorder _border(Color color, {double width = 1}) {
    return OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: color, width: width));
  }
}
