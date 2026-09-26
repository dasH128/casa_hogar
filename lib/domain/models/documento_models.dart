// lib/domain/models/documento_models.dart
//
// Modelos de la pantalla Documentos. Número formateado, importe con
// signo y estado ante SUNAT llegan ya resueltos desde la vista
// `documentos_listado` (ver `013_documentos_listado.sql`).

import 'package:decimal/decimal.dart';

import '../decimal_parsing.dart';

/// Estado ante SUNAT, independiente de `documentos.estado`.
enum EstadoSunat {
  noFiscal,
  sinEnvio,
  resumenDiario,
  pendiente,
  errorTecnico,
  aceptado,
  observado,
  rechazado,
  bajaSolicitada,
  bajaAceptada;

  static EstadoSunat desde(String valor) {
    return switch (valor) {
      'NO_FISCAL' => noFiscal,
      'RESUMEN_DIARIO' => resumenDiario,
      'PENDIENTE' => pendiente,
      'ERROR_TECNICO' => errorTecnico,
      'ACEPTADO' => aceptado,
      'OBSERVADO' => observado,
      'RECHAZADO' => rechazado,
      'BAJA_SOLICITADA' => bajaSolicitada,
      'BAJA_ACEPTADA' => bajaAceptada,
      _ => sinEnvio,
    };
  }
}

/// Una fila de `documentos_listado`.
class DocumentoListado {
  const DocumentoListado({
    required this.id,
    required this.tipoDocumento,
    required this.esCompra,
    required this.numero,
    required this.fechaEmision,
    required this.estado,
    required this.simboloMoneda,
    required this.importe,
    required this.tercero,
    required this.terceroTipoDoc,
    required this.terceroNumeroDoc,
    required this.referenciaNumero,
    required this.motivoNota,
    required this.notaCreditoNumero,
    required this.estadoSunat,
    required this.codigoRespuesta,
    required this.descripcionRespuesta,
    required this.respondidoEn,
    required this.diasPlazoEnvio,
  });

  factory DocumentoListado.fromRow(Map<String, dynamic> row) {
    final respondidoEn = row['respondido_en'] as String?;
    return DocumentoListado(
      id: row['id'] as String,
      tipoDocumento: row['tipo_documento'] as String,
      esCompra: row['es_compra'] as bool,
      numero: row['numero'] as String?,
      fechaEmision: DateTime.parse(row['fecha_emision'] as String),
      estado: row['estado'] as String,
      simboloMoneda: row['simbolo_moneda'] as String,
      importe: parseDecimal(row['importe']),
      tercero: row['tercero'] as String?,
      terceroTipoDoc: row['tercero_tipo_doc'] as String?,
      terceroNumeroDoc: row['tercero_numero_doc'] as String?,
      referenciaNumero: row['referencia_numero'] as String?,
      motivoNota: row['motivo_nota'] as String?,
      notaCreditoNumero: row['nota_credito_numero'] as String?,
      estadoSunat: EstadoSunat.desde(row['estado_sunat'] as String),
      codigoRespuesta: row['codigo_respuesta'] as String?,
      descripcionRespuesta: row['descripcion_respuesta'] as String?,
      respondidoEn: respondidoEn == null
          ? null
          : DateTime.parse(respondidoEn).toLocal(),
      diasPlazoEnvio: row['dias_plazo_envio'] as int,
    );
  }

  final String id;
  final String tipoDocumento;
  final bool esCompra;

  /// Null mientras el documento es borrador: el correlativo se asigna
  /// al confirmar.
  final String? numero;
  final DateTime fechaEmision;
  final String estado;
  final String simboloMoneda;

  /// Negativo en notas de crédito.
  final Decimal importe;
  final String? tercero;
  final String? terceroTipoDoc;
  final String? terceroNumeroDoc;
  final String? referenciaNumero;
  final String? motivoNota;
  final String? notaCreditoNumero;
  final EstadoSunat estadoSunat;
  final String? codigoRespuesta;
  final String? descripcionRespuesta;
  final DateTime? respondidoEn;

  /// Días hasta el plazo legal de envío; negativo si ya venció.
  final int diasPlazoEnvio;

  bool get anulado => estado == 'ANULADO';

  bool get esBoleta => tipoDocumento == 'BV';

  bool get esNotaSalida => tipoDocumento == 'NS';
}

/// Lo que devuelve `resumen_documentos()`.
class ResumenDocumentos {
  const ResumenDocumentos({
    required this.aceptadosHoy,
    required this.pendientesEnvio,
    required this.rechazados,
  });

  factory ResumenDocumentos.fromJson(Map<String, dynamic> json) {
    return ResumenDocumentos(
      aceptadosHoy: json['aceptados_hoy'] as int,
      pendientesEnvio: json['pendientes_envio'] as int,
      rechazados: json['rechazados'] as int,
    );
  }

  final int aceptadosHoy;
  final int pendientesEnvio;
  final int rechazados;
}

class TipoDocumentoOption {
  const TipoDocumentoOption({required this.codigo, required this.nombre});

  factory TipoDocumentoOption.fromRow(Map<String, dynamic> row) {
    return TipoDocumentoOption(
      codigo: row['codigo'] as String,
      nombre: row['nombre'] as String,
    );
  }

  final String codigo;
  final String nombre;
}

/// Filtros de la tabla. Inmutable: cada cambio devuelve una copia.
class DocumentosQuery {
  const DocumentosQuery({
    required this.desde,
    required this.hasta,
    this.termino = '',
    this.tipoDocumento,
    this.estado,
  });

  /// Los tres últimos días, el mismo margen que el plazo legal de
  /// envío a SUNAT.
  factory DocumentosQuery.inicial(DateTime hoy) {
    final dia = DateTime(hoy.year, hoy.month, hoy.day);
    return DocumentosQuery(
      desde: dia.subtract(const Duration(days: 2)),
      hasta: dia,
    );
  }

  final String termino;

  /// Null significa "todos los tipos".
  final String? tipoDocumento;

  /// Null significa "todos los estados".
  final String? estado;
  final DateTime desde;
  final DateTime hasta;

  DocumentosQuery conTermino(String termino) => _copia(termino: termino);

  DocumentosQuery conTipo(String? tipoDocumento) =>
      _copia(tipoDocumento: () => tipoDocumento);

  DocumentosQuery conEstado(String? estado) => _copia(estado: () => estado);

  DocumentosQuery conRango(DateTime desde, DateTime hasta) =>
      _copia(desde: desde, hasta: hasta);

  DocumentosQuery _copia({
    String? termino,
    String? Function()? tipoDocumento,
    String? Function()? estado,
    DateTime? desde,
    DateTime? hasta,
  }) {
    return DocumentosQuery(
      termino: termino ?? this.termino,
      tipoDocumento: tipoDocumento == null
          ? this.tipoDocumento
          : tipoDocumento(),
      estado: estado == null ? this.estado : estado(),
      desde: desde ?? this.desde,
      hasta: hasta ?? this.hasta,
    );
  }
}
