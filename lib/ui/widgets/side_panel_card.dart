// lib/ui/widgets/side_panel_card.dart

import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import 'field_label.dart';

/// Tono de fondo de un [SidePanelCard]. `warn` es el aviso de crédito
/// del panel lateral de venta.
enum SidePanelTone { neutral, warn }

/// Tarjeta del panel lateral de 296 px: resumen de totales, stock o
/// avisos. Aporta el borde, el radio y el padding comunes a las tres;
/// el contenido es composición de cada pantalla.
class SidePanelCard extends StatelessWidget {
  const SidePanelCard({
    super.key,
    this.title,
    required this.child,
    this.tone = SidePanelTone.neutral,
  });

  final String? title;
  final Widget child;
  final SidePanelTone tone;

  @override
  Widget build(BuildContext context) {
    final background = tone == SidePanelTone.warn ? AppColor.warnBg : AppColor.surface;
    final border = tone == SidePanelTone.warn ? AppColor.warnBorder : AppColor.line;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: AppSpace.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title != null) ...[
              FieldLabel(title!),
              const SizedBox(height: 9),
            ],
            child,
          ],
        ),
      ),
    );
  }
}
