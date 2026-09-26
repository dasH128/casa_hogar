// lib/data/repositories/venta_repository.dart
//
// Todo el acceso a Supabase de "Nueva venta": documentos, líneas y
// las búsquedas propias de la pantalla. El ViewModel
// (`venta_form_view_model.dart`) no habla con Supabase directo.

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/venta_models.dart';
import '../supabase_errors.dart';

class VentaRepository {
  VentaRepository(this._db);

  final SupabaseClient _db;

  Future<DocumentoVentaDraft> crearBorrador({
    required String sucursalId,
    required String almacenId,
  }) {
    return ejecutarConSupabase(() async {
      final row = await _db
          .from('documentos')
          .insert({
            'tipo_documento': 'NS',
            'sucursal_id': sucursalId,
            'almacen_id': almacenId,
            'estado': 'BORRADOR',
            'creado_por': _db.auth.currentUser!.id,
          })
          .select()
          .single();
      return DocumentoVentaDraft.fromRow(row);
    });
  }

  Future<DocumentoVentaDraft> obtenerDocumento(String id) {
    return ejecutarConSupabase(() async {
      final row = await _db.from('documentos').select().eq('id', id).single();
      return DocumentoVentaDraft.fromRow(row);
    });
  }

  Future<List<LineaVentaDraft>> obtenerLineas(String documentoId) {
    return ejecutarConSupabase(() async {
      final rows = await _db
          .from('documento_lineas')
          .select('*, presentaciones(nombre)')
          .eq('documento_id', documentoId)
          .order('numero_linea');
      return [for (final row in rows) LineaVentaDraft.fromRow(row)];
    });
  }

  Future<ClienteResumen> obtenerClienteResumen(String id) {
    return ejecutarConSupabase(() async {
      final row = await _db
          .from('clientes')
          .select(
            'id, tipo_doc_identidad, numero_documento, razon_social, '
            'condicion_pago_id, limite_credito',
          )
          .eq('id', id)
          .single();
      return ClienteResumen.fromRow(row);
    });
  }

  Future<void> asignarCliente(String documentoId, ClienteResumen cliente) {
    return ejecutarConSupabase(() async {
      return _db
          .from('documentos')
          .update({
            'cliente_id': cliente.id,
            if (cliente.condicionPagoId != null)
              'condicion_pago_id': cliente.condicionPagoId,
          })
          .eq('id', documentoId);
    });
  }

  Future<void> asignarCondicionPago(
    String documentoId, {
    required String condicionId,
    required String formaPago,
  }) {
    return ejecutarConSupabase(() async {
      return _db
          .from('documentos')
          .update({'condicion_pago_id': condicionId, 'forma_pago': formaPago})
          .eq('id', documentoId);
    });
  }

  Future<void> actualizarFechaVencimiento(
    String documentoId,
    DateTime? vencimiento,
  ) {
    return ejecutarConSupabase(() async {
      return _db
          .from('documentos')
          .update({
            'fecha_vencimiento': vencimiento
                ?.toIso8601String()
                .split('T')
                .first,
          })
          .eq('id', documentoId);
    });
  }

  Future<void> asignarVendedor(String documentoId, String vendedorId) {
    return ejecutarConSupabase(() async {
      return _db
          .from('documentos')
          .update({'vendedor_id': vendedorId})
          .eq('id', documentoId);
    });
  }

  Future<void> asignarAlmacen(String documentoId, String almacenId) {
    return ejecutarConSupabase(() async {
      return _db
          .from('documentos')
          .update({'almacen_id': almacenId})
          .eq('id', documentoId);
    });
  }

