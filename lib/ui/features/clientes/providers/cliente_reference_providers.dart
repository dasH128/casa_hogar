// lib/ui/features/clientes/view_models/cliente_reference_providers.dart
//
// Catálogos de solo lectura para la ficha de cliente. Vendedores y
// condiciones de pago se comparten con "Nueva venta" y viven en
// `state/catalogos_providers.dart`. El acceso a Supabase de estos dos
// vive en `ClienteRepository`.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/repositories/cliente_repository.dart';
import '../../../../domain/models/cliente_models.dart';

final _repository = ClienteRepository();

final tiposDocIdentidadProvider = FutureProvider<List<TipoDocIdentidadOption>>(
  (ref) => _repository.obtenerTiposDocIdentidad(),
);

final zonasProvider = FutureProvider<List<ZonaOption>>(
  (ref) => _repository.obtenerZonas(),
);
