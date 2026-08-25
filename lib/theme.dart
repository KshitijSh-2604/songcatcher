import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Doodle Pulse Color Palette
  static const primaryInkBlue = Color(0xFF0001BB);
  static const primaryBlueContainer = Color(0xFF0000FF);
  static const markerGreen = Color(0xFF026E00);
  static const secondaryContainer = Color(0xFF00F900); // Marker Green bright
  static const crayonRed = Color(0xFF720100);
  static const warningYellow = Color(0xFFFFFF00);
  static const doodleBlack = Color(0xFF000000);
  static const paperGray = Color(0xFFF0F0F0);
  static const surfaceWhite = Color(0xFFFFFFFF);

  // Dark Mode Palette - Enhanced
  static const darkBg = Color(0xFF0A0A0A);
  static const darkSurface = Color(0xFF141414);
  static const darkOutline = Color(0xFF333333); // Subtle outline for neubrutalist
  static const darkPrimary = Color(0xFF6366F1); // Indigo-ish
  static const darkText = Color(0xFFE5E7EB);
  static const darkTextDim = Color(0xFF9CA3AF);

  static const double borderThick = 3.0;

  static ThemeData skribbl() {
    final base = ThemeData.light();
    return _buildTheme(base, Brightness.light);
  }

  static ThemeData skribblDark() {
    final base = ThemeData.dark();
    return _buildTheme(base, Brightness.dark);
  }

  static ThemeData _buildTheme(ThemeData base, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final primary = isDark ? darkPrimary : primaryInkBlue;
    final bg = isDark ? darkBg : paperGray;
    final surface = isDark ? darkSurface : surfaceWhite;
    final outline = isDark ? Colors.white : doodleBlack;
    final text = isDark ? darkText : doodleBlack;
    final textDim = isDark ? darkTextDim : Colors.black54;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      primaryColor: primary,
      scaffoldBackgroundColor: bg,
      cardColor: surface,
      dividerColor: outline,
      hintColor: isDark ? Colors.white24 : Colors.black26,
      
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: brightness,
        primary: primary,
        onPrimary: isDark ? Colors.white : surfaceWhite,
        secondary: isDark ? const Color(0xFF10B981) : markerGreen,
        onSecondary: isDark ? Colors.white : surfaceWhite,
        surface: surface,
        background: bg,
        outline: outline,
        onSurface: text,
        onBackground: text,
        error: isDark ? const Color(0xFFEF4444) : crayonRed,
      ),

      textTheme: GoogleFonts.plusJakartaSansTextTheme(
        base.textTheme.apply(bodyColor: text, displayColor: text),
      ).copyWith(
        displayLarge: GoogleFonts.bricolageGrotesque(fontWeight: FontWeight.w900, fontSize: 64, color: text),
        displayMedium: GoogleFonts.bricolageGrotesque(fontWeight: FontWeight.w900, fontSize: 48, color: text),
        displaySmall: GoogleFonts.bricolageGrotesque(fontWeight: FontWeight.w900, fontSize: 32, color: text),
        headlineLarge: GoogleFonts.bricolageGrotesque(fontWeight: FontWeight.w800, fontSize: 32, color: text),
        headlineMedium: GoogleFonts.bricolageGrotesque(fontWeight: FontWeight.w800, fontSize: 24, color: text),
        titleLarge: GoogleFonts.bricolageGrotesque(fontWeight: FontWeight.w800, fontSize: 20, color: text),
        bodyLarge: TextStyle(color: text, fontWeight: FontWeight.w600),
        bodyMedium: TextStyle(color: textDim, fontWeight: FontWeight.w500),
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: text, size: 24),
        titleTextStyle: TextStyle(
          fontFamily: 'Bricolage Grotesque',
          fontWeight: FontWeight.w900,
          fontSize: 24,
          color: isDark ? darkPrimary : primary,
        ),
        shape: Border(bottom: BorderSide(color: outline, width: borderThick)),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: isDark ? Colors.white : surfaceWhite,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
            side: BorderSide(color: outline, width: borderThick),
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? Colors.white.withOpacity(0.03) : surfaceWhite,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: outline, width: borderThick),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: outline, width: borderThick),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: primary, width: borderThick),
        ),
        labelStyle: TextStyle(color: text, fontWeight: FontWeight.w600),
        hintStyle: TextStyle(color: textDim),
      ),

      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: BorderSide(color: outline, width: borderThick),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: outline, width: borderThick),
        ),
      ),

      dividerTheme: DividerThemeData(
        color: outline,
        thickness: 2,
      ),
    );
  }
}
