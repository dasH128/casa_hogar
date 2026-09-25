// lib/ui/core/theme/app_tokens.dart
//
// Tokens extraídos de los mockups del lienzo de diseño.
// Esta es la única fuente de color, espaciado y radio de la aplicación.
// Ningún widget debe escribir un Color(0x...) a mano.

import 'package:flutter/material.dart';

abstract final class AppColor {
  // Fondos
  static const ground = Color(0xFFF6F4EF); // papel cálido, fondo de pantalla
  static const surface = Color(0xFFFFFFFF); // tarjetas y tablas
  static const surfaceAlt = Color(0xFFFAF8F3); // pies de tabla, franjas
  static const tableHeader = Color(0xFFF1EEE5);
  static const rowActive = Color(0xFFFBF6EC); // línea con el cursor
  static const readonly = Color(0xFFF6F4EF); // campo no editable

  // Rail lateral
  static const rail = Color(0xFF1B1A15);
  static const railActive = Color(0xFF33312A);
  static const railText = Color(0xFFCFCABA);
  static const railTextStrong = Color(0xFFFFFFFF);
  static const railTextMuted = Color(0xFF9B9683);
  static const railTextFaint = Color(
    0xFF6E6A5C,
  ); // pie de página del panel de acceso

  // Texto
  static const ink = Color(0xFF14130F);
  static const inkMuted = Color(0xFF4F4C42);
  static const inkFaint = Color(0xFF6B6759); // etiquetas de campo
  static const inkDisabled = Color(0xFF8A8574);

  // Líneas
  static const line = Color(0xFFE3DED1); // borde de tarjeta
  static const lineSoft = Color(0xFFF0EDE3); // separador de fila
  static const lineField = Color(0xFFD3CDBC); // borde de input

  // Acción
  static const primary = Color(0xFF14453C);
  static const primaryOn = Color(0xFFFFFFFF);
  static const primarySoft = Color(0xFFE2EDE7);

  // Estados. Difieren en luminosidad, no solo en tono,
  // para que se distingan sin depender del color.
  static const info = Color(0xFF1B4F82); // emitido, por vencer
  static const infoSoft = Color(0xFFE1EAF3);
  static const warn = Color(0xFF6B4700); // pendiente, aviso
  static const warnSoft = Color(0xFFF7EEDC);
  static const warnBorder = Color(0xFFDCC79A);
  static const warnBg = Color(0xFFF9F1E1);
  static const warnIconStrong = Color(0xFF7A5200); // ícono del aviso de crédito
  static const danger = Color(0xFF8A350C); // rechazado, vencido
  static const dangerSoft = Color(0xFFF7E4DA);
  static const dangerBorder = Color(0xFFE0B5A0);
  static const dangerBorderStrong = Color(
    0xFFA8410F,
  ); // botón "Solicitar autorización"
  static const dangerBg = Color(0xFFFCF3EE);
  static const neutral = Color(0xFF5C5A52); // anulado, inactivo
  static const neutralSoft = Color(0xFFEDEAE0);
}

abstract final class AppSpace {
  static const xs = 5.0;
  static const sm = 8.0;
  static const md = 14.0; // separación entre tarjetas
  static const lg = 18.0; // padding vertical del área de contenido
  static const xl = 22.0; // padding horizontal del área de contenido
  static const cardPadding =
      16.0; // interior de una tarjeta (cabecera, totales)
}

abstract final class AppRadius {
  static const field = 4.0;
  static const button = 5.0;
  static const card = 7.0;
  static const pill = 3.0;
  static const authControl = 6.0; // campos y botón del formulario de acceso
}

abstract final class AppSize {
  static const railWidth = 216.0;
  static const railItemHeight = 38.0;
  static const headerHeight = 62.0;
  static const keyBarHeight = 46.0;
  static const fieldHeight = 36.0;
  static const buttonHeight = 36.0;
  static const authFieldHeight = 44.0; // formularios sin densidad
  static const authButtonHeight = 46.0;
  static const authPanelWidth =
      560.0; // panel izquierdo de la pantalla de acceso
  static const authFormWidth = 388.0; // formulario de acceso, centrado
  static const asidePanelWidth = 296.0;
  static const tableRowHeight = 36.0;
  static const compactRowHeight = 30.0; // grilla de compras
  static const lineSearchFieldHeight =
      32.0; // buscador de producto, última fila de la grilla
  static const warningIconSize = 16.0; // aviso de crédito
  static const stockBarHeight =
      6.0; // barra de disponibilidad del panel de stock
  static const creditBarHeight =
      8.0; // barra usado/límite de la ficha de cliente
  static const clienteAsideWidth =
      286.0; // panel lateral de la ficha de cliente
  static const inlineNoticeIconSize =
      14.0; // aviso en línea dentro de un grid de campos
  static const listSearchFieldWidth = 420.0; // buscador sobre un listado
}

/// Tipografía. Requiere el paquete google_fonts.
///
/// - Instrument Serif: solo la marca y titulares grandes.
/// - IBM Plex Sans: toda la interfaz.
/// - IBM Plex Mono: importes, cantidades, códigos, fechas y números
///   de documento. Siempre con cifras tabulares, o las columnas bailan.
abstract final class AppType {
  static const sans = 'IBMPlexSans';
  static const mono = 'IBMPlexMono';
  static const serif = 'InstrumentSerif';

  /// Aplícalo a cualquier Text que muestre un número en una columna.
  static const tabular = <FontFeature>[FontFeature.tabularFigures()];
}
