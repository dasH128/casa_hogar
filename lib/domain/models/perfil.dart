// lib/domain/models/perfil.dart
//
// Quién es el usuario ya autenticado: nombre y "Rol · Sucursal" para
// el pie del rail de `AppShell`.

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
