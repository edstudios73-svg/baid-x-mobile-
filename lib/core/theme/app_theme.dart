import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_palette.dart';
import 'app_spacing.dart';
import 'app_text_styles.dart';

abstract final class AppTheme {
  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.orange,
      primary: AppColors.ink,
      onPrimary: AppColors.white,
      secondary: AppColors.orange,
      onSecondary: AppColors.ink,
      surface: AppColors.surface,
      error: AppColors.danger,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.canvas,
      splashFactory: NoSplash.splashFactory,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.canvas,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppTextStyles.title,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        hintStyle: AppTextStyles.bodyMuted,
        labelStyle: AppTextStyles.label,
        border: _border(AppColors.line),
        enabledBorder: _border(AppColors.line),
        focusedBorder: _border(AppColors.ink, width: 1.6),
        errorBorder: _border(AppColors.danger),
        focusedErrorBorder: _border(AppColors.danger, width: 1.6),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.orange,
          foregroundColor: AppColors.ink,
          overlayColor: AppColors.orangePressed,
          disabledBackgroundColor: AppColors.line,
          disabledForegroundColor: AppColors.textMuted,
          minimumSize: const Size.fromHeight(AppSpacing.buttonHeight),
          textStyle: AppTextStyles.button,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          minimumSize: const Size.fromHeight(AppSpacing.buttonHeight),
          textStyle: AppTextStyles.button,
          side: const BorderSide(color: AppColors.ink),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.blue,
          textStyle: AppTextStyles.label,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.white,
        elevation: 0,
        surfaceTintColor: AppColors.white,
        shadowColor: AppColors.white,
        indicatorColor: AppColors.yellow,
        height: 72,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 24,
            color: selected ? AppColors.ink : AppColors.textMuted,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          if (selected) return AppTextStyles.label;
          return AppTextStyles.label.copyWith(
            fontWeight: FontWeight.w500,
            color: AppColors.textMuted,
          );
        }),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.line, space: 1, thickness: 1),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        minVerticalPadding: AppSpacing.sm,
        titleTextStyle: AppTextStyles.label,
        subtitleTextStyle: AppTextStyles.caption,
        iconColor: AppColors.ink,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.yellow,
        disabledColor: AppColors.line,
        side: const BorderSide(color: AppColors.line),
        labelStyle: AppTextStyles.caption.copyWith(color: AppColors.text, fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusSm)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.ink, linearTrackColor: AppColors.line),
      extensions: const [AppPalette.light],
      cardTheme: _card(AppColors.surface, AppColors.line),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusLg))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: AppTextStyles.section,
        contentTextStyle: AppTextStyles.bodyMuted,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusLg)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        contentTextStyle: AppTextStyles.body.copyWith(color: AppColors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: AppColors.ink,
        unselectedLabelColor: AppColors.textMuted,
        labelStyle: AppTextStyles.label,
        indicatorColor: AppColors.yellow,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: AppColors.line,
      ),
      textSelectionTheme: const TextSelectionThemeData(cursorColor: AppColors.ink),
    );
  }

  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.orange,
      brightness: Brightness.dark,
      primary: AppColors.orange,
      onPrimary: AppColors.ink,
      secondary: AppColors.orange,
      onSecondary: AppColors.ink,
      surface: AppColors.darkSurface,
      onSurface: AppColors.white,
      error: AppColors.darkDanger,
      onError: AppColors.ink,
    ).copyWith(outline: AppColors.darkLine);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.darkCanvas,
      splashFactory: NoSplash.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.darkCanvas,
        foregroundColor: AppColors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppTextStyles.title.copyWith(color: AppColors.white),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkSurface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        hintStyle: AppTextStyles.bodyMuted.copyWith(color: AppColors.darkTextMuted),
        labelStyle: AppTextStyles.label.copyWith(color: AppColors.white),
        border: _border(AppColors.darkLine),
        enabledBorder: _border(AppColors.darkLine),
        focusedBorder: _border(AppColors.white, width: 1.6),
        errorBorder: _border(AppColors.darkDanger),
        focusedErrorBorder: _border(AppColors.darkDanger, width: 1.6),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.orange,
          foregroundColor: AppColors.ink,
          overlayColor: AppColors.orangePressed,
          disabledBackgroundColor: AppColors.darkLine,
          disabledForegroundColor: AppColors.darkTextMuted,
          minimumSize: const Size.fromHeight(AppSpacing.buttonHeight),
          textStyle: AppTextStyles.button,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.white,
          minimumSize: const Size.fromHeight(AppSpacing.buttonHeight),
          textStyle: AppTextStyles.button,
          side: const BorderSide(color: AppColors.white),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.darkBlue,
          textStyle: AppTextStyles.label,
        ),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.darkLine, space: 1, thickness: 1),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        minVerticalPadding: AppSpacing.sm,
        titleTextStyle: AppTextStyles.label.copyWith(color: AppColors.white),
        subtitleTextStyle: AppTextStyles.caption.copyWith(color: AppColors.darkTextMuted),
        iconColor: AppColors.white,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.darkSurface,
        selectedColor: AppColors.yellow,
        side: const BorderSide(color: AppColors.darkLine),
        labelStyle: AppTextStyles.caption.copyWith(color: AppColors.white, fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusSm)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.yellow, linearTrackColor: AppColors.darkLine),
      extensions: const [AppPalette.dark],
      cardTheme: _card(AppColors.darkSurface, AppColors.darkLine),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.darkSurface,
        elevation: 0,
        surfaceTintColor: AppColors.darkSurface,
        indicatorColor: AppColors.yellow,
        height: 72,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(size: 24, color: selected ? AppColors.ink : AppColors.darkTextMuted);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return AppTextStyles.label.copyWith(
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? AppColors.white : AppColors.darkTextMuted,
          );
        }),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.darkSurface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusLg))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.darkSurface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: AppTextStyles.section.copyWith(color: AppColors.white),
        contentTextStyle: AppTextStyles.bodyMuted.copyWith(color: AppColors.darkTextMuted),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusLg)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.white,
        contentTextStyle: AppTextStyles.body.copyWith(color: AppColors.ink),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: AppColors.white,
        unselectedLabelColor: AppColors.darkTextMuted,
        labelStyle: AppTextStyles.label,
        indicatorColor: AppColors.yellow,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: AppColors.darkLine,
      ),
      textSelectionTheme: const TextSelectionThemeData(cursorColor: AppColors.yellow),
    );
  }

  static CardThemeData _card(Color fill, Color line) {
    return CardThemeData(
      color: fill,
      elevation: 0,
      margin: EdgeInsets.zero,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        side: BorderSide(color: line),
      ),
    );
  }

  static OutlineInputBorder _border(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}