  Future<LineaVentaDraft> agregarLinea({
    required String documentoId,
    required int numeroLinea,
    required ProductoBusqueda producto,
    required PresentacionOption presentacion,
  }) {
    return ejecutarConSupabase(() async {
      final row = await _db
          .from('documento_lineas')
          .insert({
            'documento_id': documentoId,
            'numero_linea': numeroLinea,
            'producto_id': producto.id,
            'presentacion_id': presentacion.id,
            'sku': producto.sku,
            'descripcion': producto.descripcion,
            'codigo_producto_sunat': producto.codigoProductoSunat,
            'unidad_medida': presentacion.unidadMedida,
            'cantidad': 0,
            'factor_conversion': presentacion.factor.toString(),
            'precio_unitario': 0,
            'afectacion_igv': producto.afectacionIgv,
            'tasa_igv': producto.tasaIgv.toString(),
            'coste_unitario_snapshot': producto.costeMedio.toString(),
          })
          .select('*, presentaciones(nombre)')
          .single();
      return LineaVentaDraft.fromRow(row);
    });
  }

  Future<void> actualizarLinea(String lineaId, Map<String, Object?> cambios) {
    return ejecutarConSupabase(() async {
      return _db.from('documento_lineas').update(cambios).eq('id', lineaId);
    });
  }

  Future<void> eliminarLinea(String lineaId) {
    return ejecutarConSupabase(() async {
      return _db.from('documento_lineas').delete().eq('id', lineaId);
    });
  }

  /// Ver `app.recalcular_totales` en `005_funciones_negocio.sql`.
  Future<DocumentoVentaDraft> recalcular(String documentoId) {
    return ejecutarConSupabase(() async {
      final row = await _db.rpc(
        'recalcular_documento',
        params: {'p_documento_id': documentoId},
      ) as Map<String, dynamic>;
      return DocumentoVentaDraft.fromRow(row);
    });
  }

  /// Ver `confirmar_documento()` en `005_funciones_negocio.sql`. Lanza
  /// `LimiteCreditoFailure` si el crédito no alcanza, o
  /// `ServidorFailure` con el texto del servidor (p. ej. stock
  /// insuficiente).
  Future<DocumentoVentaDraft> confirmar(String documentoId) {
    return ejecutarConSupabase(() async {
      final row = await _db.rpc(
        'confirmar_documento',
        params: {'p_documento_id': documentoId},
      ) as Map<String, dynamic>;
      return DocumentoVentaDraft.fromRow(row);
    });
  }

  /// Disponible en unidad base para un producto en un almacén, leído
  /// de `stock_actual` (ver `004_documentos_y_stock.sql`): el stock
  /// nunca se calcula en Dart, solo se lee lo que ya sumó la base de
  /// datos.
  Future<num> stockDisponible({
    required String almacenId,
    required String productoId,
  }) {
    return ejecutarConSupabase(() async {
      final row = await _db
          .from('stock_actual')
          .select('cantidad')
          .eq('almacen_id', almacenId)
          .eq('producto_id', productoId)
          .maybeSingle();
      return (row?['cantidad'] as num?) ?? 0;
    });
  }

  Future<List<ClienteResumen>> buscarClientes(String termino) {
    return ejecutarConSupabase(() async {
      if (termino.trim().isEmpty) return const [];
      final rows = await _db
          .from('clientes')
          .select(
            'id, tipo_doc_identidad, numero_documento, razon_social, '
            'condicion_pago_id, limite_credito',
          )
          .eq('activo', true)
          .or('razon_social.ilike.%$termino%,numero_documento.ilike.%$termino%')
          .order('razon_social')
          .limit(20);
      return [for (final row in rows) ClienteResumen.fromRow(row)];
    });
  }

  Future<List<ProductoBusqueda>> buscarProductos(String termino) {
    return ejecutarConSupabase(() async {
      if (termino.trim().isEmpty) return const [];
      final rows = await _db
          .from('productos')
          .select(
            'id, sku, descripcion, codigo_producto_sunat, afectacion_igv, coste_medio, '
            'cat_afectacion_igv(tasa_igv), '
            'presentaciones(id, codigo, nombre, unidad_medida, factor, es_default_venta, activo)',
          )
          .eq('activo', true)
          .or('sku.ilike.%$termino%,descripcion.ilike.%$termino%')
          .order('descripcion')
          .limit(20);
      return [for (final row in rows) ProductoBusqueda.fromRow(row)];
    });
  }
}
