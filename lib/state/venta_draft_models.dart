// lib/state/venta_draft_models.dart
//
// Modelos del borrador de "Nueva venta". Los importes de línea
// (valor_venta, igv_linea, total_linea) y de cabecera (total_*,
// importe_total) solo cambian cuando responde `recalcular_documento`
// o `confirmar_documento` (ver `005_funciones_negocio.sql` y
// `009_recalcular_documento_rpc.sql`): estos modelos los transportan,
// nunca los recalculan.

import 'package:decimal/decimal.dart';

/// Postgrest entrega `numeric` como número JSON, no como string; para
/// no perder el valor exacto de una vez, se convierte a [Decimal] tan
/// pronto llega, y no se vuelve a tocar como `double`.
Decimal parseDecimal(Object? value) {
  if (value == null) return Decimal.zero;
  if (value is num) return Decimal.parse(value.toString());
  return Decimal.parse(value as String);
}

class ClienteResumen {
  const ClienteResumen({
    required this.id,
    required this.tipoDocIdentidad,
    required this.numeroDocumento,
    required this.razonSocial,
    required this.condicionPagoId,
    required this.limiteCredito,
  });

  factory ClienteResumen.fromRow(Map<String, dynamic> row) {
    return ClienteResumen(
      id: row['id'] as String,
      tipoDocIdentidad: row['tipo_doc_identidad'] as String,
      numeroDocumento: row['numero_documento'] as String,
      razonSocial: row['razon_social'] as String,
      condicionPagoId: row['condicion_pago_id'] as String?,
      limiteCredito: parseDecimal(row['limite_credito']),
    );
  }

  final String id;
  final String tipoDocIdentidad;
  final String numeroDocumento;
  final String razonSocial;
  final String? condicionPagoId;
  final Decimal limiteCredito;
}

class CondicionPagoOption {
  const CondicionPagoOption({
    required this.id,
    required this.codigo,
    required this.nombre,
    required this.formaPago,
    required this.diasCredito,
  });

  factory CondicionPagoOption.fromRow(Map<String, dynamic> row) {
    return CondicionPagoOption(
      id: row['id'] as String,
      codigo: row['codigo'] as String,
      nombre: row['nombre'] as String,
      formaPago: row['forma_pago'] as String,
      diasCredito: row['dias_credito'] as int,
    );
  }

  final String id;
  final String codigo;
  final String nombre;
  final String formaPago; // 'CONTADO' | 'CREDITO'
  final int diasCredito;
}

class VendedorOption {
  const VendedorOption({
    required this.id,
    required this.codigo,
    required this.nombre,
  });

  factory VendedorOption.fromRow(Map<String, dynamic> row) {
    return VendedorOption(
      id: row['id'] as String,
      codigo: row['codigo'] as String,
      nombre: row['nombre'] as String,
    );
  }

  final String id;
  final String codigo;
  final String nombre;
}

/// Una presentación de venta de un producto ('CAJA x72', 'UNIDAD'...).
class PresentacionOption {
  const PresentacionOption({
    required this.id,
    required this.codigo,
    required this.nombre,
    required this.unidadMedida,
    required this.factor,
    required this.esDefaultVenta,
  });

  factory PresentacionOption.fromRow(Map<String, dynamic> row) {
    return PresentacionOption(
      id: row['id'] as String,
      codigo: row['codigo'] as String,
      nombre: row['nombre'] as String,
      unidadMedida: row['unidad_medida'] as String,
      factor: parseDecimal(row['factor']),
      esDefaultVenta: row['es_default_venta'] as bool,
    );
  }

  final String id;
  final String codigo;
  final String nombre;
  final String unidadMedida;
  final Decimal factor;
  final bool esDefaultVenta;
}

/// Resultado del buscador de producto (última fila de la grilla).
class ProductoBusqueda {
  const ProductoBusqueda({
    required this.id,
    required this.sku,
    required this.descripcion,
    required this.codigoProductoSunat,
    required this.afectacionIgv,
    required this.tasaIgv,
    required this.costeMedio,
    required this.presentaciones,
  });

