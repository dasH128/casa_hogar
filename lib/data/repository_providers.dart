// lib/data/repository_providers.dart
//
// Inyección de dependencias de la capa de datos. ViewModels y
// providers leen los repositorios de aquí (`ref.read`/`ref.watch`) en
// lugar de construirlos, así un test puede sustituir cualquiera con
// `ProviderScope(overrides: [...])`.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'repositories/auth_repository.dart';
import 'repositories/catalogos_repository.dart';
import 'repositories/cliente_repository.dart';
import 'repositories/documentos_repository.dart';
import 'repositories/perfil_repository.dart';
import 'repositories/sesion_repository.dart';
import 'repositories/venta_repository.dart';

final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(supabaseClientProvider)),
);

final catalogosRepositoryProvider = Provider<CatalogosRepository>(
  (ref) => CatalogosRepository(ref.watch(supabaseClientProvider)),
);

final clienteRepositoryProvider = Provider<ClienteRepository>(
  (ref) => ClienteRepository(ref.watch(supabaseClientProvider)),
);

final documentosRepositoryProvider = Provider<DocumentosRepository>(
  (ref) => DocumentosRepository(ref.watch(supabaseClientProvider)),
);

final perfilRepositoryProvider = Provider<PerfilRepository>(
  (ref) => PerfilRepository(ref.watch(supabaseClientProvider)),
);

final sesionRepositoryProvider = Provider<SesionRepository>(
  (ref) => SesionRepository(ref.watch(supabaseClientProvider)),
);

final ventaRepositoryProvider = Provider<VentaRepository>(
  (ref) => VentaRepository(ref.watch(supabaseClientProvider)),
);
