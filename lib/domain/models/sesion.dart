// lib/domain/models/sesion.dart
//
// Sucursal y almacén elegidos en /acceso. La cabecera de todo
// documento nuevo se precarga desde aquí.

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

/// La sucursal y el almacén elegidos al entrar.
class SesionSeleccion {
  const SesionSeleccion({required this.sucursalId, required this.almacenId});

  final String sucursalId;
  final String almacenId;
}
