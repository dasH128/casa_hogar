// lib/domain/models/cliente_models.dart
//
// Modelos de la ficha de cliente. Saldos, crédito usado, disponible y
// actividad llegan ya calculados desde `cuenta_corriente_cuotas` y
// `resumen_cliente()` (ver `012_ficha_cliente.sql`): aquí solo se
// transportan, nunca se recalculan.

import 'package:decimal/decimal.dart';

import '../decimal_parsing.dart';
import '../doc_identidad.dart';

String simboloMoneda(String moneda) => moneda == 'PEN' ? 'S/' : moneda;

/// Datos editables de `clientes`. [id] es null mientras el cliente
/// no se ha dado de alta (`/clientes/nuevo`).
class ClienteFicha {
  const ClienteFicha({
    required this.id,
    required this.tipoDocIdentidad,
    required this.numeroDocumento,
    required this.razonSocial,
    required this.direccion,
    required this.telefono,
    required this.zonaId,
    required this.vendedorId,
    required this.condicionPagoId,
  });

  /// Alta nueva: DNI por defecto, el caso más común en mostrador.
  const ClienteFicha.nuevo()
    : id = null,
      tipoDocIdentidad = '1',
      numeroDocumento = '',
      razonSocial = '',
      direccion = '',
      telefono = '',
      zonaId = null,
      vendedorId = null,
      condicionPagoId = null;

  factory ClienteFicha.fromRow(Map<String, dynamic> row) {
    return ClienteFicha(
      id: row['id'] as String,
      tipoDocIdentidad: row['tipo_doc_identidad'] as String,
      numeroDocumento: row['numero_documento'] as String,
      razonSocial: row['razon_social'] as String,
      direccion: row['direccion'] as String? ?? '',
      telefono: row['telefono'] as String? ?? '',
      zonaId: row['zona_id'] as String?,
      vendedorId: row['vendedor_id'] as String?,
      condicionPagoId: row['condicion_pago_id'] as String?,
    );
  }

  final String? id;
  final String tipoDocIdentidad;
  final String numeroDocumento;
  final String razonSocial;
  final String direccion;
  final String telefono;
  final String? zonaId;
  final String? vendedorId;
  final String? condicionPagoId;

  bool get esNuevo => id == null;

  bool get correspondeFactura => tipoDocIdentidad == codigoRuc;

  /// RUC 20… es persona jurídica; RUC 10… y cualquier otro documento
  /// de identidad, persona natural.
  bool get esPersonaJuridica =>
      correspondeFactura && numeroDocumento.startsWith('20');

  /// Columnas para el `update` de `clientes`. Los textos vacíos se
  /// guardan como null, igual que un cliente dado de alta sin ellos.
  Map<String, Object?> toUpdateRow() {
    return {
      'tipo_doc_identidad': tipoDocIdentidad,
      'numero_documento': numeroDocumento.trim(),
      'direccion': _textoONulo(direccion),
      'telefono': _textoONulo(telefono),
      'zona_id': zonaId,
      'vendedor_id': vendedorId,
      'condicion_pago_id': condicionPagoId,
    };
  }

  /// La razón social solo se escribe en el alta: la ficha de un
  /// cliente existente no la edita (ver `design/artboards/Cliente.dc.html`).
  Map<String, Object?> toInsertRow() {
    return {...toUpdateRow(), 'razon_social': razonSocial.trim()};
  }

  ClienteFicha copyWith({
    String? tipoDocIdentidad,
    String? numeroDocumento,
    String? razonSocial,
    String? direccion,
    String? telefono,
    String? zonaId,
    String? vendedorId,
    String? condicionPagoId,
  }) {
    return ClienteFicha(
      id: id,
      tipoDocIdentidad: tipoDocIdentidad ?? this.tipoDocIdentidad,
      numeroDocumento: numeroDocumento ?? this.numeroDocumento,
      razonSocial: razonSocial ?? this.razonSocial,
      direccion: direccion ?? this.direccion,
      telefono: telefono ?? this.telefono,
      zonaId: zonaId ?? this.zonaId,
      vendedorId: vendedorId ?? this.vendedorId,
      condicionPagoId: condicionPagoId ?? this.condicionPagoId,
    );
  }

  static String? _textoONulo(String texto) {
    final limpio = texto.trim();
    return limpio.isEmpty ? null : limpio;
  }
}

enum EstadoCuota { porVencer, vencida, cancelada }

/// Una fila de `cuenta_corriente_cuotas`.
class CuotaCuentaCorriente {
  const CuotaCuentaCorriente({
    required this.cuotaId,
    required this.documentoId,
    required this.serie,
    required this.correlativo,
    required this.fechaEmision,
    required this.fechaVencimiento,
    required this.numero,
    required this.totalCuotas,
    required this.monto,
    required this.saldo,
    required this.estado,
  });

  factory CuotaCuentaCorriente.fromRow(Map<String, dynamic> row) {
    return CuotaCuentaCorriente(
      cuotaId: row['cuota_id'] as String,
      documentoId: row['documento_id'] as String,
      serie: row['serie'] as String? ?? '',
      correlativo: row['correlativo'] as int? ?? 0,
      fechaEmision: DateTime.parse(row['fecha_emision'] as String),
      fechaVencimiento: DateTime.parse(row['fecha_vencimiento'] as String),
      numero: row['numero'] as int,
      totalCuotas: row['total_cuotas'] as int,
      monto: parseDecimal(row['monto']),
      saldo: parseDecimal(row['saldo']),
      estado: _estadoDesde(row['estado_cuota'] as String),
    );
  }

