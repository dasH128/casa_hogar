// lib/ui/features/clientes/providers/cliente_reference_providers.dart
//
// Catálogos de solo lectura para la ficha de cliente. Vendedores y
// condiciones de pago se comparten con "Nueva venta" y viven en
// `state/catalogos_providers.dart`. El acceso a Supabase de estos dos
// vive en `ClienteRepository`.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/repository_providers.dart';
import '../../../../domain/models/cliente_models.dart';

final tiposDocIdentidadProvider = FutureProvider<List<TipoDocIdentidadOption>>(
  (ref) => ref.watch(clienteRepositoryProvider).obtenerTiposDocIdentidad(),
);

final zonasProvider = FutureProvider<List<ZonaOption>>(
  (ref) => ref.watch(clienteRepositoryProvider).obtenerZonas(),
);
