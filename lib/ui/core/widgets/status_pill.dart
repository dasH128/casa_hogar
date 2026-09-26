// lib/ui/core/widgets/status_pill.dart

import 'package:flutter/material.dart';

import '../../../domain/estado_documento.dart';
import '../theme/app_tokens.dart';

/// Tono de color de un [StatusPill]. El color y el fondo salen del
/// par correspondiente en [AppColor] (p. ej. [AppStatusTone.warn] usa
/// `AppColor.warn` / `AppColor.warnSoft`). `neutral` es el borrador y
/// `inactive` lo anulado: difieren en el tono del texto.
enum AppStatusTone { neutral, info, warn, primary, danger, inactive }

/// Píldora de estado de 10.5 px, versalita, radio 3. El mapa de
/// colores por estado de documento sale de `docs/ui-spec.md`.
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, required this.tone});

  /// Mapea `estado_documento` (ver `001_fundamentos.sql`) al texto y
  /// tono documentados en la tabla de `docs/ui-spec.md`. El texto sale
  /// de `domain/estado_documento.dart`, compartido con los filtros.
  factory StatusPill.estadoDocumento(String estado) {
    return StatusPill(
      label: etiquetaEstadoDocumento(estado),
      tone: switch (estado) {
        'EMITIDO' => AppStatusTone.info,
        'ENVIANDO' || 'OBSERVADO' => AppStatusTone.warn,
        'ACEPTADO' => AppStatusTone.primary,
        'RECHAZADO' => AppStatusTone.danger,
        'ANULADO' => AppStatusTone.inactive,
        _ => AppStatusTone.neutral,
      },
    );
  }

  final String label;
  final AppStatusTone tone;

  (Color, Color) _colors() {
    switch (tone) {
      case AppStatusTone.neutral:
        return (AppColor.inkMuted, AppColor.neutralSoft);
      case AppStatusTone.info:
        return (AppColor.info, AppColor.infoSoft);
      case AppStatusTone.warn:
        return (AppColor.warn, AppColor.warnSoft);
      case AppStatusTone.primary:
        return (AppColor.primary, AppColor.primarySoft);
      case AppStatusTone.danger:
        return (AppColor.danger, AppColor.dangerSoft);
      case AppStatusTone.inactive:
        return (AppColor.neutral, AppColor.neutralSoft);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (foreground, background) = _colors();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.525,
            color: foreground,
          ),
        ),
      ),
    );
  }
}
