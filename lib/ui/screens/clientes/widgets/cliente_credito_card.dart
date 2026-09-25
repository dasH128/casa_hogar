// lib/ui/screens/clientes/widgets/cliente_credito_card.dart

import 'package:flutter/material.dart';

import '../../../../state/cliente_ficha_models.dart';
import '../../../theme/app_tokens.dart';
import '../../../widgets/amount_text.dart';
import '../../../widgets/side_panel_card.dart';

/// Barra de crédito: usado sobre límite, con el disponible en negrita.
/// Los tres importes y el porcentaje de la barra vienen de
/// `resumen_cliente()`; aquí no se resta ni se divide nada.
class ClienteCreditoCard extends StatelessWidget {
  const ClienteCreditoCard({super.key, required this.resumen});

  final ResumenCliente resumen;

  @override
  Widget build(BuildContext context) {
    return SidePanelCard(
      title: 'Crédito',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              const Text('Límite', style: TextStyle(color: AppColor.inkMuted)),
              if (resumen.tieneLimite)
                AmountText(
                  resumen.limiteCredito,
                  currencySymbol: resumen.simbolo,
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                )
              else
                const Text(
                  'Sin límite',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
                ),
            ],
          ),
          if (resumen.tieneLimite) ...[
            const SizedBox(height: 12),
            _BarraCredito(pctUsado: resumen.pctUsado),
            const SizedBox(height: 10),
          ] else
            const SizedBox(height: 6),
          _FilaImporte(label: 'Usado', child: AmountText(resumen.usado)),
          if (resumen.tieneLimite)
            _FilaImporte(
              label: 'Disponible',
              child: AmountText(
                resumen.disponible,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}

class _BarraCredito extends StatelessWidget {
  const _BarraCredito({required this.pctUsado});

  final int pctUsado;

  @override
  Widget build(BuildContext context) {
    final pctLibre = 100 - pctUsado;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSize.creditBarHeight / 2),
      child: SizedBox(
        height: AppSize.creditBarHeight,
        child: Row(
          children: [
            if (pctUsado > 0)
              Expanded(
                flex: pctUsado,
                child: const ColoredBox(color: AppColor.primary),
              ),
            if (pctLibre > 0)
              Expanded(
                flex: pctLibre,
                child: const ColoredBox(color: AppColor.neutralSoft),
              ),
          ],
        ),
      ),
    );
  }
}

class _FilaImporte extends StatelessWidget {
  const _FilaImporte({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
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
