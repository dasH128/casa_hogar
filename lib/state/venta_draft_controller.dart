// lib/state/venta_draft_controller.dart
//
// Estado mutable del documento de "Nueva venta" en edición. Cabecera
// y líneas se escriben directo a `documentos`/`documento_lineas`
// (permitido por RLS mientras el documento sigue en BORRADOR, ver
// `006_rls.sql`); los importes solo cambian cuando responde
// `recalcular_documento` o `confirmar_documento` — nunca se calculan
// aquí (ver la lista de "Lo que no debe hacer la interfaz" en
// `docs/ui-spec.md`).

import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'session_providers.dart';
import 'venta_draft_models.dart';
import 'venta_reference_providers.dart';

class VentaDraftState {
  const VentaDraftState({
    required this.documento,
    required this.lineas,
    this.clienteResumen,
    this.focusedLineIndex,
    this.stockDisponible,
    this.avisoCredito,
    this.guardando = false,
  });

  final DocumentoVentaDraft documento;
  final List<LineaVentaDraft> lineas;
  final ClienteResumen? clienteResumen;
  final int? focusedLineIndex;
  final Decimal? stockDisponible;

  /// Texto tal cual lo lanza `confirmar_documento()` cuando el crédito
  /// del cliente no alcanza (ver `docs/ui-spec.md`: "El aviso de
  /// crédito reproduce el texto del error... con los mismos números").
  final String? avisoCredito;
  final bool guardando;

  LineaVentaDraft? get lineaEnfocada =>
      focusedLineIndex == null ? null : lineas[focusedLineIndex!];

  VentaDraftState copyWith({
    DocumentoVentaDraft? documento,
    List<LineaVentaDraft>? lineas,
    ClienteResumen? clienteResumen,
    int? focusedLineIndex,
    bool clearFocusedLineIndex = false,
    Decimal? stockDisponible,
    String? avisoCredito,
    bool clearAvisoCredito = false,
    bool? guardando,
  }) {
    return VentaDraftState(
      documento: documento ?? this.documento,
      lineas: lineas ?? this.lineas,
      clienteResumen: clienteResumen ?? this.clienteResumen,
      focusedLineIndex: clearFocusedLineIndex
          ? null
          : (focusedLineIndex ?? this.focusedLineIndex),
      stockDisponible: stockDisponible ?? this.stockDisponible,
      avisoCredito: clearAvisoCredito
          ? null
          : (avisoCredito ?? this.avisoCredito),
      guardando: guardando ?? this.guardando,
    );
  }
}

class VentaDraftNotifier extends Notifier<AsyncValue<VentaDraftState>> {
  @override
  AsyncValue<VentaDraftState> build() => const AsyncValue.loading();

  SupabaseClient get _db => Supabase.instance.client;
  VentaDraftState get _current => state.requireValue;

  void _update(VentaDraftState Function(VentaDraftState) transform) {
    state = AsyncValue.data(transform(_current));
  }

