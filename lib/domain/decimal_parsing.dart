// lib/domain/decimal_parsing.dart
//
// Compartido entre "Nueva venta" y la ficha de cliente: ambos leen
// columnas `numeric` de Supabase y las necesitan como `Decimal`, nunca
// como `double`.

import 'package:decimal/decimal.dart';

/// Postgrest entrega `numeric` como número JSON, no como string; para
/// no perder el valor exacto de una vez, se convierte a [Decimal] tan
/// pronto llega, y no se vuelve a tocar como `double`.
Decimal parseDecimal(Object? value) {
  if (value == null) return Decimal.zero;
  if (value is num) return Decimal.parse(value.toString());
  return Decimal.parse(value as String);
}
