// lib/state/session_providers.dart
//
// Estado de sesión: sucursal y almacén elegidos en /acceso. La
// cabecera de todo documento nuevo se precarga desde aquí. La
// consulta a Supabase vive en `SesionRepository`.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repository_providers.dart';
import '../domain/models/sesion.dart';

export '../domain/models/sesion.dart';

/// Almacenes activos, con su sucursal, para el selector de /acceso.
final almacenOptionsProvider = FutureProvider<List<AlmacenOption>>(
  (ref) => ref.watch(sesionRepositoryProvider).obtenerAlmacenes(),
);

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
