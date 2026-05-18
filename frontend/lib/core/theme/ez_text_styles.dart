import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'ez_colors.dart';

class EzTextStyles {
  EzTextStyles._();

  // Display (Bricolage Grotesque / Plus Jakarta Sans fallback)
  static TextStyle display(
      {double size = 28,
      FontWeight weight = FontWeight.w600,
      Color color = EzColors.ink}) {
    return GoogleFonts.plusJakartaSans(
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: -0.5,
      height: 1.15,
    );
  }

  // Body / UI (Plus Jakarta Sans)
  static TextStyle body(
      {double size = 14,
      FontWeight weight = FontWeight.w500,
      Color color = EzColors.ink}) {
    return GoogleFonts.plusJakartaSans(
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: -0.15,
    );
  }

  // Label / Bold
  static TextStyle label(
      {double size = 12,
      FontWeight weight = FontWeight.w700,
      Color color = EzColors.ink}) {
    return GoogleFonts.plusJakartaSans(
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: -0.1,
    );
  }

  // Mono (JetBrains Mono)
  static TextStyle mono(
      {double size = 11,
      FontWeight weight = FontWeight.w700,
      Color color = EzColors.ink}) {
    return GoogleFonts.jetBrainsMono(
      fontSize: size,
      fontWeight: weight,
      color: color,
    );
  }

  // Caption
  static TextStyle caption(
      {double size = 10.5, Color color = EzColors.muted}) {
    return GoogleFonts.plusJakartaSans(
      fontSize: size,
      fontWeight: FontWeight.w600,
      color: color,
      letterSpacing: -0.1,
    );
  }
}
