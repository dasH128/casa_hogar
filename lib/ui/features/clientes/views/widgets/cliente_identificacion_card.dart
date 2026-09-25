// lib/ui/features/clientes/views/widgets/cliente_identificacion_card.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../domain/models/cliente_models.dart';
import '../../../../../state/catalogos_providers.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/app_field.dart';
import '../../../../core/widgets/field_label.dart';
import '../../view_models/cliente_ficha_view_model.dart';
import '../../providers/cliente_reference_providers.dart';

/// Sección "Identificación": grid de 6 columnas en tres filas, tal como
/// `design/artboards/Cliente.dc.html`. En un alta se antepone la razón
/// social, que la ficha de un cliente existente solo muestra en el
/// título.
class ClienteIdentificacionCard extends ConsumerWidget {
  const ClienteIdentificacionCard({super.key, required this.ficha});

  final ClienteFicha ficha;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(clienteFichaProvider.notifier);
    final tiposDoc = ref.watch(tiposDocIdentidadProvider).value ?? const [];
    final zonas = ref.watch(zonasProvider).value ?? const [];
    final vendedores = ref.watch(vendedoresProvider).value ?? const [];
    final condiciones = ref.watch(condicionesPagoProvider).value ?? const [];

    final tipoActual = tiposDoc
        .where((tipo) => tipo.codigo == ficha.tipoDocIdentidad)
        .firstOrNull;
    final numeroValido = tipoActual?.admite(ficha.numeroDocumento) ?? true;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColor.surface,
        border: Border.all(color: AppColor.line),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const FieldLabel('Identificación'),
            const SizedBox(height: AppSpace.md),
            if (ficha.esNuevo) ...[
              AppField(
                label: 'Razón social',
                initialValue: ficha.razonSocial,
                onChanged: (razonSocial) =>
                    notifier.editar(ficha.copyWith(razonSocial: razonSocial)),
              ),
              const SizedBox(height: 13),
            ],
            _GridRow(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _Celda(
                  child: AppField(
                    label: 'Tipo de documento',
                    child: _Desplegable(
                      value: ficha.tipoDocIdentidad,
                      opciones: {
                        for (final tipo in tiposDoc) tipo.codigo: tipo.label,
                      },
                      onChanged: (codigo) => notifier.editar(
                        ficha.copyWith(tipoDocIdentidad: codigo),
                      ),
                    ),
                  ),
                ),
                _Celda(
                  child: AppField(
                    label: 'Número',
                    monospace: true,
                    initialValue: ficha.numeroDocumento,
                    onChanged: (numero) => notifier.editar(
                      ficha.copyWith(numeroDocumento: numero),
                    ),
                  ),
                ),
                _Celda(
                  child: _ComprobanteAviso(
                    correspondeFactura: ficha.correspondeFactura,
                  ),
                ),
              ],
            ),
            if (!numeroValido) ...[
              const SizedBox(height: 6),
              Text(
                'El número no cumple el formato de ${tipoActual!.nombre}.',
                style: const TextStyle(fontSize: 11, color: AppColor.danger),
              ),
            ],
            const SizedBox(height: 13),
            _GridRow(
              children: [
                _Celda(
                  span: 4,
                  child: AppField(
                    label: 'Dirección',
                    initialValue: ficha.direccion,
                    onChanged: (direccion) =>
                        notifier.editar(ficha.copyWith(direccion: direccion)),
                  ),
                ),
                _Celda(
                  child: AppField(
                    label: 'Teléfono',
                    monospace: true,
                    keyboardType: TextInputType.phone,
                    initialValue: ficha.telefono,
                    onChanged: (telefono) =>
                        notifier.editar(ficha.copyWith(telefono: telefono)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 13),
            _GridRow(
              children: [
                _Celda(
                  child: AppField(
                    label: 'Zona',
                    child: _Desplegable(
                      value: ficha.zonaId,
                      opciones: {
                        for (final zona in zonas) zona.id: zona.nombre,
                      },
                      onChanged: (id) =>
                          notifier.editar(ficha.copyWith(zonaId: id)),
                    ),
                  ),
                ),
                _Celda(
                  child: AppField(
                    label: 'Vendedor asignado',
                    child: _Desplegable(
                      value: ficha.vendedorId,
                      opciones: {
                        for (final vendedor in vendedores)
                          vendedor.id: vendedor.nombre,
                      },
                      onChanged: (id) =>
                          notifier.editar(ficha.copyWith(vendedorId: id)),
                    ),
                  ),
                ),
                _Celda(
                  child: AppField(
                    label: 'Condición habitual',
                    child: _Desplegable(
                      value: ficha.condicionPagoId,
                      opciones: {
                        for (final condicion in condiciones)
                          condicion.id: condicion.nombre,
                      },
                      onChanged: (id) =>
                          notifier.editar(ficha.copyWith(condicionPagoId: id)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Una fila del grid de 6 columnas. Cada [_Celda] ocupa `span`
/// columnas; la separación de 13 px es el `gap` del artboard.
class _GridRow extends StatelessWidget {
  const _GridRow({
    required this.children,
    this.crossAxisAlignment = CrossAxisAlignment.start,
  });

  final List<_Celda> children;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: crossAxisAlignment,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(width: 13),
          Expanded(flex: children[i].span, child: children[i]),
        ],
      ],
    );
  }
}

class _Celda extends StatelessWidget {
  const _Celda({required this.child, this.span = 2});

  final Widget child;
  final int span;

  @override
  Widget build(BuildContext context) => child;
}

/// Desplegable con el aspecto de un [AppField]. Mientras el catálogo
/// no ha cargado, el valor guardado todavía no está entre las opciones
/// y se deja vacío; la clave fuerza a reconstruirlo cuando llegan.
class _Desplegable extends StatelessWidget {
  const _Desplegable({
    required this.value,
    required this.opciones,
    required this.onChanged,
  });

  final String? value;
  final Map<String, String> opciones;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      key: ValueKey(opciones.length),
      initialValue: opciones.containsKey(value) ? value : null,
      isDense: true,
      isExpanded: true,
      decoration: AppField.decoration(),
      style: AppField.textStyleFor(context),
      items: [
        for (final MapEntry(:key, :value) in opciones.entries)
          DropdownMenuItem(
            value: key,
            child: Text(value, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (seleccion) {
        if (seleccion != null) onChanged(seleccion);
      },
    );
  }
}

/// "DNI implica boleta, y la interfaz lo dice en línea, sin esperar a
/// un error al confirmar" (ver `docs/ui-spec.md`).
class _ComprobanteAviso extends StatelessWidget {
  const _ComprobanteAviso({required this.correspondeFactura});

  final bool correspondeFactura;

  @override
  Widget build(BuildContext context) {
    final texto = correspondeFactura
        ? 'Con RUC: corresponde factura'
        : 'Sin RUC: corresponde boleta de venta';

    return Container(
      height: AppSize.fieldHeight,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColor.tableHeader,
        borderRadius: BorderRadius.circular(AppRadius.button),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline,
            size: AppSize.inlineNoticeIconSize,
            color: AppColor.inkMuted,
          ),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: Text(
              texto,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5, color: AppColor.inkMuted),
            ),
          ),
        ],
      ),
    );
  }
}
