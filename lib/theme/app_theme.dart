// lib/theme/app_theme.dart
// Visual constants for the modern dark Todo UI inspired by the Figma design.

import 'package:flutter/material.dart';

class AppColors {
  // ── Backgrounds ────────────────────────────────────────────────────────────
  static const Color bgDeep    = Color(0xFF0D0D1F);
  static const Color bgMid     = Color(0xFF12142E);
  static const Color bgSurface = Color(0xFF181A35); // cards / sheets

  // ── Accent gradients ───────────────────────────────────────────────────────
  static const Color accentPurple = Color(0xFF8C40FF);
  static const Color accentBlue   = Color(0xFF268CFF);
  static const Color accentCyan   = Color(0xFF0DB9E6);
  static const Color accentGreen  = Color(0xFF26D98C);
  static const Color accentOrange = Color(0xFFFFA626);
  static const Color accentRed    = Color(0xFFFF5959);

  // ── Text ───────────────────────────────────────────────────────────────────
  static const Color textPrimary   = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF99A6D9);
  static const Color textMuted     = Color(0xFF5A6490);

  // ── Borders / overlays ────────────────────────────────────────────────────
  static const Color borderSubtle = Color(0x1AFFFFFF); // 10 % white
  static const Color borderCard   = Color(0x1FFFFFFF); // 12 % white
  static const Color overlay08    = Color(0x14FFFFFF); // 8  % white
  static const Color overlay05    = Color(0x0DFFFFFF); // 5  % white

  // ── Priority colours ──────────────────────────────────────────────────────
  static const Color priorityHigh   = accentRed;
  static const Color priorityMedium = accentOrange;
  static const Color priorityLow    = accentGreen;

  // ── Nav bar ───────────────────────────────────────────────────────────────
  static const Color navBg      = Color(0xF20F0F24); // 95 % opaque
  static const Color navActive  = accentPurple;
  static const Color navInactive = Color(0xFF6673A6);
}

class AppGradients {
  // Primary CTA (FAB, active chips, buttons)
  static const LinearGradient primary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.accentPurple, AppColors.accentBlue],
  );

  // Background gradient for the whole screen
  static const LinearGradient screenBg = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [AppColors.bgDeep, AppColors.bgMid],
  );

  // AppBar / header gradient
  static const LinearGradient header = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1A1035), Color(0xFF0D0D2E)],
  );

  // Green completion gradient (checkbox ticked)
  static const LinearGradient done = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.accentGreen, Color(0xFF0DA673)],
  );
}

class AppShadows {
  // Glow shadow for the FAB
  static List<BoxShadow> fabGlow = [
    BoxShadow(
      color: AppColors.accentPurple.withOpacity(0.55),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];

  // Subtle card elevation
  static List<BoxShadow> card = [
    BoxShadow(
      color: Colors.black.withOpacity(0.25),
      blurRadius: 8,
      offset: const Offset(0, 4),
    ),
  ];
}

class AppRadius {
  static const double card   = 20.0;
  static const double chip   = 16.0;
  static const double button = 14.0;
  static const double small  = 8.0;
  static const double badge  = 10.0;
}

class AppTextStyles {
  static const TextStyle screenTitle = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  static const TextStyle sectionLabel = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const TextStyle taskTitle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const TextStyle taskTitleDone = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textMuted,
    decoration: TextDecoration.lineThrough,
    decorationColor: AppColors.textMuted,
  );

  static const TextStyle labelChip = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle timeText = TextStyle(
    fontSize: 11,
    color: AppColors.textMuted,
  );

  static const TextStyle statValue = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  static const TextStyle statLabel = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );

  static const TextStyle greeting = TextStyle(
    fontSize: 14,
    color: AppColors.textSecondary,
  );

  static const TextStyle filterChipActive = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const TextStyle filterChipInactive = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );
}