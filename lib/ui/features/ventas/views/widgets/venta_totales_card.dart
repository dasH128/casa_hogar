// lib/ui/features/ventas/views/widgets/venta_totales_card.dart

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import '../../../../../domain/models/venta_models.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/amount_text.dart';
import '../../../../core/widgets/side_panel_card.dart';

/// Panel de totales del documento: siempre los que devolvió el
/// servidor (`app.recalcular_totales`), nunca una suma hecha en Dart.
class VentaTotalesCard extends StatelessWidget {
  const VentaTotalesCard({super.key, required this.documento});

  final DocumentoVentaDraft documento;

  @override
  Widget build(BuildContext context) {
    return SidePanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TotalRow(label: 'Valor de venta', value: documento.valorVenta),
          _TotalRow(
            label: 'Descuentos',
            value: documento.totalDescuento,
            negative: true,
          ),
          _TotalRow(label: 'IGV', value: documento.totalIgv),
          _TotalRow(
            label: 'Percepción',
            value: documento.totalPercepcion,
            borderBottom: true,
          ),
          Padding(
            padding: const EdgeInsets.only(top: AppSpace.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total a pagar',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                AmountText(
                  documento.importeTotal,
                  currencySymbol: documento.moneda == 'PEN'
                      ? 'S/'
                      : documento.moneda,
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              documento.preciosIncluyenIgv
                  ? 'Precios con IGV incluido'
                  : 'Precios sin IGV',
              style: const TextStyle(fontSize: 11, color: AppColor.inkFaint),
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({
    required this.label,
    required this.value,
    this.negative = false,
    this.borderBottom = false,
  });

  final String label;
  final Decimal value;
  final bool negative;
  final bool borderBottom;

  @override
  Widget build(BuildContext context) {
    final row = Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColor.inkMuted)),
        Row(
          children: [
            if (negative)
              Text('−', style: AppTheme.mono(color: AppColor.inkMuted)),
            AmountText(value, color: AppColor.inkMuted),
          ],
        ),
      ],
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        border: borderBottom
            ? const Border(bottom: BorderSide(color: AppColor.line))
            : null,
      ),
      child: Padding(
        padding: EdgeInsets.only(top: 5, bottom: borderBottom ? 10 : 5),
        child: row,
      ),
    );
  }
}
