// lib/data/repositories/auth_repository.dart

import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase_errors.dart';

class AuthRepository {
  AuthRepository(this._db);

  final SupabaseClient _db;

  /// Devuelve el id del usuario autenticado, o null si Supabase no lo
  /// entregó. Credenciales incorrectas lanzan `AutenticacionFailure`.
  Future<String?> iniciarSesion({
    required String email,
    required String password,
  }) {
    return ejecutarConSupabase(() async {
      final response = await _db.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return response.user?.id;
    });
  }

  Future<void> recuperarContrasena(String email) {
    return ejecutarConSupabase(() async {
      return _db.auth.resetPasswordForEmail(email);
    });
  }
}
