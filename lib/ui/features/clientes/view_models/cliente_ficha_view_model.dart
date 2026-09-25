// lib/ui/features/clientes/view_models/cliente_ficha_view_model.dart
//
// Estado de la ficha de cliente (`/clientes/:id` y `/clientes/nuevo`).
// Los datos editables se escriben en `clientes`; cuenta corriente y
// resumen de crédito son de solo lectura y salen de
// `012_ficha_cliente.sql`. Un alta no tiene ninguno de los dos. El
// acceso a Supabase vive en `ClienteRepository`.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../data/repositories/cliente_repository.dart';
import '../../../../domain/models/cliente_models.dart';
import '../providers/clientes_lista_providers.dart';

class ClienteFichaState {
  const ClienteFichaState({
    required this.ficha,
    this.cuotas = const [],
    this.resumen,
    this.guardando = false,
  });

  final ClienteFicha ficha;
  final List<CuotaCuentaCorriente> cuotas;

  /// Null en un alta: todavía no hay crédito ni actividad que resumir.
  final ResumenCliente? resumen;
  final bool guardando;

  ClienteFichaState copyWith({ClienteFicha? ficha, bool? guardando}) {
    return ClienteFichaState(
      ficha: ficha ?? this.ficha,
      cuotas: cuotas,
      resumen: resumen,
      guardando: guardando ?? this.guardando,
    );
  }
}

/// Error de guardado ya traducido para mostrarlo tal cual.
class GuardarClienteFailure implements Exception {
  const GuardarClienteFailure(this.mensaje);

  final String mensaje;

  @override
  String toString() => mensaje;
}

class ClienteFichaViewModel extends Notifier<AsyncValue<ClienteFichaState>> {
  final _repository = ClienteRepository();

  @override
  AsyncValue<ClienteFichaState> build() => const AsyncValue.loading();

  ClienteFichaState get _current => state.requireValue;

  void nuevo() {
    state = const AsyncValue.data(
      ClienteFichaState(ficha: ClienteFicha.nuevo()),
    );
  }

  Future<void> cargar(String clienteId) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final (ficha, cuotas, resumen) = await (
        _repository.obtenerFicha(clienteId),
        _repository.obtenerCuotas(clienteId),
        _repository.obtenerResumen(clienteId),
      ).wait;
      return ClienteFichaState(ficha: ficha, cuotas: cuotas, resumen: resumen);
    });
  }

  void editar(ClienteFicha ficha) {
    state = AsyncValue.data(_current.copyWith(ficha: ficha));
  }

  /// Guarda la ficha y devuelve el id del cliente, recién creado si
  /// era un alta.
  Future<String> guardar() async {
    final ficha = _current.ficha;
    if (ficha.esNuevo && ficha.razonSocial.trim().isEmpty) {
      throw const GuardarClienteFailure('Escribe la razón social.');
    }

    state = AsyncValue.data(_current.copyWith(guardando: true));
    try {
      return ficha.esNuevo ? await _insertar(ficha) : await _actualizar(ficha);
    } on PostgrestException catch (error) {
      throw GuardarClienteFailure(_mensajeGuardado(error));
    } finally {
      state = AsyncValue.data(_current.copyWith(guardando: false));
    }
  }

  Future<String> _insertar(ClienteFicha ficha) async {
    final id = await _repository.insertar(ficha);
    ref.invalidate(clientesListaProvider);
    return id;
  }

  Future<String> _actualizar(ClienteFicha ficha) async {
    final id = await _repository.actualizar(ficha);
    if (id == null) {
      throw const GuardarClienteFailure(
        'No tienes permiso para modificar clientes.',
      );
    }
    ref.invalidate(clientesListaProvider);
    return id;
  }

  String _mensajeGuardado(PostgrestException error) {
    return switch (error.code) {
      '23505' => 'Ya existe un cliente con ese tipo y número de documento.',
      '42501' => 'No tienes permiso para guardar clientes.',
      _ => error.message,
    };
  }
}

final clienteFichaProvider =
    NotifierProvider<ClienteFichaViewModel, AsyncValue<ClienteFichaState>>(
      ClienteFichaViewModel.new,
    );
