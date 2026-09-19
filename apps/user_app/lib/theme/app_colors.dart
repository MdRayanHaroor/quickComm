import 'package:flutter/material.dart';

/// QuickComm Brand Color Palette — Maroon/Burgundy Edition
class AppColors {
  AppColors._();

  // ── Primary Brand ──────────────────────────────────────────────
  static const Color primary = Color(0xFF8B1A2B);       // Deep maroon
  static const Color primaryLight = Color(0xFFC1273A);  // Vivid burgundy (accent)
  static const Color primaryDark = Color(0xFF5C0F1C);   // Darkest wine
  static const Color primarySurface = Color(0xFFFDF8F5); // Warm cream

  // ── Background Layers ──────────────────────────────────────────
  static const Color background = Color(0xFFFFFFFF);    // Pure full white
  static const Color surface = Color(0xFFFFFFFF);       // Pure card white
  static const Color surfaceVariant = Color(0xFFF5F5F7); // Subtle neutral tint for search/inputs

  // ── Text ───────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF1A1A1A);   // Near-black
  static const Color textSecondary = Color(0xFF6B6B6B); // Muted grey
  static const Color textMuted = Color(0xFFAAAAAA);     // Light placeholder

  // ── Semantic ───────────────────────────────────────────────────
  static const Color success = Color(0xFF1BA672);        // Blinkit green (for in-stock)
  static const Color successLight = Color(0xFFE8F7F1);
  static const Color error = Color(0xFFD32F2F);
  static const Color errorLight = Color(0xFFFFEBEE);
  static const Color warning = Color(0xFFF57C00);
  static const Color warningLight = Color(0xFFFFF3E0);
  static const Color info = Color(0xFF1565C0);

  // ── Dividers & Borders ─────────────────────────────────────────
  static const Color divider = Color(0xFFEDEDED);
  static const Color border = Color(0xFFE0D9D8);
  static const Color borderFocus = Color(0xFF8B1A2B);

  // ── Discount & Promo ───────────────────────────────────────────
  static const Color discountBadge = Color(0xFF1BA672);
  static const Color discountText = Color(0xFFFFFFFF);
  static const Color strikeMrp = Color(0xFFAAAAAA);

  // ── Bottom Nav ─────────────────────────────────────────────────
  static const Color navBackground = Color(0xFFFFFFFF);
  static const Color navSelected = Color(0xFF8B1A2B);
  static const Color navUnselected = Color(0xFFAAAAAA);

  // ── Shimmer ────────────────────────────────────────────────────
  static const Color shimmerBase = Color(0xFFEAE4E2);
  static const Color shimmerHighlight = Color(0xFFF5F0EE);

  // ── Shadow ─────────────────────────────────────────────────────
  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: const Color(0xFF8B1A2B).withValues(alpha: 0.06),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> elevatedShadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.10),
      blurRadius: 20,
      offset: const Offset(0, 6),
    ),
  ];
}
