// lib/ui/features/ventas/views/widgets/venta_lineas_card.dart

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../domain/models/venta_models.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/amount_text.dart';
import '../../../../core/widgets/data_table_shell.dart';
import '../../providers/venta_busqueda_providers.dart';
import '../../view_models/venta_draft_view_model.dart';

const _columnas = [
  DataTableColumn(label: '#', width: FixedColumnWidth(34), numeric: true),
  DataTableColumn(label: 'SKU', width: FixedColumnWidth(62)),
  DataTableColumn(label: 'Descripción', width: FlexColumnWidth()),
  DataTableColumn(label: 'Present.', width: FixedColumnWidth(92)),
  DataTableColumn(label: 'Cant.', width: FixedColumnWidth(72), numeric: true),
  DataTableColumn(label: 'Precio', width: FixedColumnWidth(86), numeric: true),
  DataTableColumn(label: 'Dto %', width: FixedColumnWidth(56), numeric: true),
  DataTableColumn(label: 'Importe', width: FixedColumnWidth(96), numeric: true),
];

/// Grilla de líneas del documento + buscador de producto, tal como
/// `design/artboards/Main.dc.html`.
class VentaLineasCard extends ConsumerStatefulWidget {
  const VentaLineasCard({
    super.key,
    required this.state,
    required this.buscadorFocus,
  });

  final VentaDraftState state;
  final FocusNode buscadorFocus;

  @override
  ConsumerState<VentaLineasCard> createState() => _VentaLineasCardState();
}

class _VentaLineasCardState extends ConsumerState<VentaLineasCard> {
  final _buscadorController = TextEditingController();
  final _focusNodes = <String, FocusNode>{};

