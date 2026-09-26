// lib/ui/features/ventas/views/widgets/venta_header_card.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../../domain/doc_identidad.dart';
import '../../../../../domain/models/venta_models.dart';
import '../../../../../state/catalogos_providers.dart';
import '../../../../../state/session_providers.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/app_field.dart';
import '../../providers/venta_busqueda_providers.dart';
import '../../view_models/venta_form_view_model.dart';

/// Cabecera del documento: grid de 12 columnas en dos filas, tal como
/// `design/artboards/Main.dc.html`.
class VentaHeaderCard extends ConsumerWidget {
  const VentaHeaderCard({super.key, required this.state});

  final VentaFormState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doc = state.documento;
    final notifier = ref.read(ventaFormProvider.notifier);
    final cliente = state.clienteResumen;

    final serieNumero = doc.serie == null
        ? 'Se asigna al confirmar'
        : '${doc.serie}-${doc.correlativo.toString().padLeft(7, '0')}';

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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(
                  flex: 3,
                  child: AppField(
                    label: 'Documento',
                    readOnly: true,
                    initialValue: 'Nota de salida',
                  ),
                ),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  flex: 2,
                  child: AppField(
                    label: 'Serie · Número',
                    readOnly: true,
                    monospace: true,
                    initialValue: serieNumero,
                  ),
                ),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  flex: 5,
                  child: _ClienteField(
                    cliente: cliente,
                    onSelected: notifier.seleccionarCliente,
                  ),
                ),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  flex: 2,
                  child: AppField(
                    label: cliente == null
                        ? 'Doc.'
                        : abreviaturaDocIdentidad(cliente.tipoDocIdentidad),
                    readOnly: true,
                    monospace: true,
                    initialValue: cliente?.numeroDocumento ?? '—',
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.md),
            Consumer(
              builder: (context, ref, _) {
                final almacenes =
                    ref.watch(almacenOptionsProvider).value ?? const [];
                final condiciones =
                    ref.watch(condicionesPagoProvider).value ?? const [];
                final vendedores =
                    ref.watch(vendedoresProvider).value ?? const [];

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: AppField(
                        label: 'Almacén',
                        child: DropdownButtonFormField<String>(
                          initialValue: doc.almacenId,
                          isDense: true,
                          decoration: AppField.decoration(),
                          style: AppField.textStyleFor(context),
                          items: [
                            for (final almacen in almacenes)
                              DropdownMenuItem(
                                value: almacen.almacenId,
                                child: Text(almacen.label),
                              ),
                          ],
                          onChanged: (_) {},
                          selectedItemBuilder: (context) => [
                            for (final a in almacenes)
                              Text(a.label, overflow: TextOverflow.ellipsis),
                          ],
                          onSaved: null,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpace.md),
                    Expanded(
                      flex: 3,
                      child: AppField(
                        label: 'Condición de pago',
                        child: DropdownButtonFormField<String>(
                          initialValue: doc.condicionPagoId,
                          isDense: true,
                          decoration: AppField.decoration(),
                          style: AppField.textStyleFor(context),
                          items: [
                            for (final condicion in condiciones)
                              DropdownMenuItem(
                                value: condicion.id,
                                child: Text(condicion.nombre),
                              ),
                          ],
                          onChanged: (id) {
                            if (id == null) return;
                            final condicion = condiciones.firstWhere(
                              (c) => c.id == id,
                            );
                            notifier.seleccionarCondicionPago(condicion);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpace.md),
                    Expanded(
                      flex: 2,
                      child: AppField(
                        label: 'Vendedor',
                        child: DropdownButtonFormField<String>(
                          initialValue: doc.vendedorId,
                          isDense: true,
                          decoration: AppField.decoration(),
                          style: AppField.textStyleFor(context),
                          items: [
                            for (final vendedor in vendedores)
                              DropdownMenuItem(
                                value: vendedor.id,
                                child: Text(vendedor.nombre),
                              ),
                          ],
                          onChanged: (id) {
                            if (id == null) return;
                            notifier.seleccionarVendedor(
                              vendedores.firstWhere((v) => v.id == id),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpace.md),
                    Expanded(
                      flex: 2,
                      child: AppField(
                        label: 'Emisión',
                        readOnly: true,
                        monospace: true,
                        initialValue: DateFormat('dd/MM/yyyy')
                            .format(doc.fechaEmision),
                      ),
                    ),
                    const SizedBox(width: AppSpace.md),
                    Expanded(
                      flex: 2,
                      child: AppField(
                        label: 'Vencimiento',
                        readOnly: true,
                        monospace: true,
                        initialValue: doc.fechaVencimiento == null
                            ? ''
                            : DateFormat('dd/MM/yyyy')
                                  .format(doc.fechaVencimiento!),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ClienteField extends StatelessWidget {
  const _ClienteField({required this.cliente, required this.onSelected});

  final ClienteResumen? cliente;
  final ValueChanged<ClienteResumen> onSelected;

  @override
  Widget build(BuildContext context) {
    return AppField(
      label: 'Cliente',
      readOnly: true,
      initialValue: cliente?.razonSocial ?? 'Elegir cliente…',
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.field),
        onTap: () async {
          final elegido = await showDialog<ClienteResumen>(
            context: context,
            builder: (_) => const _ClienteSearchDialog(),
          );
          if (elegido != null) onSelected(elegido);
        },
        child: InputDecorator(
          decoration: AppField.decoration(),
          child: Text(
            cliente?.razonSocial ?? 'Elegir cliente…',
            overflow: TextOverflow.ellipsis,
            style: AppField.textStyleFor(context)?.copyWith(
              fontWeight: cliente != null ? FontWeight.w500 : FontWeight.w400,
              color: cliente != null ? AppColor.ink : AppColor.inkFaint,
            ),
          ),
        ),
      ),
    );
  }
}

class _ClienteSearchDialog extends ConsumerStatefulWidget {
  const _ClienteSearchDialog();

  @override
  ConsumerState<_ClienteSearchDialog> createState() =>
      _ClienteSearchDialogState();
}

class _ClienteSearchDialogState extends ConsumerState<_ClienteSearchDialog> {
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    ref.read(clienteSearchQueryProvider.notifier).state = '';
    super.dispose();
  }

  void _buscar(String texto) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      ref.read(clienteSearchQueryProvider.notifier).state = texto;
    });
  }

  @override
  Widget build(BuildContext context) {
    final resultados = ref.watch(clienteSearchResultsProvider);

    return AlertDialog(
      title: const Text('Buscar cliente'),
      content: SizedBox(
        width: 420,
        height: 360,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Razón social o número de documento',
              ),
              onChanged: _buscar,
            ),
            const SizedBox(height: AppSpace.sm),
            Expanded(
              child: resultados.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(child: Text('Error: $error')),
                data: (clientes) {
                  if (clientes.isEmpty) {
                    return const Center(
                      child: Text(
                        'Escribe para buscar',
                        style: TextStyle(color: AppColor.inkFaint),
                      ),
                    );
                  }
                  return ListView.separated(
                    itemCount: clientes.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final cliente = clientes[index];
                      return ListTile(
                        title: Text(cliente.razonSocial),
                        subtitle: Text(
                          '${abreviaturaDocIdentidad(cliente.tipoDocIdentidad)} ${cliente.numeroDocumento}',
                        ),
                        onTap: () => Navigator.of(context).pop(cliente),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}
