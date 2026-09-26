// lib/ui/features/ventas/providers/venta_busqueda_providers.dart
//
// Búsquedas de solo lectura propias de "Nueva venta": no tocan el
// documento en edición (eso es `venta_form_view_model.dart`). El
// acceso a Supabase vive en `VentaRepository`.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../data/repository_providers.dart';
import '../../../../domain/models/venta_models.dart';

/// Término de búsqueda de cliente, confirmado (Enter / F3), no en
/// vivo por tecla: así lo pide el buscador de la grilla de líneas.
final clienteSearchQueryProvider = StateProvider<String>((ref) => '');

final clienteSearchResultsProvider = FutureProvider<List<ClienteResumen>>((
  ref,
) {
  return ref
      .watch(ventaRepositoryProvider)
      .buscarClientes(ref.watch(clienteSearchQueryProvider));
});

/// Término de búsqueda de producto (F3, última fila de la grilla).
final productoSearchQueryProvider = StateProvider<String>((ref) => '');

final productoSearchResultsProvider = FutureProvider<List<ProductoBusqueda>>((
  ref,
) {
  return ref
      .watch(ventaRepositoryProvider)
      .buscarProductos(ref.watch(productoSearchQueryProvider));
});
