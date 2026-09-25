// lib/ui/screens/clientes/widgets/cliente_vencidas_card.dart

import 'package:flutter/material.dart';

import '../../../../state/cliente_ficha_models.dart';
import '../../../theme/app_tokens.dart';
import '../../../widgets/amount_text.dart';
import '../../../widgets/side_panel_card.dart';

/// Aviso de cuotas vencidas. `confirmar_documento()` no bloquea por
/// deuda vencida, solo por límite de crédito, y nunca las ventas al
/// contado: el texto lo dice para que el vendedor no dude.
class ClienteVencidasCard extends StatelessWidget {
  const ClienteVencidasCard({super.key, required this.resumen});

  final ResumenCliente resumen;

  String get _titulo => resumen.cuotasVencidas == 1
      ? 'Una cuota vencida'
      : '${resumen.cuotasVencidas} cuotas vencidas';

  String get _detalle {
    final importe =
        '${resumen.simbolo} ${AmountText.format(resumen.importeVencido)}';
    final dias = resumen.diasAtraso == 1
        ? '1 día'
        : '${resumen.diasAtraso} días';
    final atraso = resumen.cuotasVencidas == 1
        ? 'con $dias de atraso'
        : 'la más antigua con $dias de atraso';
    return '$importe $atraso. El sistema seguirá permitiendo ventas al contado.';
  }

  @override
  Widget build(BuildContext context) {
    return SidePanelCard(
      tone: SidePanelTone.danger,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              Icons.error_outline,
              size: AppSize.warningIconSize,
              color: AppColor.danger,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _titulo,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                    color: AppColor.danger,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _detalle,
                  style: const TextStyle(
                    fontSize: 11.5,
                    height: 1.5,
                    color: AppColor.danger,
                    fontFeatures: AppType.tabular,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
