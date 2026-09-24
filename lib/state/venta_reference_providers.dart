// lib/state/venta_reference_providers.dart
//
// Catálogos y búsquedas de solo lectura para "Nueva venta": no tocan
// el documento en edición (eso es `venta_draft_controller.dart`).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'venta_draft_models.dart';

/// Condiciones de pago activas, para el desplegable de cabecera.
final condicionesPagoProvider = FutureProvider<List<CondicionPagoOption>>((
  ref,
) async {
  final rows = await Supabase.instance.client
      .from('condiciones_pago')
      .select('id, codigo, nombre, forma_pago, dias_credito')
      .eq('activo', true)
      .order('nombre');

  return [for (final row in rows) CondicionPagoOption.fromRow(row)];
});

/// Vendedores activos, para el desplegable de cabecera.
final vendedoresProvider = FutureProvider<List<VendedorOption>>((ref) async {
  final rows = await Supabase.instance.client
      .from('vendedores')
      .select('id, codigo, nombre')
      .eq('activo', true)
      .order('nombre');

  return [for (final row in rows) VendedorOption.fromRow(row)];
});

/// Término de búsqueda de cliente, confirmado (Enter / F3), no en
/// vivo por tecla: así lo pide el buscador de la grilla de líneas.
final clienteSearchQueryProvider = StateProvider<String>((ref) => '');

final clienteSearchResultsProvider = FutureProvider<List<ClienteResumen>>((
  ref,
) async {
  final termino = ref.watch(clienteSearchQueryProvider).trim();
  if (termino.isEmpty) return const [];

  final rows = await Supabase.instance.client
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

/// Término de búsqueda de producto (F3, última fila de la grilla).
final productoSearchQueryProvider = StateProvider<String>((ref) => '');

final productoSearchResultsProvider = FutureProvider<List<ProductoBusqueda>>((
  ref,
) async {
  final termino = ref.watch(productoSearchQueryProvider).trim();
  if (termino.isEmpty) return const [];

  final rows = await Supabase.instance.client
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

/// Disponible en unidad base para un producto en un almacén, leído de
/// `stock_actual` (ver `004_documentos_y_stock.sql`): el stock nunca
/// se calcula en Dart, solo se lee lo que ya sumó la base de datos.
Future<num> stockDisponible({
  required String almacenId,
  required String productoId,
}) async {
  final row = await Supabase.instance.client
      .from('stock_actual')
      .select('cantidad')
      .eq('almacen_id', almacenId)
      .eq('producto_id', productoId)
      .maybeSingle();

  return (row?['cantidad'] as num?) ?? 0;
}
