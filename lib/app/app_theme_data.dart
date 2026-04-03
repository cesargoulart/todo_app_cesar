// lib/app/app_theme_data.dart
//
// Define os ThemeData do MaterialApp (dark e light).
// Usa as constantes do app_theme.dart para consistência.

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AppThemeData {
  static ThemeData get dark => ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.bgDeep,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.accentPurple,
          secondary: AppColors.accentBlue,
          surface: AppColors.bgSurface,
          error: AppColors.accentRed,
        ),
        fontFamily: 'Inter',
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.bgDeep,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: AppColors.accentPurple,
        ),
        dialogBackgroundColor: AppColors.bgSurface,
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: AppColors.bgSurface,
        ),
        dividerColor: AppColors.borderSubtle,
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: AppColors.textSecondary),
          bodyLarge: TextStyle(color: AppColors.textPrimary),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.selected)
                  ? AppColors.accentPurple
                  : AppColors.textMuted),
          trackColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.selected)
                  ? AppColors.accentPurple.withOpacity(0.4)
                  : AppColors.overlay08),
        ),
        checkboxTheme: CheckboxThemeData(
          fillColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.selected)
                  ? AppColors.accentPurple
                  : Colors.transparent),
          side: const BorderSide(color: AppColors.textMuted),
        ),
      );

  static ThemeData get light => ThemeData(
        brightness: Brightness.light,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.accentPurple),
        fontFamily: 'Inter',
      );
}