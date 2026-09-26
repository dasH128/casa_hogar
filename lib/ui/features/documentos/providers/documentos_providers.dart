// lib/ui/features/documentos/providers/documentos_providers.dart
//
// Consultas de solo lectura de `/documentos`. La pantalla no escribe
// nada, así que no tiene ViewModel (ver "Nombres" en
// `docs/ui-spec.md`). RLS decide qué documentos llegan: un vendedor
// solo ve los suyos y los sin vendedor asignado.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../data/repository_providers.dart';
import '../../../../domain/models/documento_models.dart';

/// Filtros de la tabla. La búsqueda se confirma con Enter; tipo,
/// estado y fechas se aplican al elegirlos.
final documentosQueryProvider = StateProvider<DocumentosQuery>(
  (ref) => DocumentosQuery.inicial(DateTime.now()),
);

final documentosListaProvider = FutureProvider<List<DocumentoListado>>((ref) {
  return ref
      .watch(documentosRepositoryProvider)
      .listar(ref.watch(documentosQueryProvider));
});

/// Tarjetas de arriba: no dependen de los filtros.
final documentosResumenProvider = FutureProvider<ResumenDocumentos>((ref) {
  return ref.watch(documentosRepositoryProvider).obtenerResumen();
});

final tiposDocumentoProvider = FutureProvider<List<TipoDocumentoOption>>((ref) {
  return ref.watch(documentosRepositoryProvider).obtenerTipos();
});
