// lib/domain/models/catalogos.dart
//
// Catálogos que comparten "Nueva venta" y la ficha de cliente:
// condiciones de pago y vendedores.

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
