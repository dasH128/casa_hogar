// lib/ui/screens/ventas/widgets/venta_stock_card.dart

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import '../../../../state/venta_draft_controller.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/app_tokens.dart';
import '../../../widgets/side_panel_card.dart';

/// Disponibilidad de la línea con el foco, leída de `stock_actual`
/// (ver `venta_reference_providers.dart`): nunca sumada en Dart.
class VentaStockCard extends StatelessWidget {
  const VentaStockCard({super.key, required this.state});

  final VentaDraftState state;

  @override
  Widget build(BuildContext context) {
    final linea = state.lineaEnfocada;
    final disponible = state.stockDisponible ?? Decimal.zero;
    if (linea == null) return const SizedBox.shrink();

    final estaLinea = linea.cantidadBase;
    final total = disponible == Decimal.zero ? Decimal.one : disponible;
    final proporcion = (estaLinea / total).toDouble().clamp(0, 1);

    return SidePanelCard(
      title: 'Stock · línea ${linea.numeroLinea}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              const Text(
                'Disponible',
                style: TextStyle(fontSize: 12, color: AppColor.inkMuted),
              ),
              Text(
                '${disponible.toStringAsFixed(0)} ${linea.unidadMedida}',
                style: AppTheme.mono(size: 16, weight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              const Text(
                'Esta línea',
                style: TextStyle(fontSize: 12, color: AppColor.inkMuted),
              ),
              Text(
                '${estaLinea.toStringAsFixed(0)} ${linea.unidadMedida} · '
                '${linea.cantidad.toStringAsFixed(0)} ${linea.presentacionNombre}',
                style: AppTheme.mono(size: 13, color: AppColor.inkMuted),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 11),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: SizedBox(
                height: AppSize.stockBarHeight,
                child: Row(
                  children: [
                    Expanded(
                      flex: (proporcion * 1000).round().clamp(0, 1000),
                      child: const ColoredBox(color: AppColor.primary),
                    ),
                    Expanded(
                      flex: 1000 - (proporcion * 1000).round().clamp(0, 1000),
                      child: const ColoredBox(color: AppColor.neutralSoft),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
