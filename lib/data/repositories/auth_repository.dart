// lib/data/repositories/auth_repository.dart

import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRepository {
  SupabaseClient get _db => Supabase.instance.client;

  /// Devuelve el id del usuario autenticado, o null si Supabase no lo
  /// entregó (no debería pasar sin lanzar [AuthException] antes).
  Future<String?> iniciarSesion({
    required String email,
    required String password,
  }) async {
    final response = await _db.auth.signInWithPassword(
      email: email,
      password: password,
    );
    return response.user?.id;
  }

  Future<void> recuperarContrasena(String email) {
    return _db.auth.resetPasswordForEmail(email);
  }
}
