import 'package:flutter/material.dart';

/// Cotopole design tokens.
///
/// Derived from the concept design in `cotople-mobile-app/designs`
/// (deep-navy canvas, electric blue → violet gradients, teal accents for the
/// selfie flow) and the brand logo (blue "co", amber "tople").
abstract final class AppColors {
  // Canvas
  static const background = Color(0xFF060918);
  static const backgroundAlt = Color(0xFF0A1028);
  static const surface = Color(0xFF0E1533);
  static const surfaceHigh = Color(0xFF141D45);
  static const border = Color(0xFF1E2A5A);
  static const borderBright = Color(0xFF2D3F86);

  // Brand
  static const brandBlue = Color(0xFF1E73BE);
  static const brandAmber = Color(0xFFFFB020);

  // Accents
  static const primary = Color(0xFF3D7BFF);
  static const violet = Color(0xFF8B5CF6);
  static const cyan = Color(0xFF22D3EE);
  static const teal = Color(0xFF2DD4BF);
  static const success = Color(0xFF3DDC84);
  static const warning = Color(0xFFFFB020);
  static const danger = Color(0xFFFF6259);
  static const hot = Color(0xFFFF6B4A);

  // Text
  static const textPrimary = Color(0xFFF4F6FF);
  static const textSecondary = Color(0xFFB4BCDD);
  static const textMuted = Color(0xFF7A84AD);

  static const primaryGradient = LinearGradient(
    colors: [Color(0xFF2F6BFF), Color(0xFF7C4DFF)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const tealGradient = LinearGradient(
    colors: [Color(0xFF0EA5A4), Color(0xFF22D3EE)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const amberGradient = LinearGradient(
    colors: [Color(0xFFFFB020), Color(0xFFFF7A45)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const cardGradient = LinearGradient(
    colors: [Color(0xCC111A40), Color(0xB30A1030)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Deterministic avatar gradient from a seed string (e.g. a contact name).
  static LinearGradient avatarGradient(String seed) {
    const palettes = [
      [Color(0xFF2F6BFF), Color(0xFF7C4DFF)],
      [Color(0xFF0EA5A4), Color(0xFF22D3EE)],
      [Color(0xFFFF7A45), Color(0xFFFFB020)],
      [Color(0xFFE0457B), Color(0xFF8B5CF6)],
      [Color(0xFF16A34A), Color(0xFF2DD4BF)],
      [Color(0xFF6366F1), Color(0xFF22D3EE)],
    ];
    final hash = seed.codeUnits.fold<int>(0, (a, b) => (a * 31 + b) & 0x7fffffff);
    final p = palettes[hash % palettes.length];
    return LinearGradient(colors: p, begin: Alignment.topLeft, end: Alignment.bottomRight);
  }
}

abstract final class AppRadii {
  static const sm = 10.0;
  static const md = 14.0;
  static const lg = 20.0;
  static const xl = 26.0;
  static const pill = 999.0;
}

abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 28.0;
  static const page = 20.0;
}
