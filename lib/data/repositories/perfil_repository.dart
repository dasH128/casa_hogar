// lib/data/repositories/perfil_repository.dart

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/perfil.dart';
import '../supabase_errors.dart';

class PerfilRepository {
  PerfilRepository(this._db);

  final SupabaseClient _db;

  /// Nombre, rol y matriz de permisos del usuario ya autenticado.
  Future<PerfilActual> obtenerPerfil(String userId) {
    return ejecutarConSupabase(() async {
      final perfil = await _db
          .from('profiles')
          .select(
            'rol_id, nombre, rol:roles(codigo, nombre), sucursal:sucursales(nombre)',
          )
          .eq('id', userId)
          .single();
      final rol = perfil['rol'] as Map;
      final sucursal = perfil['sucursal'] as Map?;

      final permisosRows = await _db
          .from('permisos')
          .select('recurso, accion')
          .eq('rol_id', perfil['rol_id'] as String);
      final permisos = {
        for (final p in permisosRows) '${p['recurso']}.${p['accion']}',
      };

      return PerfilActual(
        nombre: perfil['nombre'] as String,
        rolCodigo: rol['codigo'] as String,
        rolLabel: '${rol['nombre']} · ${sucursal?['nombre'] ?? 'Sin sucursal'}',
        permisos: permisos,
      );
    });
  }
}
