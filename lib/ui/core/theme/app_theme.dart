// lib/ui/core/theme/app_theme.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_tokens.dart';

abstract final class AppTheme {
  static ThemeData build() {
    final sans = GoogleFonts.ibmPlexSansTextTheme();

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColor.ground,
      colorScheme: const ColorScheme.light(
        primary: AppColor.primary,
        onPrimary: AppColor.primaryOn,
        surface: AppColor.surface,
        onSurface: AppColor.ink,
        error: AppColor.danger,
      ),
      textTheme: sans
          .apply(bodyColor: AppColor.ink, displayColor: AppColor.ink)
          .copyWith(
            // Título de pantalla
            titleLarge: GoogleFonts.ibmPlexSans(
              fontSize: 19,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.19,
              color: AppColor.ink,
            ),
            // Texto general de la interfaz
            bodyMedium: GoogleFonts.ibmPlexSans(
              fontSize: 13,
              color: AppColor.ink,
            ),
            // Celdas de tabla
            bodySmall: GoogleFonts.ibmPlexSans(
              fontSize: 12.5,
              color: AppColor.ink,
            ),
            // Etiqueta de campo: 10 px, versalita, con tracking
            labelSmall: GoogleFonts.ibmPlexSans(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.9,
              color: AppColor.inkFaint,
            ),
          ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: AppColor.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        border: _fieldBorder(AppColor.lineField),
        enabledBorder: _fieldBorder(AppColor.lineField),
        focusedBorder: _fieldBorder(AppColor.primary),
        disabledBorder: _fieldBorder(AppColor.line),
      ),
      cardTheme: CardThemeData(
        color: AppColor.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: AppColor.line),
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColor.lineSoft,
        space: 1,
        thickness: 1,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColor.primary,
          foregroundColor: AppColor.primaryOn,
          minimumSize: const Size(0, AppSize.buttonHeight),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          textStyle: GoogleFonts.ibmPlexSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColor.ink,
          backgroundColor: AppColor.surface,
          side: const BorderSide(color: AppColor.lineField),
          minimumSize: const Size(0, AppSize.buttonHeight),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          textStyle: GoogleFonts.ibmPlexSans(fontSize: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
        ),
      ),
    );
  }

  static OutlineInputBorder _fieldBorder(Color c) => OutlineInputBorder(
    borderSide: BorderSide(color: c),
    borderRadius: BorderRadius.circular(AppRadius.field),
  );

  /// Estilo obligatorio para importes, cantidades y códigos.
  static TextStyle mono({
    double size = 13,
    FontWeight weight = FontWeight.w400,
    Color color = AppColor.ink,
  }) => GoogleFonts.ibmPlexMono(
    fontSize: size,
    fontWeight: weight,
    color: color,
    fontFeatures: AppType.tabular,
  );

  /// Marca y titulares grandes.
  static TextStyle serif({double size = 26, Color color = AppColor.ink}) =>
      GoogleFonts.instrumentSerif(fontSize: size, color: color, height: 1.0);
}
