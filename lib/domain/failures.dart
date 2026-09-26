// lib/domain/failures.dart
//
// Errores de la app, independientes de Supabase. La capa de datos
// traduce las excepciones del cliente (`PostgrestException`,
// `AuthException`) a estos tipos (ver `data/supabase_errors.dart`);
// ViewModels y vistas solo conocen estos.

sealed class AppFailure implements Exception {
  const AppFailure(this.mensaje);

  /// Texto listo para mostrar. En [ServidorFailure] es el mensaje tal
  /// cual lo lanzó la base de datos (p. ej. un trigger de validación).
  final String mensaje;

  @override
  String toString() => mensaje;
}

/// RLS o `app.tiene_permiso()` rechazaron la operación.
class SinPermisoFailure extends AppFailure {
  const SinPermisoFailure([
    super.mensaje = 'No tienes permiso para esta acción.',
  ]);
}

/// Violación de una clave única.
class RegistroDuplicadoFailure extends AppFailure {
  const RegistroDuplicadoFailure([super.mensaje = 'El registro ya existe.']);
}

/// `confirmar_documento()` rechazó la venta por límite de crédito. El
/// mensaje es el del servidor, con sus números: `docs/ui-spec.md` pide
/// mostrarlo tal cual.
class LimiteCreditoFailure extends AppFailure {
  const LimiteCreditoFailure(super.mensaje);
}

/// Credenciales incorrectas u otro rechazo de Supabase Auth.
class AutenticacionFailure extends AppFailure {
  const AutenticacionFailure(super.mensaje);
}

/// Cualquier otro error de la base de datos o de red.
class ServidorFailure extends AppFailure {
  const ServidorFailure(super.mensaje);
}
