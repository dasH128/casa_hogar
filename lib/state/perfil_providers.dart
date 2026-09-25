// lib/state/perfil_providers.dart
//
// Quién es el usuario ya autenticado. Se llena una vez, justo después
// del login (ver `ui/features/acceso/view_models/acceso_view_model.dart`).
// La consulta a Supabase vive en `PerfilRepository`.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/perfil.dart';

export '../domain/models/perfil.dart';

class PerfilActualNotifier extends Notifier<PerfilActual?> {
  @override
  PerfilActual? build() => null;

  void establecer(PerfilActual perfil) => state = perfil;

  void limpiar() => state = null;
}

final perfilActualProvider =
    NotifierProvider<PerfilActualNotifier, PerfilActual?>(
      PerfilActualNotifier.new,
    );

/// A dónde va cada rol justo después de iniciar sesión (ver
/// `docs/ui-spec.md`, pantalla "1. Acceso").
String rutaSegunRol(String rolCodigo) {
  return switch (rolCodigo) {
    'vendedor' => '/ventas/nueva',
    'almacen' => '/compras',
    _ => '/documentos',
  };
}