  factory ProductoBusqueda.fromRow(Map<String, dynamic> row) {
    final afectacion = row['cat_afectacion_igv'] as Map<String, dynamic>?;
    return ProductoBusqueda(
      id: row['id'] as String,
      sku: row['sku'] as String,
      descripcion: row['descripcion'] as String,
      codigoProductoSunat: row['codigo_producto_sunat'] as String?,
      afectacionIgv: row['afectacion_igv'] as String,
      tasaIgv: parseDecimal(afectacion?['tasa_igv']),
      costeMedio: parseDecimal(row['coste_medio']),
      presentaciones: [
        for (final p
            in (row['presentaciones'] as List).cast<Map<String, dynamic>>())
          if (p['activo'] == true) PresentacionOption.fromRow(p),
      ],
    );
  }

  final String id;
  final String sku;
  final String descripcion;
  final String? codigoProductoSunat;
  final String afectacionIgv;
  final Decimal tasaIgv;
  final Decimal costeMedio;
  final List<PresentacionOption> presentaciones;

  /// La presentación con la que se agrega la línea si el usuario no
  /// elige otra: `es_default_venta`, o la primera si ninguna lo es.
  PresentacionOption? get presentacionSugerida {
    if (presentaciones.isEmpty) return null;
    return presentaciones.firstWhere(
      (p) => p.esDefaultVenta,
      orElse: () => presentaciones.first,
    );
  }
}

/// Una línea del documento. Sin `id` hasta que se guarda; los importes
/// quedan en cero hasta el siguiente recálculo del servidor.
class LineaVentaDraft {
  LineaVentaDraft({
    this.id,
    required this.numeroLinea,
    required this.productoId,
    this.presentacionId,
    required this.sku,
    required this.descripcion,
    required this.presentacionNombre,
    required this.unidadMedida,
    required this.cantidad,
    required this.factorConversion,
    required this.precioUnitario,
    required this.dto1Pct,
    required this.dto2Pct,
    required this.dto3Pct,
    required this.afectacionIgv,
    required this.tasaIgv,
    required this.costeUnitarioSnapshot,
    Decimal? valorVenta,
    Decimal? igvLinea,
    Decimal? totalLinea,
  }) : valorVenta = valorVenta ?? Decimal.zero,
       igvLinea = igvLinea ?? Decimal.zero,
       totalLinea = totalLinea ?? Decimal.zero;

  factory LineaVentaDraft.fromRow(Map<String, dynamic> row) {
    final presentacion = row['presentaciones'] as Map<String, dynamic>?;
    return LineaVentaDraft(
      id: row['id'] as String,
      numeroLinea: row['numero_linea'] as int,
      productoId: row['producto_id'] as String,
      presentacionId: row['presentacion_id'] as String?,
      sku: row['sku'] as String? ?? '',
      descripcion: row['descripcion'] as String,
      presentacionNombre: presentacion?['nombre'] as String? ?? '',
      unidadMedida: row['unidad_medida'] as String,
      cantidad: parseDecimal(row['cantidad']),
      factorConversion: parseDecimal(row['factor_conversion']),
      precioUnitario: parseDecimal(row['precio_unitario']),
      dto1Pct: parseDecimal(row['dto1_pct']),
      dto2Pct: parseDecimal(row['dto2_pct']),
      dto3Pct: parseDecimal(row['dto3_pct']),
      afectacionIgv: row['afectacion_igv'] as String,
      tasaIgv: parseDecimal(row['tasa_igv']),
      costeUnitarioSnapshot: parseDecimal(row['coste_unitario_snapshot']),
      valorVenta: parseDecimal(row['valor_venta']),
      igvLinea: parseDecimal(row['igv_linea']),
      totalLinea: parseDecimal(row['total_linea']),
    );
  }

