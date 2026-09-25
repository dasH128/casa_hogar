// lib/state/cliente_ficha_controller.dart
//
// Estado de la ficha de cliente (`/clientes/:id` y `/clientes/nuevo`).
// Los datos editables se escriben en `clientes`; cuenta corriente y
// resumen de crédito son de solo lectura y salen de
// `012_ficha_cliente.sql`. Un alta no tiene ninguno de los dos.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'cliente_ficha_models.dart';
import 'clientes_lista_providers.dart';

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

class ClienteFichaNotifier extends Notifier<AsyncValue<ClienteFichaState>> {
  @override
  AsyncValue<ClienteFichaState> build() => const AsyncValue.loading();

  SupabaseClient get _db => Supabase.instance.client;
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
        _cargarFicha(clienteId),
        _cargarCuotas(clienteId),
        _cargarResumen(clienteId),
      ).wait;
      return ClienteFichaState(ficha: ficha, cuotas: cuotas, resumen: resumen);
    });
  }

  Future<ClienteFicha> _cargarFicha(String id) async {
    final row = await _db
        .from('clientes')
        .select(
          'id, tipo_doc_identidad, numero_documento, razon_social, '
          'direccion, telefono, zona_id, vendedor_id, condicion_pago_id',
        )
        .eq('id', id)
        .single();
    return ClienteFicha.fromRow(row);
  }

  Future<List<CuotaCuentaCorriente>> _cargarCuotas(String clienteId) async {
    final rows = await _db
        .from('cuenta_corriente_cuotas')
        .select()
        .eq('cliente_id', clienteId)
        .order('fecha_emision', ascending: false)
        .order('correlativo', ascending: false)
        .order('numero');
    return [for (final row in rows) CuotaCuentaCorriente.fromRow(row)];
  }

  Future<ResumenCliente> _cargarResumen(String clienteId) async {
    final json = await _db.rpc(
      'resumen_cliente',
      params: {'p_cliente_id': clienteId},
    );
    return ResumenCliente.fromJson(json as Map<String, dynamic>);
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
    final row = await _db
        .from('clientes')
        .insert(ficha.toInsertRow())
        .select('id')
        .single();
    ref.invalidate(clientesListaProvider);
    return row['id'] as String;
  }

  /// Una política RLS de `update` que no se cumple no lanza error: el
  /// `update` afecta cero filas. Por eso se pide la fila de vuelta y,
  /// si no llega, se trata como falta de permiso.
  Future<String> _actualizar(ClienteFicha ficha) async {
    final filas = await _db
        .from('clientes')
        .update(ficha.toUpdateRow())
        .eq('id', ficha.id!)
        .select('id');
    if (filas.isEmpty) {
      throw const GuardarClienteFailure(
        'No tienes permiso para modificar clientes.',
      );
    }
    ref.invalidate(clientesListaProvider);
    return ficha.id!;
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
    NotifierProvider<ClienteFichaNotifier, AsyncValue<ClienteFichaState>>(
      ClienteFichaNotifier.new,
    );
