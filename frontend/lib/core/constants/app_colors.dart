import 'package:flutter/material.dart';
import 'package:digital_wallet_app/core/theme/app_theme_controller.dart';

/// Shared NaNa Wallet design tokens.
///
/// Keep the legacy names below as aliases while feature screens are migrated
/// to semantic tokens, so this palette can be rolled out safely across routes.
class AppColors {
  // Core surfaces
  static const Color midnightBlue = Color(0xFF0B141B);
  static const Color royalBlue = Color(0xFF35C9A5);
  static const Color neonPink = Color(0xFFA3E635);

  // Semantic brand tokens
  static const Color brandMint = Color(0xFF35C9A5);
  static const Color brandMintBright = Color(0xFF58E0BC);
  static const Color accentLime = Color(0xFFA3E635);
  static const Color surface = Color(0xFF121F28);
  static const Color surfaceRaised = Color(0xFF172731);
  static const Color textPrimary = Color(0xFFF5F8F7);
  static const Color textSecondary = Color(0xFFA6B5B8);

  /// Adapts legacy hard-coded screen colors while those screens migrate to
  /// fully semantic ThemeData colors.
  static bool get isDark => AppThemeController.instance.isDark;
  static Color get themeText =>
      isDark ? const Color(0xFFF5F8F7) : const Color(0xFF17231F);
  static Color get adaptiveSurface =>
      isDark ? const Color(0xFF16252B) : const Color(0xFFFFFFFF);
  static Color get adaptiveSurfaceAlt =>
      isDark ? const Color(0xFF0F1C20) : const Color(0xFFF1F5F3);

  /// Keeps screens that use legacy palette values listening to Theme updates.
  static Brightness dependOnTheme(BuildContext context) =>
      Theme.of(context).brightness;

  static const Color glassWhite = Color(0x1AFFFFFF);
  static const Color glassBorder = Color(0x33FFFFFF);
}
