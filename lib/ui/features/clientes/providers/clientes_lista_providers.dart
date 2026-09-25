// lib/ui/features/clientes/view_models/clientes_lista_providers.dart
//
// Listado de `/clientes`. RLS decide qué filas llegan: un vendedor
// solo ve los clientes sin asignar y los suyos (ver
// `008_rendimiento.sql`, política `clientes_read`). El acceso a
// Supabase vive en `ClienteRepository`.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../data/repositories/cliente_repository.dart';
import '../../../../domain/models/cliente_models.dart';

final _repository = ClienteRepository();

/// Término de búsqueda confirmado con Enter, igual que el buscador de
/// cliente de "Nueva venta".
final clientesListaQueryProvider = StateProvider<String>((ref) => '');

final clientesListaProvider = FutureProvider<List<ClienteListado>>((ref) {
  return _repository.listar(ref.watch(clientesListaQueryProvider));
});
