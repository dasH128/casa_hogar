// lib/data/repositories/catalogos_repository.dart
//
// Acceso a los catálogos que comparten "Nueva venta" y la ficha de
// cliente: condiciones de pago y vendedores.

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/catalogos.dart';

class CatalogosRepository {
  SupabaseClient get _db => Supabase.instance.client;

  Future<List<CondicionPagoOption>> obtenerCondicionesPago() async {
    final rows = await _db
        .from('condiciones_pago')
        .select('id, codigo, nombre, forma_pago, dias_credito')
        .eq('activo', true)
        .order('nombre');

    return [for (final row in rows) CondicionPagoOption.fromRow(row)];
  }

  Future<List<VendedorOption>> obtenerVendedores() async {
    final rows = await _db
        .from('vendedores')
        .select('id, codigo, nombre')
        .eq('activo', true)
        .order('nombre');

    return [for (final row in rows) VendedorOption.fromRow(row)];
  }
}
