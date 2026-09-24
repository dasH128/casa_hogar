// lib/state/session_providers.dart
//
// Estado de sesión: sucursal y almacén elegidos en /acceso. La
// cabecera de todo documento nuevo se precarga desde aquí.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Un almacén seleccionable en /acceso, con el nombre de su sucursal
/// ya compuesto para mostrar en el desplegable.
class AlmacenOption {
  const AlmacenOption({
    required this.almacenId,
    required this.sucursalId,
    required this.label,
  });

  final String almacenId;
  final String sucursalId;
  final String label;
}

/// Almacenes activos, con su sucursal, para el selector de /acceso.
final almacenOptionsProvider = FutureProvider<List<AlmacenOption>>((ref) async {
  final rows = await Supabase.instance.client
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

/// La sucursal y el almacén elegidos al entrar.
class SesionSeleccion {
  const SesionSeleccion({required this.sucursalId, required this.almacenId});

  final String sucursalId;
  final String almacenId;
}

class SesionNotifier extends Notifier<SesionSeleccion?> {
  @override
  SesionSeleccion? build() => null;

  void seleccionar(SesionSeleccion seleccion) => state = seleccion;

  void limpiar() => state = null;
}

/// Null hasta que el usuario elige sucursal y almacén en /acceso.
final sesionProvider = NotifierProvider<SesionNotifier, SesionSeleccion?>(
  SesionNotifier.new,
);
