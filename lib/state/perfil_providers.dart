// lib/state/perfil_providers.dart
//
// Quién es el usuario ya autenticado: nombre y "Rol · Sucursal" para
// el pie del rail de `AppShell`. Se llena una vez, justo después del
// login en `/acceso` (ver `acceso_screen.dart`).

import 'package:flutter_riverpod/flutter_riverpod.dart';

class PerfilActual {
  const PerfilActual({
    required this.nombre,
    required this.rolCodigo,
    required this.rolLabel,
    required this.permisos,
  });

  final String nombre;
  final String rolCodigo;

  /// "Gerente · Sucursal M", ya formateado para `AppShell.userRoleLabel`.
  final String rolLabel;

  /// La matriz de permisos del rol (tabla `permisos`, ver
  /// `001_fundamentos.sql`), como `'recurso.accion'`. Solo para decidir
  /// qué mostrar en el rail: la autorización real la aplica RLS en
  /// cada tabla.
  final Set<String> permisos;

  bool tienePermiso(String recurso, String accion) =>
      permisos.contains('$recurso.$accion');
}

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
