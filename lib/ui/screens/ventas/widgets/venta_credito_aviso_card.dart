// lib/ui/screens/ventas/widgets/venta_credito_aviso_card.dart

import 'package:flutter/material.dart';

import '../../../theme/app_tokens.dart';
import '../../../widgets/side_panel_card.dart';

/// Aviso de crédito excedido. El texto es literalmente el que lanza
/// `confirmar_documento()` (ver `005_funciones_negocio.sql`): la
/// pantalla no vuelve a calcular deuda ni límite, solo lo muestra.
class VentaCreditoAvisoCard extends StatelessWidget {
  const VentaCreditoAvisoCard({
    super.key,
    required this.mensaje,
    this.onSolicitarAutorizacion,
  });

  final String mensaje;
  final VoidCallback? onSolicitarAutorizacion;

  @override
  Widget build(BuildContext context) {
    return SidePanelCard(
      tone: SidePanelTone.warn,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: AppSize.warningIconSize,
            color: AppColor.warnIconStrong,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Límite de crédito excedido',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColor.warn,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  mensaje,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColor.warn,
                    height: 1.5,
                  ),
                ),
                if (onSolicitarAutorizacion != null) ...[
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: onSolicitarAutorizacion,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 32),
                      side: const BorderSide(
                        color: AppColor.dangerBorderStrong,
                      ),
                      foregroundColor: AppColor.danger,
                    ),
                    child: const Text('Solicitar autorización'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