  final String cuotaId;
  final String documentoId;
  final String serie;
  final int correlativo;
  final DateTime fechaEmision;
  final DateTime fechaVencimiento;
  final int numero;
  final int totalCuotas;
  final Decimal monto;
  final Decimal saldo;
  final EstadoCuota estado;

  /// `B001-00001180`: SUNAT admite hasta ocho dígitos de correlativo.
  String get numeroDocumento =>
      '$serie-${correlativo.toString().padLeft(8, '0')}';

  static EstadoCuota _estadoDesde(String estado) {
    return switch (estado) {
      'VENCIDA' => EstadoCuota.vencida,
      'CANCELADA' => EstadoCuota.cancelada,
      _ => EstadoCuota.porVencer,
    };
  }
}

/// Lo que devuelve `resumen_cliente()`.
class ResumenCliente {
  const ResumenCliente({
    required this.limiteCredito,
    required this.monedaCredito,
    required this.usado,
    required this.disponible,
    required this.pctUsado,
    required this.cuotasVencidas,
    required this.importeVencido,
    required this.diasAtraso,
    required this.documentos12m,
    required this.facturado12m,
    required this.ticketMedio12m,
  });

  factory ResumenCliente.fromJson(Map<String, dynamic> json) {
    return ResumenCliente(
      limiteCredito: parseDecimal(json['limite_credito']),
      monedaCredito: json['moneda_credito'] as String,
      usado: parseDecimal(json['usado']),
      disponible: parseDecimal(json['disponible']),
      pctUsado: json['pct_usado'] as int,
      cuotasVencidas: json['cuotas_vencidas'] as int,
      importeVencido: parseDecimal(json['importe_vencido']),
      diasAtraso: json['dias_atraso'] as int,
      documentos12m: json['documentos_12m'] as int,
      facturado12m: parseDecimal(json['facturado_12m']),
      ticketMedio12m: parseDecimal(json['ticket_medio_12m']),
    );
  }

  final Decimal limiteCredito;
  final String monedaCredito;
  final Decimal usado;
  final Decimal disponible;

  /// Entero de 0 a 100, ya calculado en la base de datos.
  final int pctUsado;
  final int cuotasVencidas;
  final Decimal importeVencido;
  final int diasAtraso;
  final int documentos12m;
  final Decimal facturado12m;
  final Decimal ticketMedio12m;

  /// `confirmar_documento()` solo controla el crédito si el límite es
  /// mayor que cero: un límite 0 es "sin límite".
  bool get tieneLimite => limiteCredito > Decimal.zero;

  String get simbolo => simboloMoneda(monedaCredito);
}

/// Entrada del catálogo 06, con el patrón de validación del número.
class TipoDocIdentidadOption {
  const TipoDocIdentidadOption({
    required this.codigo,
    required this.nombre,
    required this.patron,
  });

  factory TipoDocIdentidadOption.fromRow(Map<String, dynamic> row) {
    return TipoDocIdentidadOption(
      codigo: row['codigo'] as String,
      nombre: row['nombre'] as String,
      patron: row['patron'] as String?,
    );
  }

  final String codigo;
  final String nombre;
  final String? patron;

  String get label => '$codigo · $nombre';

  /// El mismo patrón que aplica el trigger `clientes_valida_doc`: la
  /// pantalla lo avisa antes de guardar, la base de datos lo exige.
  bool admite(String numero) {
    final regla = patron;
    if (regla == null) return true;
    return RegExp(regla).hasMatch(numero.trim());
  }
}

class ZonaOption {
  const ZonaOption({required this.id, required this.nombre});

  factory ZonaOption.fromRow(Map<String, dynamic> row) {
    return ZonaOption(id: row['id'] as String, nombre: row['nombre'] as String);
  }

  final String id;
  final String nombre;
}

/// Una fila del listado de `/clientes`.
class ClienteListado {
  const ClienteListado({
    required this.id,
    required this.tipoDocIdentidad,
    required this.numeroDocumento,
    required this.razonSocial,
    required this.zona,
    required this.vendedor,
    required this.limiteCredito,
    required this.monedaCredito,
    required this.bloqueado,
  });

  factory ClienteListado.fromRow(Map<String, dynamic> row) {
    final zona = row['zonas'] as Map<String, dynamic>?;
    final vendedor = row['vendedores'] as Map<String, dynamic>?;
    return ClienteListado(
      id: row['id'] as String,
      tipoDocIdentidad: row['tipo_doc_identidad'] as String,
      numeroDocumento: row['numero_documento'] as String,
      razonSocial: row['razon_social'] as String,
      zona: zona?['nombre'] as String?,
      vendedor: vendedor?['nombre'] as String?,
      limiteCredito: parseDecimal(row['limite_credito']),
      monedaCredito: row['moneda_credito'] as String,
      bloqueado: row['bloqueado'] as bool,
    );
  }

  final String id;
  final String tipoDocIdentidad;
  final String numeroDocumento;
  final String razonSocial;
  final String? zona;
  final String? vendedor;
  final Decimal limiteCredito;
  final String monedaCredito;
  final bool bloqueado;
}