  final String? id;
  final int numeroLinea;
  final String productoId;
  final String? presentacionId;
  final String sku;
  final String descripcion;
  final String presentacionNombre;
  final String unidadMedida;
  final Decimal cantidad;
  final Decimal factorConversion;
  final Decimal precioUnitario;
  final Decimal dto1Pct;
  final Decimal dto2Pct;
  final Decimal dto3Pct;
  final String afectacionIgv;
  final Decimal tasaIgv;
  final Decimal costeUnitarioSnapshot;

  /// Server-computed por `app.recalcular_totales`; cero hasta el
  /// próximo recálculo.
  final Decimal valorVenta;
  final Decimal igvLinea;
  final Decimal totalLinea;

  /// Vista previa de la conversión a unidad base. Es aritmética de
  /// empaque (cantidad × factor), no de dinero: coincide con la
  /// columna generada `documento_lineas.cantidad_base`.
  Decimal get cantidadBase => cantidad * factorConversion;

  LineaVentaDraft copyWith({
    String? id,
    Decimal? cantidad,
    Decimal? precioUnitario,
    Decimal? dto1Pct,
    Decimal? dto2Pct,
    Decimal? dto3Pct,
    Decimal? valorVenta,
    Decimal? igvLinea,
    Decimal? totalLinea,
  }) {
    return LineaVentaDraft(
      id: id ?? this.id,
      numeroLinea: numeroLinea,
      productoId: productoId,
      presentacionId: presentacionId,
      sku: sku,
      descripcion: descripcion,
      presentacionNombre: presentacionNombre,
      unidadMedida: unidadMedida,
      cantidad: cantidad ?? this.cantidad,
      factorConversion: factorConversion,
      precioUnitario: precioUnitario ?? this.precioUnitario,
      dto1Pct: dto1Pct ?? this.dto1Pct,
      dto2Pct: dto2Pct ?? this.dto2Pct,
      dto3Pct: dto3Pct ?? this.dto3Pct,
      afectacionIgv: afectacionIgv,
      tasaIgv: tasaIgv,
      costeUnitarioSnapshot: costeUnitarioSnapshot,
      valorVenta: valorVenta ?? this.valorVenta,
      igvLinea: igvLinea ?? this.igvLinea,
      totalLinea: totalLinea ?? this.totalLinea,
    );
  }
}

/// Cabecera y totales del documento en edición.
class DocumentoVentaDraft {
  DocumentoVentaDraft({
    required this.id,
    this.serie,
    this.correlativo,
    required this.estado,
    required this.sucursalId,
    required this.almacenId,
    this.clienteId,
    this.vendedorId,
    this.condicionPagoId,
    required this.formaPago,
    required this.fechaEmision,
    this.fechaVencimiento,
    required this.moneda,
    required this.tipoCambio,
    required this.preciosIncluyenIgv,
    required this.modoDescuento,
    Decimal? totalGravado,
    Decimal? totalExonerado,
    Decimal? totalInafecto,
    Decimal? totalDescuento,
    Decimal? totalIgv,
    Decimal? totalPercepcion,
    Decimal? importeTotal,
  }) : totalGravado = totalGravado ?? Decimal.zero,
       totalExonerado = totalExonerado ?? Decimal.zero,
       totalInafecto = totalInafecto ?? Decimal.zero,
       totalDescuento = totalDescuento ?? Decimal.zero,
       totalIgv = totalIgv ?? Decimal.zero,
       totalPercepcion = totalPercepcion ?? Decimal.zero,
       importeTotal = importeTotal ?? Decimal.zero;

