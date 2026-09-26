// lib/data/repositories/cliente_repository.dart
//
// Todo el acceso a Supabase de la ficha y el listado de clientes. Los
// ViewModels (`ui/features/clientes/view_models/`) no hablan con
// Supabase directo.

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/cliente_models.dart';
import '../supabase_errors.dart';

const _limiteFilasListado = 200;

class ClienteRepository {
  ClienteRepository(this._db);

  final SupabaseClient _db;

  Future<ClienteFicha> obtenerFicha(String id) {
    return ejecutarConSupabase(() async {
      final row = await _db
          .from('clientes')
          .select(
            'id, tipo_doc_identidad, numero_documento, razon_social, '
            'direccion, telefono, zona_id, vendedor_id, condicion_pago_id',
          )
          .eq('id', id)
          .single();
      return ClienteFicha.fromRow(row);
    });
  }

  Future<List<CuotaCuentaCorriente>> obtenerCuotas(String clienteId) {
    return ejecutarConSupabase(() async {
      final rows = await _db
          .from('cuenta_corriente_cuotas')
          .select()
          .eq('cliente_id', clienteId)
          .order('fecha_emision', ascending: false)
          .order('correlativo', ascending: false)
          .order('numero');
      return [for (final row in rows) CuotaCuentaCorriente.fromRow(row)];
    });
  }

  Future<ResumenCliente> obtenerResumen(String clienteId) {
    return ejecutarConSupabase(() async {
      final json = await _db.rpc(
        'resumen_cliente',
        params: {'p_cliente_id': clienteId},
      );
      return ResumenCliente.fromJson(json as Map<String, dynamic>);
    });
  }

  Future<String> insertar(ClienteFicha ficha) {
    return ejecutarConSupabase(() async {
      final row = await _db
          .from('clientes')
          .insert(ficha.toInsertRow())
          .select('id')
          .single();
      return row['id'] as String;
    });
  }

  /// Null si el `update` no afectó ninguna fila: una política RLS que
  /// no se cumple no lanza error, solo deja la fila intacta.
  Future<String?> actualizar(ClienteFicha ficha) {
    return ejecutarConSupabase(() async {
      final filas = await _db
          .from('clientes')
          .update(ficha.toUpdateRow())
          .eq('id', ficha.id!)
          .select('id');
      return filas.isEmpty ? null : ficha.id!;
    });
  }

  Future<List<TipoDocIdentidadOption>> obtenerTiposDocIdentidad() {
    return ejecutarConSupabase(() async {
      final rows = await _db
          .from('cat_tipo_doc_identidad')
          .select('codigo, nombre, patron')
          .order('codigo');
      return [for (final row in rows) TipoDocIdentidadOption.fromRow(row)];
    });
  }

  Future<List<ZonaOption>> obtenerZonas() {
    return ejecutarConSupabase(() async {
      final rows = await _db
          .from('zonas')
          .select('id, nombre')
          .eq('activo', true)
          .order('nombre');
      return [for (final row in rows) ZonaOption.fromRow(row)];
    });
  }

  Future<List<ClienteListado>> listar(String termino) {
    return ejecutarConSupabase(() async {
      final terminoSeguro = _terminoSeguro(termino);
      var query = _db
          .from('clientes')
          .select(
            'id, tipo_doc_identidad, numero_documento, razon_social, '
            'limite_credito, moneda_credito, bloqueado, '
            'zonas(nombre), vendedores(nombre)',
          )
          .eq('activo', true);
      if (terminoSeguro.isNotEmpty) {
        query = query.or(
          'razon_social.ilike.%$terminoSeguro%,numero_documento.ilike.%$terminoSeguro%',
        );
      }

      final rows = await query.order('razon_social').limit(_limiteFilasListado);
      return [for (final row in rows) ClienteListado.fromRow(row)];
    });
  }

  /// Comas y paréntesis rompen la sintaxis del filtro `or` de PostgREST.
  String _terminoSeguro(String termino) =>
      termino.replaceAll(RegExp(r'[,()]'), ' ').trim();
}
