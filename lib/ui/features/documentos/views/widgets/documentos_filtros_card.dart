// lib/ui/features/documentos/views/widgets/documentos_filtros_card.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../../domain/estado_documento.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/app_field.dart';
import '../../providers/documentos_providers.dart';

final _formatoFecha = DateFormat('dd/MM/yyyy');

/// Barra de filtros: búsqueda, tipo, estado y rango de fechas, en ese
/// orden (ver `docs/ui-spec.md`, pantalla "3. Documentos").
class DocumentosFiltrosCard extends ConsumerWidget {
  const DocumentosFiltrosCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(documentosQueryProvider);
    final queryNotifier = ref.read(documentosQueryProvider.notifier);
    final tipos = ref.watch(tiposDocumentoProvider).value ?? const [];

    return SizedBox(
      height: AppSize.fieldHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: TextField(
              style: AppField.textStyleFor(context),
              decoration: AppField.decoration().copyWith(
                hintText: 'Número, cliente o documento de identidad · Enter',
              ),
              onSubmitted: (termino) =>
                  queryNotifier.state = query.conTermino(termino),
            ),
          ),
          const SizedBox(width: AppSpace.filterGap),
          _Desplegable(
            key: ValueKey('tipos-${tipos.length}'),
            value: query.tipoDocumento,
            todos: 'Todos los tipos',
            opciones: {for (final tipo in tipos) tipo.codigo: tipo.nombre},
            onChanged: (tipo) => queryNotifier.state = query.conTipo(tipo),
          ),
          const SizedBox(width: AppSpace.filterGap),
          _Desplegable(
            value: query.estado,
            todos: 'Todos los estados',
            opciones: {
              for (final estado in estadosDocumento)
                estado: etiquetaEstadoDocumento(estado),
            },
            onChanged: (estado) =>
                queryNotifier.state = query.conEstado(estado),
          ),
          const SizedBox(width: AppSpace.filterGap),
          _RangoFechas(
            desde: query.desde,
            hasta: query.hasta,
            onChanged: (rango) =>
                queryNotifier.state = query.conRango(rango.start, rango.end),
          ),
        ],
      ),
    );
  }
}

/// Desplegable cuya primera opción (valor null) es "todos".
class _Desplegable extends StatelessWidget {
  const _Desplegable({
    super.key,
    required this.value,
    required this.todos,
    required this.opciones,
    required this.onChanged,
  });

  final String? value;
  final String todos;
  final Map<String, String> opciones;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: AppSize.filterSelectWidth,
      child: DropdownButtonFormField<String?>(
        initialValue: opciones.containsKey(value) ? value : null,
        isDense: true,
        isExpanded: true,
        decoration: AppField.decoration(),
        style: AppField.textStyleFor(context),
        items: [
          DropdownMenuItem(value: null, child: Text(todos)),
          for (final MapEntry(:key, :value) in opciones.entries)
            DropdownMenuItem(
              value: key,
              child: Text(value, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: onChanged,
      ),
    );
  }
}

class _RangoFechas extends StatelessWidget {
  const _RangoFechas({
    required this.desde,
    required this.hasta,
    required this.onChanged,
  });

  final DateTime desde;
  final DateTime hasta;
  final ValueChanged<DateTimeRange> onChanged;

  Future<void> _elegir(BuildContext context) async {
    final rango = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: desde, end: hasta),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (rango != null) onChanged(rango);
  }

  @override
  Widget build(BuildContext context) {
    final texto =
        '${_formatoFecha.format(desde)} – ${_formatoFecha.format(hasta)}';

    return SizedBox(
      width: AppSize.dateRangeFieldWidth,
      child: InkWell(
        onTap: () => _elegir(context),
        borderRadius: BorderRadius.circular(AppRadius.field),
        child: InputDecorator(
          decoration: AppField.decoration(),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(texto, style: AppTheme.mono(size: 12.5)),
          ),
        ),
      ),
    );
  }
}
