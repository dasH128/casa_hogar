// lib/ui/features/documentos/views/widgets/documentos_tabla_card.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../../domain/doc_identidad.dart';
import '../../../../../domain/models/documento_models.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/amount_text.dart';
import '../../../../core/widgets/data_table_shell.dart';
import '../../../../core/widgets/status_pill.dart';

const _columnas = [
  DataTableColumn(label: 'Tipo', width: FixedColumnWidth(52)),
  DataTableColumn(label: 'Número', width: FixedColumnWidth(132)),
  DataTableColumn(label: 'Emisión', width: FixedColumnWidth(90)),
  DataTableColumn(label: 'Cliente o proveedor', width: FlexColumnWidth()),
  DataTableColumn(label: 'Total', width: FixedColumnWidth(120), numeric: true),
  DataTableColumn(label: 'Estado', width: FixedColumnWidth(104)),
  DataTableColumn(label: 'SUNAT', width: FixedColumnWidth(216)),
];

const _tamanoCelda = 12.5;
const _tamanoSecundario = 11.5;

final _formatoFecha = DateFormat('dd/MM/yyyy');
final _formatoHora = DateFormat('HH:mm');

/// Tabla de documentos con **dos columnas de estado**: la del documento
/// y la de SUNAT (ver `docs/ui-spec.md`, pantalla "3. Documentos").
/// Solo las notas de salida abren su formulario: es el único tipo que
/// tiene pantalla por ahora (`/ventas/:id`).
class DocumentosTablaCard extends StatelessWidget {
  const DocumentosTablaCard({super.key, required this.documentos});

  final List<DocumentoListado> documentos;

  @override
  Widget build(BuildContext context) {
    return DataTableShell(
      columns: _columnas,
      rowCount: documentos.length,
      rowColor: (row) => _fondoFila(documentos[row]),
      isRowTappable: (row) => documentos[row].esNotaSalida,
      onRowTap: (row) => context.go('/ventas/${documentos[row].id}'),
      cellBuilder: (context, row, column) =>
          _Celda(documento: documentos[row], column: column),
      trailingRow: documentos.isEmpty ? const _SinResultados() : null,
    );
  }
}

/// Pendiente de envío en `warnBg`, rechazado en `dangerBg`. Una fila
/// anulada ya no requiere atención: sin fondo.
Color? _fondoFila(DocumentoListado documento) {
  if (documento.anulado) return null;
  return switch (documento.estadoSunat) {
    EstadoSunat.pendiente || EstadoSunat.errorTecnico => AppColor.warnBg,
    EstadoSunat.rechazado => AppColor.dangerBg,
    _ => null,
  };
}

class _Celda extends StatelessWidget {
  const _Celda({required this.documento, required this.column});

  final DocumentoListado documento;
  final int column;

  @override
  Widget build(BuildContext context) {
    final anulado = documento.anulado;
    final colorBase = anulado ? AppColor.inkDisabled : AppColor.ink;
    final colorSecundario = anulado ? AppColor.inkDisabled : AppColor.inkMuted;

    return switch (column) {
      0 => Text(
        documento.tipoDocumento,
        style: AppTheme.mono(size: _tamanoCelda, color: colorSecundario),
      ),
      1 => _Numero(documento: documento),
      2 => Text(
        _formatoFecha.format(documento.fechaEmision),
        style: AppTheme.mono(size: _tamanoCelda, color: colorSecundario),
      ),
      3 => _Tercero(documento: documento, color: colorBase),
      4 => AmountText(
        documento.importe,
        currencySymbol: documento.simboloMoneda,
        fontSize: _tamanoCelda,
        color: colorBase,
      ),
      5 => StatusPill.estadoDocumento(documento.estado),
      _ => _DetalleSunat(documento: documento),
    };
  }
}

/// Número en mono 500; tachado si el documento está anulado.
class _Numero extends StatelessWidget {
  const _Numero({required this.documento});

  final DocumentoListado documento;

  @override
  Widget build(BuildContext context) {
    final numero = documento.numero;
    if (numero == null) {
      return Text(
        'Sin numerar',
        style: AppTheme.mono(size: _tamanoCelda, color: AppColor.inkFaint),
      );
    }

    final anulado = documento.anulado;
    return Text(
      numero,
      style: AppTheme.mono(
        size: _tamanoCelda,
        weight: anulado ? FontWeight.w400 : FontWeight.w500,
        color: anulado ? AppColor.inkDisabled : AppColor.ink,
      ).copyWith(decoration: anulado ? TextDecoration.lineThrough : null),
    );
  }
}

/// Razón social y, en gris, el dato que la aclara: el DNI en una
/// boleta, la referencia y el motivo en una nota, "compra" en una
/// compra.
class _Tercero extends StatelessWidget {
  const _Tercero({required this.documento, required this.color});

