// lib/ui/features/acceso/view_models/acceso_view_model.dart
//
// Estado y flujo de `/acceso`: elegir almacén, iniciar sesión, cargar
// el perfil y decidir a qué ruta ir (ver `rutaSegunRol` en
// `state/perfil_providers.dart`). El acceso a Supabase vive en
// `AuthRepository`/`PerfilRepository`.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/repositories/auth_repository.dart';
import '../../../../data/repositories/perfil_repository.dart';
import '../../../../data/repository_providers.dart';
import '../../../../domain/failures.dart';
import '../../../../state/perfil_providers.dart';
import '../../../../state/session_providers.dart';

class AccesoState {
  const AccesoState({this.almacenId, this.submitting = false, this.error});

  final String? almacenId;
  final bool submitting;
  final String? error;

  AccesoState copyWith({
    String? almacenId,
    bool? submitting,
    String? error,
    bool clearError = false,
  }) {
    return AccesoState(
      almacenId: almacenId ?? this.almacenId,
      submitting: submitting ?? this.submitting,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class AccesoViewModel extends Notifier<AccesoState> {
  AuthRepository get _authRepository => ref.read(authRepositoryProvider);
  PerfilRepository get _perfilRepository => ref.read(perfilRepositoryProvider);

  @override
  AccesoState build() => const AccesoState();

  void seleccionarAlmacen(String? almacenId) {
    state = state.copyWith(almacenId: almacenId);
  }

  /// True si hay que avisar "te enviamos un enlace"; lanza
  /// [AutenticacionFailure] si Supabase rechaza la solicitud.
  Future<bool> recuperarContrasena(String email) async {
    if (email.trim().isEmpty) {
      state = state.copyWith(
        error: 'Escribe tu correo para recuperar la contraseña.',
      );
      return false;
    }
    await _authRepository.recuperarContrasena(email.trim());
    return true;
  }

  /// Inicia sesión, carga el perfil y guarda sucursal/almacén elegidos.
  /// Devuelve la ruta de destino, o null si falló (el motivo queda en
  /// [AccesoState.error]).
  Future<String?> entrar({
    required String email,
    required String password,
    required List<AlmacenOption> opciones,
  }) async {
    final almacenId = state.almacenId;
    if (almacenId == null) {
      state = state.copyWith(error: 'Elige una sucursal y almacén.');
      return null;
    }

    state = state.copyWith(submitting: true, clearError: true);
    try {
      final userId = await _authRepository.iniciarSesion(
        email: email.trim(),
        password: password,
      );
      if (userId == null) {
        state = state.copyWith(
          error: 'No se pudo iniciar sesión. Intenta de nuevo.',
        );
        return null;
      }

      final perfil = await _perfilRepository.obtenerPerfil(userId);
      final opcion = opciones.firstWhere((o) => o.almacenId == almacenId);

      ref
          .read(sesionProvider.notifier)
          .seleccionar(
            SesionSeleccion(
              sucursalId: opcion.sucursalId,
              almacenId: opcion.almacenId,
            ),
          );
      ref.read(perfilActualProvider.notifier).establecer(perfil);

      return rutaSegunRol(perfil.rolCodigo);
    } on AutenticacionFailure catch (failure) {
      state = state.copyWith(error: failure.mensaje);
      return null;
    } catch (_) {
      state = state.copyWith(
        error: 'No se pudo iniciar sesión. Intenta de nuevo.',
      );
      return null;
    } finally {
      state = state.copyWith(submitting: false);
    }
  }
}

final accesoProvider = NotifierProvider<AccesoViewModel, AccesoState>(
  AccesoViewModel.new,
);