  factory DocumentoVentaDraft.fromRow(Map<String, dynamic> row) {
    return DocumentoVentaDraft(
      id: row['id'] as String,
      serie: row['serie'] as String?,
      correlativo: row['correlativo'] as int?,
      estado: row['estado'] as String,
      sucursalId: row['sucursal_id'] as String,
      almacenId: row['almacen_id'] as String,
      clienteId: row['cliente_id'] as String?,
      vendedorId: row['vendedor_id'] as String?,
      condicionPagoId: row['condicion_pago_id'] as String?,
      formaPago: row['forma_pago'] as String,
      fechaEmision: DateTime.parse(row['fecha_emision'] as String),
      fechaVencimiento: row['fecha_vencimiento'] == null
          ? null
          : DateTime.parse(row['fecha_vencimiento'] as String),
      moneda: row['moneda'] as String,
      tipoCambio: parseDecimal(row['tipo_cambio']),
      preciosIncluyenIgv: row['precios_incluyen_igv'] as bool,
      modoDescuento: row['modo_descuento'] as String,
      totalGravado: parseDecimal(row['total_gravado']),
      totalExonerado: parseDecimal(row['total_exonerado']),
      totalInafecto: parseDecimal(row['total_inafecto']),
      totalDescuento: parseDecimal(row['total_descuento']),
      totalIgv: parseDecimal(row['total_igv']),
      totalPercepcion: parseDecimal(row['total_percepcion']),
      importeTotal: parseDecimal(row['importe_total']),
    );
  }

  final String id;
  final String? serie;
  final int? correlativo;
  final String estado;
  final String sucursalId;
  final String almacenId;
  final String? clienteId;
  final String? vendedorId;
  final String? condicionPagoId;
  final String formaPago;
  final DateTime fechaEmision;
  final DateTime? fechaVencimiento;
  final String moneda;
  final Decimal tipoCambio;
  final bool preciosIncluyenIgv;
  final String modoDescuento; // 'SUCESIVO' | 'LINEAL'

  final Decimal totalGravado;
  final Decimal totalExonerado;
  final Decimal totalInafecto;
  final Decimal totalDescuento;
  final Decimal totalIgv;
  final Decimal totalPercepcion;
  final Decimal importeTotal;

  /// Suma de los tres grupos que la cabecera trata como "valor de
  /// venta" (gravado + exonerado + inafecto), tal como lo calcula
  /// `app.recalcular_totales`.
  Decimal get valorVenta => totalGravado + totalExonerado + totalInafecto;

  bool get esBorrador => estado == 'BORRADOR';

  DocumentoVentaDraft copyWith({
    String? serie,
    int? correlativo,
    String? estado,
    String? clienteId,
    String? almacenId,
    String? vendedorId,
    String? condicionPagoId,
    String? formaPago,
    DateTime? fechaVencimiento,
    bool clearFechaVencimiento = false,
    Decimal? totalGravado,
    Decimal? totalExonerado,
    Decimal? totalInafecto,
    Decimal? totalDescuento,
    Decimal? totalIgv,
    Decimal? totalPercepcion,
    Decimal? importeTotal,
  }) {
    return DocumentoVentaDraft(
      id: id,
      serie: serie ?? this.serie,
      correlativo: correlativo ?? this.correlativo,
      estado: estado ?? this.estado,
      sucursalId: sucursalId,
      almacenId: almacenId ?? this.almacenId,
      clienteId: clienteId ?? this.clienteId,
      vendedorId: vendedorId ?? this.vendedorId,
      condicionPagoId: condicionPagoId ?? this.condicionPagoId,
      formaPago: formaPago ?? this.formaPago,
      fechaEmision: fechaEmision,
      fechaVencimiento: clearFechaVencimiento
          ? null
          : (fechaVencimiento ?? this.fechaVencimiento),
      moneda: moneda,
      tipoCambio: tipoCambio,
      preciosIncluyenIgv: preciosIncluyenIgv,
      modoDescuento: modoDescuento,
      totalGravado: totalGravado ?? this.totalGravado,
      totalExonerado: totalExonerado ?? this.totalExonerado,
      totalInafecto: totalInafecto ?? this.totalInafecto,
      totalDescuento: totalDescuento ?? this.totalDescuento,
      totalIgv: totalIgv ?? this.totalIgv,
      totalPercepcion: totalPercepcion ?? this.totalPercepcion,
      importeTotal: importeTotal ?? this.importeTotal,
    );
  }
}
