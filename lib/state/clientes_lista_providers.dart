// lib/state/clientes_lista_providers.dart
//
// Listado de `/clientes`. RLS decide qué filas llegan: un vendedor
// solo ve los clientes sin asignar y los suyos (ver
// `008_rendimiento.sql`, política `clientes_read`).

import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'venta_draft_models.dart';

const _limiteFilas = 200;

class ClienteListado {
  const ClienteListado({
    required this.id,
    required this.tipoDocIdentidad,
    required this.numeroDocumento,
    required this.razonSocial,
    required this.zona,
    required this.vendedor,
    required this.limiteCredito,
    required this.monedaCredito,
    required this.bloqueado,
  });

  factory ClienteListado.fromRow(Map<String, dynamic> row) {
    final zona = row['zonas'] as Map<String, dynamic>?;
    final vendedor = row['vendedores'] as Map<String, dynamic>?;
    return ClienteListado(
      id: row['id'] as String,
      tipoDocIdentidad: row['tipo_doc_identidad'] as String,
      numeroDocumento: row['numero_documento'] as String,
      razonSocial: row['razon_social'] as String,
      zona: zona?['nombre'] as String?,
      vendedor: vendedor?['nombre'] as String?,
      limiteCredito: parseDecimal(row['limite_credito']),
      monedaCredito: row['moneda_credito'] as String,
      bloqueado: row['bloqueado'] as bool,
    );
  }

  final String id;
  final String tipoDocIdentidad;
  final String numeroDocumento;
  final String razonSocial;
  final String? zona;
  final String? vendedor;
  final Decimal limiteCredito;
  final String monedaCredito;
  final bool bloqueado;
}

/// Término de búsqueda confirmado con Enter, igual que el buscador de
/// cliente de "Nueva venta".
final clientesListaQueryProvider = StateProvider<String>((ref) => '');

final clientesListaProvider = FutureProvider<List<ClienteListado>>((ref) async {
  final termino = _terminoSeguro(ref.watch(clientesListaQueryProvider));

  var query = Supabase.instance.client
      .from('clientes')
      .select(
        'id, tipo_doc_identidad, numero_documento, razon_social, '
        'limite_credito, moneda_credito, bloqueado, '
        'zonas(nombre), vendedores(nombre)',
      )
      .eq('activo', true);
  if (termino.isNotEmpty) {
    query = query.or(
      'razon_social.ilike.%$termino%,numero_documento.ilike.%$termino%',
    );
  }

  final rows = await query.order('razon_social').limit(_limiteFilas);
  return [for (final row in rows) ClienteListado.fromRow(row)];
});

/// Comas y paréntesis rompen la sintaxis del filtro `or` de PostgREST.
String _terminoSeguro(String termino) =>
    termino.replaceAll(RegExp(r'[,()]'), ' ').trim();
