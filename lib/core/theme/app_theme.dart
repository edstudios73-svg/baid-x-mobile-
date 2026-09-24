import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
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
        indicatorColor: AppColors.white,
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
      dividerTheme: const DividerThemeData(color: AppColors.line, space: 1),
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
      dividerTheme: const DividerThemeData(color: AppColors.darkLine, space: 1),
    );
  }

  static OutlineInputBorder _border(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}