  @override
  void dispose() {
    _buscadorController.dispose();
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  FocusNode? _focusNodeFor(int row, int column) {
    if (row < 0 || row >= widget.state.lineas.length) return null;
    return _focusNodes.putIfAbsent('$row-$column', () {
      final node = FocusNode();
      node.addListener(() {
        if (node.hasFocus) {
          ref.read(ventaDraftProvider.notifier).enfocarLinea(row);
        }
      });
      return node;
    });
  }

  void _guardarCantidad(int row, String texto) {
    final valor = Decimal.tryParse(texto);
    if (valor != null) {
      ref
          .read(ventaDraftProvider.notifier)
          .actualizarLinea(row, cantidad: valor);
    }
  }

  void _guardarPrecio(int row, String texto) {
    final valor = Decimal.tryParse(texto);
    if (valor != null) {
      ref
          .read(ventaDraftProvider.notifier)
          .actualizarLinea(row, precioUnitario: valor);
    }
  }

  void _guardarDescuento(int row, String texto) {
    final valor = texto.trim().isEmpty ? Decimal.zero : Decimal.tryParse(texto);
    if (valor != null) {
      ref
          .read(ventaDraftProvider.notifier)
          .actualizarLinea(row, dto1Pct: valor);
    }
  }

  void _avanzar(BuildContext context) => FocusScope.of(context).nextFocus();

  void _ejecutarBusquedaProducto() {
    ref.read(productoSearchQueryProvider.notifier).state =
        _buscadorController.text;
  }

  Future<void> _elegirProducto(ProductoBusqueda producto) async {
    final presentacion = producto.presentacionSugerida;
    if (presentacion == null) return;
    await ref
        .read(ventaDraftProvider.notifier)
        .agregarLinea(producto, presentacion);
    _buscadorController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final lineas = widget.state.lineas;
    final unidadesBase = lineas.fold<Decimal>(
      Decimal.zero,
      (acc, l) => acc + l.cantidadBase,
    );
    final modoDescuento = widget.state.documento.modoDescuento.toLowerCase();

    return Stack(
      fit: StackFit.expand,
      children: [
        DataTableShell(
          columns: _columnas,
          rowCount: lineas.length,
          activeRowIndex: widget.state.focusedLineIndex,
          cellBuilder: (context, row, column) =>
              _celda(context, lineas[row], row, column),
          trailingRow: _filaBuscador(),
          footer: Row(
            children: [
              Text(
                '${lineas.length} líneas',
                style: const TextStyle(color: AppColor.inkMuted),
              ),
              const SizedBox(width: AppSpace.md),
              Text(
                '${unidadesBase.toStringAsFixed(0)} unidades base',
                style: const TextStyle(color: AppColor.inkMuted),
              ),
              const SizedBox(width: AppSpace.md),
              Text(
                'Descuento aplicado: $modoDescuento',
                style: const TextStyle(color: AppColor.inkMuted),
              ),
            ],
          ),
        ),
        ListenableBuilder(
          listenable: widget.buscadorFocus,
          builder: (context, _) {
            if (!widget.buscadorFocus.hasFocus) return const SizedBox.shrink();
            final resultados = ref.watch(productoSearchResultsProvider);
            return resultados.maybeWhen(
              data: (productos) {
                if (productos.isEmpty) return const SizedBox.shrink();
                return Positioned(
                  left: AppSpace.sm,
                  right: AppSpace.sm,
                  bottom: AppSize.keyBarHeight,
                  child: _ResultadosProducto(
                    productos: productos,
                    onElegir: _elegirProducto,
                  ),
                );
              },
              orElse: () => const SizedBox.shrink(),
            );
          },
        ),
      ],
    );
  }

  Widget _celda(
    BuildContext context,
    LineaVentaDraft linea,
    int row,
    int column,
  ) {
    switch (column) {
      case 0:
        return Text(
          '${row + 1}',
          style: AppTheme.mono(color: AppColor.inkDisabled),
        );
      case 1:
        return Text(linea.sku, style: AppTheme.mono());
      case 2:
        return Text(linea.descripcion, overflow: TextOverflow.ellipsis);
      case 3:
        return Text(
          linea.presentacionNombre,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: AppColor.inkMuted),
        );
      case 4:
        return _celdaNumerica(
          key: 'cantidad-${linea.id}',
          focusNode: _focusNodeFor(row, 0)!,
          valorInicial: linea.cantidad.toStringAsFixed(3),
          onSubmit: (texto) {
            _guardarCantidad(row, texto);
            _avanzar(context);
          },
          onArrowRow: (delta) => _focusNodeFor(row + delta, 0)?.requestFocus(),
        );
      case 5:
        return _celdaNumerica(
          key: 'precio-${linea.id}',
          focusNode: _focusNodeFor(row, 1)!,
          valorInicial: linea.precioUnitario.toStringAsFixed(4),
          onSubmit: (texto) {
            _guardarPrecio(row, texto);
            _avanzar(context);
          },
          onArrowRow: (delta) => _focusNodeFor(row + delta, 1)?.requestFocus(),
        );
      case 6:
        return _celdaNumerica(
          key: 'dto-${linea.id}',
          focusNode: _focusNodeFor(row, 2)!,
          valorInicial: linea.dto1Pct == Decimal.zero
              ? ''
              : linea.dto1Pct.toStringAsFixed(2),
          hintText: '—',
          onSubmit: (texto) {
            _guardarDescuento(row, texto);
            _avanzar(context);
          },
          onArrowRow: (delta) => _focusNodeFor(row + delta, 2)?.requestFocus(),
        );
      case 7:
        return AmountText(linea.totalLinea, fontWeight: FontWeight.w500);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _celdaNumerica({
    required String key,
    required FocusNode focusNode,
    required String valorInicial,
    required ValueChanged<String> onSubmit,
    required ValueChanged<int> onArrowRow,
    String? hintText,
  }) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
            onArrowRow(1),
        const SingleActivator(LogicalKeyboardKey.arrowUp): () => onArrowRow(-1),
      },
      child: TextFormField(
        key: ValueKey(key),
        focusNode: focusNode,
        initialValue: valorInicial,
        textAlign: TextAlign.right,
        textInputAction: TextInputAction.next,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: AppTheme.mono(),
        decoration: InputDecoration(
          isDense: true,
          isCollapsed: true,
          hintText: hintText,
          hintStyle: AppTheme.mono(color: AppColor.inkDisabled),
          border: InputBorder.none,
        ),
        onFieldSubmitted: onSubmit,
      ),
    );
  }

  Widget _filaBuscador() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm, vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: Text(
              '${widget.state.lineas.length + 1}',
              textAlign: TextAlign.right,
              style: AppTheme.mono(color: AppColor.inkDisabled),
            ),
          ),
          const SizedBox(width: AppSpace.sm),
          CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.f3):
                  _ejecutarBusquedaProducto,
            },
            child: SizedBox(
              width: 300,
              height: AppSize.lineSearchFieldHeight,
              child: TextField(
                controller: _buscadorController,
                focusNode: widget.buscadorFocus,
                style: const TextStyle(fontSize: 12.5),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Código, modelo o descripción…',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.field),
                    borderSide: const BorderSide(color: AppColor.primary),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.field),
                    borderSide: const BorderSide(color: AppColor.primary),
                  ),
                ),
                onSubmitted: (_) => _ejecutarBusquedaProducto(),
              ),
            ),
          ),
          const SizedBox(width: AppSpace.sm),
          const Text(
            'F3 para buscar · Enter pasa al siguiente campo',
            style: TextStyle(fontSize: 11, color: AppColor.inkFaint),
          ),
        ],
      ),
    );
  }
}

class _ResultadosProducto extends StatelessWidget {
  const _ResultadosProducto({required this.productos, required this.onElegir});

  final List<ProductoBusqueda> productos;
  final ValueChanged<ProductoBusqueda> onElegir;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 220),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColor.surface,
            border: Border.all(color: AppColor.line),
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: productos.length,
            separatorBuilder: (_, _) =>
                const Divider(height: 1, color: AppColor.lineSoft),
            itemBuilder: (context, index) {
              final producto = productos[index];
              return ListTile(
                dense: true,
                title: Text(
                  producto.descripcion,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${producto.sku} · ${producto.presentacionSugerida?.nombre ?? 'sin presentación'}',
                  style: AppTheme.mono(size: 11, color: AppColor.inkMuted),
                ),
                onTap: () => onElegir(producto),
              );
            },
          ),
        ),
      ),
    );
  }
}
