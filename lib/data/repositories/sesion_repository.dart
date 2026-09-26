// lib/data/repositories/sesion_repository.dart

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/sesion.dart';
import '../supabase_errors.dart';

class SesionRepository {
  SesionRepository(this._db);

  final SupabaseClient _db;

  /// Almacenes activos, con su sucursal, para el selector de /acceso.
  Future<List<AlmacenOption>> obtenerAlmacenes() {
    return ejecutarConSupabase(() async {
      final rows = await _db
          .from('almacenes')
          .select('id, nombre, sucursal:sucursales(id, codigo, nombre)')
          .eq('activo', true)
          .order('nombre');

      return [
        for (final row in rows)
          AlmacenOption(
            almacenId: row['id'] as String,
            sucursalId: (row['sucursal'] as Map)['id'] as String,
            label:
                '${(row['sucursal'] as Map)['codigo']} · '
                '${(row['sucursal'] as Map)['nombre']} — ${row['nombre']}',
          ),
      ];
    });
  }
}