  /// Crea el borrador si [documentoId] es nulo (ruta `/ventas/nueva`),
  /// o carga uno existente (`/ventas/:id`).
  Future<void> cargar(String? documentoId) async {
    state = const AsyncValue.loading();
    try {
      final documento = documentoId == null
          ? await _crearBorrador()
          : await _cargarDocumento(documentoId);
      final lineas = await _cargarLineas(documento.id);
      final cliente = documento.clienteId == null
          ? null
          : await _cargarCliente(documento.clienteId!);
      state = AsyncValue.data(
        VentaDraftState(
          documento: documento,
          lineas: lineas,
          clienteResumen: cliente,
        ),
      );
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<DocumentoVentaDraft> _crearBorrador() async {
    final sesion = ref.read(sesionProvider);
    if (sesion == null) {
      throw StateError(
        'No hay sucursal ni almacén elegidos: vuelve a /acceso.',
      );
    }
    final row = await _db
        .from('documentos')
        .insert({
          'tipo_documento': 'NS',
          'sucursal_id': sesion.sucursalId,
          'almacen_id': sesion.almacenId,
          'estado': 'BORRADOR',
          'creado_por': _db.auth.currentUser!.id,
        })
        .select()
        .single();
    return DocumentoVentaDraft.fromRow(row);
  }

  Future<DocumentoVentaDraft> _cargarDocumento(String id) async {
    final row = await _db.from('documentos').select().eq('id', id).single();
    return DocumentoVentaDraft.fromRow(row);
  }

  Future<List<LineaVentaDraft>> _cargarLineas(String documentoId) async {
    final rows = await _db
        .from('documento_lineas')
        .select('*, presentaciones(nombre)')
        .eq('documento_id', documentoId)
        .order('numero_linea');
    return [for (final row in rows) LineaVentaDraft.fromRow(row)];
  }

  Future<ClienteResumen> _cargarCliente(String id) async {
    final row = await _db
        .from('clientes')
        .select(
          'id, tipo_doc_identidad, numero_documento, razon_social, '
          'condicion_pago_id, limite_credito',
        )
        .eq('id', id)
        .single();
    return ClienteResumen.fromRow(row);
  }

  Future<void> seleccionarCliente(ClienteResumen cliente) async {
    await _db
        .from('documentos')
        .update({
          'cliente_id': cliente.id,
          if (cliente.condicionPagoId != null)
            'condicion_pago_id': cliente.condicionPagoId,
        })
        .eq('id', _current.documento.id);

    _update(
      (s) => s.copyWith(
        documento: s.documento.copyWith(
          clienteId: cliente.id,
          condicionPagoId: cliente.condicionPagoId,
        ),
        clienteResumen: cliente,
      ),
    );

    final condicionId = cliente.condicionPagoId;
    if (condicionId != null) await _aplicarCondicionPago(condicionId);
  }

  Future<void> seleccionarCondicionPago(CondicionPagoOption condicion) async {
    await _db
        .from('documentos')
        .update({
          'condicion_pago_id': condicion.id,
          'forma_pago': condicion.formaPago,
        })
        .eq('id', _current.documento.id);
    await _aplicarCondicionPago(condicion.id, condicion: condicion);
  }

  /// La fecha de vencimiento es emisión + días de crédito, o vacía en
  /// contado: aritmética de calendario, no de dinero (ver
  /// `docs/ui-spec.md`, pantalla "Nueva venta").
  Future<void> _aplicarCondicionPago(
    String condicionId, {
    CondicionPagoOption? condicion,
  }) async {
    condicion ??= (await ref.read(condicionesPagoProvider.future))
        .firstWhere((c) => c.id == condicionId);

    final vencimiento = condicion.formaPago == 'CREDITO'
        ? _current.documento.fechaEmision.add(
            Duration(days: condicion.diasCredito),
          )
        : null;

    await _db
        .from('documentos')
        .update({
          'fecha_vencimiento': vencimiento?.toIso8601String().split('T').first,
        })
        .eq('id', _current.documento.id);

    _update(
      (s) => s.copyWith(
        documento: s.documento.copyWith(
          condicionPagoId: condicionId,
          formaPago: condicion!.formaPago,
          fechaVencimiento: vencimiento,
          clearFechaVencimiento: vencimiento == null,
        ),
      ),
    );
  }

  Future<void> seleccionarVendedor(VendedorOption vendedor) async {
    await _db
        .from('documentos')
        .update({'vendedor_id': vendedor.id})
        .eq('id', _current.documento.id);
    _update(
      (s) =>
          s.copyWith(documento: s.documento.copyWith(vendedorId: vendedor.id)),
    );
  }

  Future<void> seleccionarAlmacen(AlmacenOption almacen) async {
    await _db
        .from('documentos')
        .update({'almacen_id': almacen.almacenId})
        .eq('id', _current.documento.id);
    _update(
      (s) => s.copyWith(
        documento: s.documento.copyWith(almacenId: almacen.almacenId),
      ),
    );
  }

  Future<void> agregarLinea(
    ProductoBusqueda producto,
    PresentacionOption presentacion,
  ) async {
    final numeroLinea =
        _current.lineas.fold<int>(
          0,
          (max, l) => l.numeroLinea > max ? l.numeroLinea : max,
        ) +
        1;

    final row = await _db
        .from('documento_lineas')
        .insert({
          'documento_id': _current.documento.id,
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

    final linea = LineaVentaDraft.fromRow(row);
    _update((s) => s.copyWith(lineas: [...s.lineas, linea]));
    ref.read(productoSearchQueryProvider.notifier).state = '';
  }

  Future<void> actualizarLinea(
    int index, {
    Decimal? cantidad,
    Decimal? precioUnitario,
    Decimal? dto1Pct,
  }) async {
    final linea = _current.lineas[index];
    final cambios = <String, Object?>{
      if (cantidad != null) 'cantidad': cantidad.toString(),
      if (precioUnitario != null) 'precio_unitario': precioUnitario.toString(),
      if (dto1Pct != null) 'dto1_pct': dto1Pct.toString(),
    };
    if (cambios.isEmpty) return;

    await _db.from('documento_lineas').update(cambios).eq('id', linea.id!);

    final lineas = [..._current.lineas];
    lineas[index] = linea.copyWith(
      cantidad: cantidad,
      precioUnitario: precioUnitario,
      dto1Pct: dto1Pct,
    );
    _update((s) => s.copyWith(lineas: lineas));

    await recalcular();
  }

  Future<void> eliminarLinea(int index) async {
    final linea = _current.lineas[index];
    if (linea.id != null) {
      await _db.from('documento_lineas').delete().eq('id', linea.id!);
    }

    final lineas = [..._current.lineas]..removeAt(index);
    _update(
      (s) => s.copyWith(
        lineas: lineas,
        clearFocusedLineIndex: s.focusedLineIndex == index,
      ),
    );
    if (lineas.isNotEmpty) await recalcular();
  }

  /// Vuelve a pedirle a la base de datos los importes de cabecera y
  /// de cada línea: es el único sitio de donde salen (ver
  /// `app.recalcular_totales` en `005_funciones_negocio.sql`).
  Future<void> recalcular() async {
    final documentoId = _current.documento.id;
    final row = await _db.rpc(
      'recalcular_documento',
      params: {'p_documento_id': documentoId},
    ) as Map<String, dynamic>;
    final documento = DocumentoVentaDraft.fromRow(row);
    final lineas = await _cargarLineas(documentoId);
    _update((s) => s.copyWith(documento: documento, lineas: lineas));
  }

  /// El panel de stock sigue a la línea con el foco.
  Future<void> enfocarLinea(int? index) async {
    _update(
      (s) => s.copyWith(
        focusedLineIndex: index,
        clearFocusedLineIndex: index == null,
      ),
    );
    if (index == null) return;

    final linea = _current.lineas[index];
    final disponible = await stockDisponible(
      almacenId: _current.documento.almacenId,
      productoId: linea.productoId,
    );
    _update((s) => s.copyWith(stockDisponible: parseDecimal(disponible)));
  }

  /// Confirma el documento. Si `confirmar_documento()` rechaza por
  /// límite de crédito, el mensaje del servidor pasa tal cual a
  /// [VentaDraftState.avisoCredito]; cualquier otro error se relanza
  /// para que la pantalla lo muestre.
  Future<void> confirmar() async {
    _update((s) => s.copyWith(guardando: true, clearAvisoCredito: true));
    try {
      final row = await _db.rpc(
        'confirmar_documento',
        params: {'p_documento_id': _current.documento.id},
      ) as Map<String, dynamic>;
      final documento = DocumentoVentaDraft.fromRow(row);
      _update((s) => s.copyWith(documento: documento, guardando: false));
    } on PostgrestException catch (e) {
      if (e.message.contains('Límite de crédito excedido')) {
        _update((s) => s.copyWith(avisoCredito: e.message, guardando: false));
        return;
      }
      _update((s) => s.copyWith(guardando: false));
      rethrow;
    }
  }
}

final ventaDraftProvider =
    NotifierProvider<VentaDraftNotifier, AsyncValue<VentaDraftState>>(
      VentaDraftNotifier.new,
    );
