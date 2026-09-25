// lib/state/cliente_reference_providers.dart
//
// Catálogos de solo lectura para la ficha de cliente. Vendedores y
// condiciones de pago se comparten con "Nueva venta"
// (`venta_reference_providers.dart`).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'cliente_ficha_models.dart';

final tiposDocIdentidadProvider = FutureProvider<List<TipoDocIdentidadOption>>((
  ref,
) async {
  final rows = await Supabase.instance.client
      .from('cat_tipo_doc_identidad')
      .select('codigo, nombre, patron')
      .order('codigo');

  return [for (final row in rows) TipoDocIdentidadOption.fromRow(row)];
});

final zonasProvider = FutureProvider<List<ZonaOption>>((ref) async {
  final rows = await Supabase.instance.client
      .from('zonas')
      .select('id, nombre')
      .eq('activo', true)
      .order('nombre');

  return [for (final row in rows) ZonaOption.fromRow(row)];
});