  final DocumentoListado documento;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final secundario = _textoSecundario();
    final colorSecundario = documento.anulado
        ? AppColor.inkDisabled
        : AppColor.inkFaint;

    return Text.rich(
      TextSpan(
        text: documento.tercero ?? '—',
        style: TextStyle(fontSize: _tamanoCelda, color: color),
        children: [
          if (secundario != null)
            TextSpan(
              text: ' · $secundario',
              style: documento.esBoleta
                  ? AppTheme.mono(
                      size: _tamanoSecundario,
                      color: colorSecundario,
                    )
                  : TextStyle(
                      fontSize: _tamanoSecundario,
                      color: colorSecundario,
                    ),
            ),
        ],
      ),
      overflow: TextOverflow.ellipsis,
    );
  }

  String? _textoSecundario() {
    final referencia = documento.referenciaNumero;
    if (referencia != null) {
      final motivo = documento.motivoNota;
      return motivo == null
          ? 'ref. $referencia'
          : 'ref. $referencia · motivo $motivo';
    }
    if (documento.esCompra) return 'compra';

    final tipoDoc = documento.terceroTipoDoc;
    final numeroDoc = documento.terceroNumeroDoc;
    if (documento.esBoleta && tipoDoc != null && numeroDoc != null) {
      return '${abreviaturaDocIdentidad(tipoDoc)} $numeroDoc';
    }
    return null;
  }
}

/// Columna SUNAT: estado del envío en palabras, con el color de su
/// gravedad. Una nota de salida jamás tendrá CDR, y lo dice.
class _DetalleSunat extends StatelessWidget {
  const _DetalleSunat({required this.documento});

  final DocumentoListado documento;

  @override
  Widget build(BuildContext context) {
    final (texto, color) = _detalle();
    return Text(
      texto,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: _tamanoCelda, color: color),
    );
  }

  (String, Color) _detalle() {
    final notaCredito = documento.notaCreditoNumero;
    if (documento.anulado && notaCredito != null) {
      return ('Nota de crédito $notaCredito', AppColor.inkDisabled);
    }

    return switch (documento.estadoSunat) {
      EstadoSunat.noFiscal => (
        'No es comprobante fiscal',
        AppColor.inkDisabled,
      ),
      EstadoSunat.sinEnvio => ('Sin enviar', AppColor.inkDisabled),
      EstadoSunat.resumenDiario => (
        'Entra en el resumen diario',
        AppColor.inkMuted,
      ),
      EstadoSunat.pendiente => (
        'En cola · ${_plazo(documento.diasPlazoEnvio)}',
        documento.diasPlazoEnvio < 0 ? AppColor.danger : AppColor.warn,
      ),
      EstadoSunat.errorTecnico => (
        'Error técnico · se reintentará',
        AppColor.warn,
      ),
      EstadoSunat.aceptado => (_cdrConforme(), AppColor.inkMuted),
      EstadoSunat.observado => (
        _conCodigo('CDR con observaciones'),
        AppColor.warn,
      ),
      EstadoSunat.rechazado => (_rechazo(), AppColor.danger),
      EstadoSunat.bajaSolicitada => ('Baja solicitada', AppColor.inkMuted),
      EstadoSunat.bajaAceptada => ('Baja aceptada', AppColor.inkMuted),
    };
  }

  String _plazo(int dias) {
    return switch (dias) {
      < 0 => 'plazo vencido',
      0 => 'vence hoy',
      1 => 'vence mañana',
      _ => 'vence en $dias días',
    };
  }

  /// La hora solo aporta si la respuesta llegó hoy.
  String _cdrConforme() {
    final respondido = documento.respondidoEn;
    if (respondido == null || !_esHoy(respondido)) return 'CDR conforme';
    return 'CDR conforme · ${_formatoHora.format(respondido)}';
  }

  String _conCodigo(String texto) {
    final codigo = documento.codigoRespuesta;
    return codigo == null ? texto : '$texto · $codigo';
  }

  String _rechazo() {
    final codigo = documento.codigoRespuesta;
    final descripcion = documento.descripcionRespuesta;
    final motivo = switch ((codigo, descripcion)) {
      (null, null) => 'Rechazado por SUNAT',
      (final c?, null) => c,
      (null, final d?) => d,
      (final c?, final d?) => '$c · $d',
    };
    return '$motivo. Corregir y reemitir';
  }

  bool _esHoy(DateTime momento) {
    final hoy = DateTime.now();
    return momento.year == hoy.year &&
        momento.month == hoy.month &&
        momento.day == hoy.day;
  }
}

class _SinResultados extends StatelessWidget {
  const _SinResultados();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(AppSpace.cardPadding),
      child: Text(
        'No hay documentos con estos filtros.',
        style: TextStyle(fontSize: _tamanoCelda, color: AppColor.inkFaint),
      ),
    );
  }
}
