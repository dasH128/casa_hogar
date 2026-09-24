// lib/ui/widgets/status_pill.dart

import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Tono de color de un [StatusPill]. El color y el fondo salen del
/// par correspondiente en [AppColor] (p. ej. [AppStatusTone.warn] usa
/// `AppColor.warn` / `AppColor.warnSoft`).
enum AppStatusTone { neutral, info, warn, primary, danger }

/// Píldora de estado de 10.5 px, versalita, radio 3. El mapa de
/// colores por estado de documento sale de `docs/ui-spec.md`.
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, required this.tone});

  /// Mapea `estado_documento` (ver `001_fundamentos.sql`) al texto y
  /// tono documentados en la tabla de `docs/ui-spec.md`. `ENVIANDO` se
  /// muestra como "Pendiente de envío": es el estado en cola hacia el
  /// PSE/OSE.
  factory StatusPill.estadoDocumento(String estado) {
    switch (estado) {
      case 'BORRADOR':
        return const StatusPill(label: 'Borrador', tone: AppStatusTone.neutral);
      case 'EMITIDO':
        return const StatusPill(label: 'Emitido', tone: AppStatusTone.info);
      case 'ENVIANDO':
        return const StatusPill(
          label: 'Pendiente de envío',
          tone: AppStatusTone.warn,
        );
      case 'ACEPTADO':
        return const StatusPill(label: 'Aceptado', tone: AppStatusTone.primary);
      case 'OBSERVADO':
        return const StatusPill(label: 'Observado', tone: AppStatusTone.warn);
      case 'RECHAZADO':
        return const StatusPill(label: 'Rechazado', tone: AppStatusTone.danger);
      case 'ANULADO':
        return const StatusPill(label: 'Anulado', tone: AppStatusTone.neutral);
      default:
        return StatusPill(label: estado, tone: AppStatusTone.neutral);
    }
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
