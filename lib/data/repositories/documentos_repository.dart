// lib/data/repositories/documentos_repository.dart
//
// Acceso a Supabase de la pantalla Documentos: la vista
// `documentos_listado`, `resumen_documentos()` y el catálogo de tipos
// para el filtro (ver `013_documentos_listado.sql`).

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/documento_models.dart';
import '../supabase_errors.dart';

const _limiteFilas = 500;

class DocumentosRepository {
  DocumentosRepository(this._db);

  final SupabaseClient _db;

  Future<List<DocumentoListado>> listar(DocumentosQuery query) {
    return ejecutarConSupabase(() async {
      var consulta = _db
          .from('documentos_listado')
          .select()
          .gte('fecha_emision', _fecha(query.desde))
          .lte('fecha_emision', _fecha(query.hasta));

      final tipo = query.tipoDocumento;
      if (tipo != null) consulta = consulta.eq('tipo_documento', tipo);

      final estado = query.estado;
      if (estado != null) consulta = consulta.eq('estado', estado);

      final termino = _terminoSeguro(query.termino);
      if (termino.isNotEmpty) {
        consulta = consulta.or(
          'numero.ilike.%$termino%,'
          'tercero.ilike.%$termino%,'
          'tercero_numero_doc.ilike.%$termino%',
        );
      }

      final rows = await consulta
          .order('fecha_emision', ascending: false)
          .order('numero', ascending: false)
          .limit(_limiteFilas);
      return [for (final row in rows) DocumentoListado.fromRow(row)];
    });
  }

  Future<ResumenDocumentos> obtenerResumen() {
    return ejecutarConSupabase(() async {
      final json = await _db.rpc('resumen_documentos');
      return ResumenDocumentos.fromJson(json as Map<String, dynamic>);
    });
  }

  Future<List<TipoDocumentoOption>> obtenerTipos() {
    return ejecutarConSupabase(() async {
      final rows = await _db
          .from('tipos_documento')
          .select('codigo, nombre')
          .eq('activo', true)
          .order('codigo');
      return [for (final row in rows) TipoDocumentoOption.fromRow(row)];
    });
  }

  String _fecha(DateTime dia) => dia.toIso8601String().split('T').first;

  /// Comas y paréntesis rompen la sintaxis del filtro `or` de PostgREST.
  String _terminoSeguro(String termino) =>
      termino.replaceAll(RegExp(r'[,()]'), ' ').trim();
}
