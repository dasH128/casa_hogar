// lib/data/supabase_errors.dart
//
// Único punto donde las excepciones de Supabase se convierten en
// `AppFailure`. Todo repositorio envuelve sus llamadas con
// [ejecutarConSupabase], así nada por encima de `data/` importa
// `supabase_flutter` para capturar errores.

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/failures.dart';

const _codigoSinPermiso = '42501';
const _codigoDuplicado = '23505';

/// Prefijo del error que lanza `confirmar_documento()` (ver
/// `005_funciones_negocio.sql`).
const _prefijoLimiteCredito = 'Límite de crédito excedido';

Future<T> ejecutarConSupabase<T>(Future<T> Function() operacion) async {
  try {
    return await operacion();
  } on PostgrestException catch (error) {
    throw _traducirPostgrest(error);
  } on AuthException catch (error) {
    throw AutenticacionFailure(error.message);
  }
}

AppFailure _traducirPostgrest(PostgrestException error) {
  if (error.code == _codigoSinPermiso) return const SinPermisoFailure();
  if (error.code == _codigoDuplicado) return const RegistroDuplicadoFailure();
  if (error.message.contains(_prefijoLimiteCredito)) {
    return LimiteCreditoFailure(error.message);
  }
  return ServidorFailure(error.message);
}
