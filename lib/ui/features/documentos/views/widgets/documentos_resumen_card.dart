// lib/ui/features/documentos/views/widgets/documentos_resumen_card.dart

import 'package:flutter/material.dart';

import '../../../../../domain/models/documento_models.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_tokens.dart';

/// Cuatro tarjetas de resumen en grid de 4 columnas iguales (ver
/// `design/artboards/Documentos.dc.html`). Mientras [resumen] carga,
/// los contadores muestran una raya.
class DocumentosResumenCard extends StatelessWidget {
  const DocumentosResumenCard({super.key, required this.resumen});

  final ResumenDocumentos? resumen;

  @override
  Widget build(BuildContext context) {
    final tarjetas = [
      _Tarjeta(
        titulo: 'Aceptados hoy',
        child: _Contador(valor: resumen?.aceptadosHoy),
      ),
      _Tarjeta(
        titulo: 'Pendientes de envío',
        color: AppColor.warn,
        borde: AppColor.warnBorder,
        child: _Contador(valor: resumen?.pendientesEnvio, color: AppColor.warn),
      ),
      _Tarjeta(
        titulo: 'Rechazados',
        color: AppColor.danger,
        borde: AppColor.dangerBorder,
        child: _Contador(valor: resumen?.rechazados, color: AppColor.danger),
      ),
      const _Tarjeta(
        titulo: 'Plazo legal de envío',
        child: Padding(
          padding: EdgeInsets.only(top: 3),
          child: Text(
            '3 días calendario desde la emisión',
            style: TextStyle(color: AppColor.inkMuted, height: 1.4),
          ),
        ),
      ),
    ];

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < tarjetas.length; i++) ...[
            if (i > 0) const SizedBox(width: AppSpace.gridGap),
            Expanded(child: tarjetas[i]),
          ],
        ],
      ),
    );
  }
}

class _Tarjeta extends StatelessWidget {
  const _Tarjeta({
    required this.titulo,
    required this.child,
    this.color = AppColor.inkFaint,
    this.borde = AppColor.line,
  });

  final String titulo;
  final Widget child;
  final Color color;
  final Color borde;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColor.surface,
        border: Border.all(color: borde),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.summaryCardPaddingH,
          vertical: AppSpace.summaryCardPaddingV,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titulo.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: color),
            ),
            const SizedBox(height: AppSpace.xs),
            child,
          ],
        ),
      ),
    );
  }
}

class _Contador extends StatelessWidget {
  const _Contador({required this.valor, this.color = AppColor.ink});

  final int? valor;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      valor?.toString() ?? '—',
      style: AppTheme.mono(size: 26, weight: FontWeight.w600, color: color),
    );
  }
}
