// lib/ui/widgets/data_table_shell.dart

import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import 'field_label.dart';

/// Columna de un [DataTableShell]. [width] fija el ancho como en la
/// grilla de línea de un documento; [numeric] alinea a la derecha.
class DataTableColumn {
  const DataTableColumn({
    required this.label,
    required this.width,
    this.numeric = false,
  });

  final String label;
  final TableColumnWidth width;
  final bool numeric;
}

/// Reemplazo de `DataTable` de Material para grillas densas: controla
/// el alto de fila y no repagina la cabecera, cosas que `DataTable`
/// no permite (ver `docs/ui-spec.md`).
class DataTableShell extends StatelessWidget {
  const DataTableShell({
    super.key,
    required this.columns,
    required this.rowCount,
    required this.cellBuilder,
    this.title,
    this.onRowTap,
    this.activeRowIndex,
    this.compact = false,
    this.trailingRow,
    this.footer,
  });

  final List<DataTableColumn> columns;
  final int rowCount;

  /// Construye la celda de la fila [row], columna [column].
  final Widget Function(BuildContext context, int row, int column) cellBuilder;

  /// Rótulo de sección sobre la cabecera, dentro de la misma tarjeta
  /// (p. ej. "Cuenta corriente" en la ficha de cliente).
  final String? title;

  /// Si se indica, cada fila de datos es clicable (p. ej. un listado
  /// que abre la ficha de la fila).
  final ValueChanged<int>? onRowTap;

  /// Fila con el cursor: se pinta con `AppColor.rowActive`.
  final int? activeRowIndex;

  /// Filas de 30 px (grilla de compras) en lugar de 36 px.
  final bool compact;

  /// Fila libre añadida tras la última fila de datos, dentro del mismo
  /// scroll (p. ej. el buscador de producto de la grilla de venta). A
  /// diferencia de las filas de [cellBuilder], no sigue el grid de
  /// columnas: el contenido decide su propio layout.
  final Widget? trailingRow;

  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final rowHeight = compact
        ? AppSize.compactRowHeight
        : AppSize.tableRowHeight;
    final columnWidths = <int, TableColumnWidth>{
      for (var i = 0; i < columns.length; i++) i: columns[i].width,
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColor.surface,
        border: Border.all(color: AppColor.line),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Column(
          children: [
            if (title != null) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.cardPadding,
                  AppSpace.md,
                  AppSpace.cardPadding,
                  12,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FieldLabel(title!),
                ),
              ),
              const ColoredBox(
                color: AppColor.line,
                child: SizedBox(height: 1, width: double.infinity),
              ),
            ],
            Table(
              columnWidths: columnWidths,
              children: [
                TableRow(
                  decoration: const BoxDecoration(color: AppColor.tableHeader),
                  children: [
                    for (final column in columns)
                      _HeaderCell(label: column.label, numeric: column.numeric),
                  ],
                ),
              ],
            ),
            const ColoredBox(
              color: AppColor.line,
              child: SizedBox(height: 1, width: double.infinity),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Table(
                      columnWidths: columnWidths,
                      children: [
                        for (var row = 0; row < rowCount; row++)
                          TableRow(
                            decoration: BoxDecoration(
                              color: row == activeRowIndex
                                  ? AppColor.rowActive
                                  : null,
                              border: const Border(
                                bottom: BorderSide(color: AppColor.lineSoft),
                              ),
                            ),
                            children: [
                              for (
                                var column = 0;
                                column < columns.length;
                                column++
                              )
                                _TappableCell(
                                  onTap: onRowTap == null
                                      ? null
                                      : () => onRowTap!(row),
                                  child: SizedBox(
                                    height: rowHeight,
                                    child: Align(
                                      alignment: columns[column].numeric
                                          ? Alignment.centerRight
                                          : Alignment.centerLeft,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: AppSpace.sm,
                                        ),
                                        child: cellBuilder(
                                          context,
                                          row,
                                          column,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                      ],
                    ),
                    ?trailingRow,
                  ],
                ),
              ),
            ),
            if (footer != null)
              DecoratedBox(
                decoration: const BoxDecoration(
                  color: AppColor.surfaceAlt,
                  border: Border(top: BorderSide(color: AppColor.line)),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: AppSpace.sm,
                  ),
                  child: footer,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// `TableRow` no admite gestos: el clic de fila se reparte en cada
/// celda, con el mismo callback, y sin efecto si [onTap] es null.
class _TappableCell extends StatelessWidget {
  const _TappableCell({required this.onTap, required this.child});

  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (onTap == null) return child;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: child,
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell({required this.label, required this.numeric});

  final String label;
  final bool numeric;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm, vertical: 9),
      child: Align(
        alignment: numeric ? Alignment.centerRight : Alignment.centerLeft,
        child: Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
            color: AppColor.inkMuted,
          ),
        ),
      ),
    );
  }
}
