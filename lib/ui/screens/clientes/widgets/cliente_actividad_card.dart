// lib/ui/screens/clientes/widgets/cliente_actividad_card.dart

import 'package:flutter/material.dart';

import '../../../../state/cliente_ficha_models.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/app_tokens.dart';
import '../../../widgets/amount_text.dart';
import '../../../widgets/side_panel_card.dart';

/// Actividad de los últimos 12 meses, tal como la devuelve
/// `resumen_cliente()`.
class ClienteActividadCard extends StatelessWidget {
  const ClienteActividadCard({super.key, required this.resumen});

  final ResumenCliente resumen;

  @override
  Widget build(BuildContext context) {
    return SidePanelCard(
      title: 'Últimos 12 meses',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _FilaDato(
            label: 'Documentos',
            child: Text('${resumen.documentos12m}', style: AppTheme.mono()),
          ),
          _FilaDato(
            label: 'Facturado',
            child: AmountText(
              resumen.facturado12m,
              currencySymbol: resumen.simbolo,
            ),
          ),
          _FilaDato(
            label: 'Ticket medio',
            child: AmountText(
              resumen.ticketMedio12m,
              currencySymbol: resumen.simbolo,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilaDato extends StatelessWidget {
  const _FilaDato({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColor.inkMuted)),
          child,
        ],
      ),
    );
  }
}
