// lib/ui/screens/clientes/widgets/cliente_cuenta_corriente_card.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../state/cliente_ficha_models.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/app_tokens.dart';
import '../../../widgets/amount_text.dart';
import '../../../widgets/data_table_shell.dart';
import '../../../widgets/status_pill.dart';

const _columnas = [
  DataTableColumn(label: 'Documento', width: FixedColumnWidth(140)),
  DataTableColumn(label: 'Emisión', width: FixedColumnWidth(92)),
  DataTableColumn(label: 'Vence', width: FixedColumnWidth(100)),
  DataTableColumn(label: 'Cuota', width: FlexColumnWidth()),
  DataTableColumn(
    label: 'Importe',
    width: FixedColumnWidth(110),
    numeric: true,
  ),
  DataTableColumn(label: 'Saldo', width: FixedColumnWidth(110), numeric: true),
  DataTableColumn(label: 'Estado', width: FixedColumnWidth(106)),
];

final _formatoFecha = DateFormat('dd/MM/yyyy');

/// Cuenta corriente al nivel de cuota, no de documento: una factura a
/// dos cuotas ocupa dos filas (ver `docs/ui-spec.md`).
class ClienteCuentaCorrienteCard extends StatelessWidget {
  const ClienteCuentaCorrienteCard({super.key, required this.cuotas});

  final List<CuotaCuentaCorriente> cuotas;

  @override
  Widget build(BuildContext context) {
    return DataTableShell(
      title: 'Cuenta corriente',
      columns: _columnas,
      rowCount: cuotas.length,
      cellBuilder: (context, row, column) =>
          _Celda(cuota: cuotas[row], column: column),
      trailingRow: cuotas.isEmpty ? const _SinMovimientos() : null,
    );
  }
}

class _Celda extends StatelessWidget {
  const _Celda({required this.cuota, required this.column});

  final CuotaCuentaCorriente cuota;
  final int column;

  @override
  Widget build(BuildContext context) {
    final cancelada = cuota.estado == EstadoCuota.cancelada;
    final colorBase = cancelada ? AppColor.inkDisabled : AppColor.ink;
    final colorSecundario = cancelada
        ? AppColor.inkDisabled
        : AppColor.inkMuted;

    return switch (column) {
      0 => Text(
        cuota.numeroDocumento,
        style: AppTheme.mono(size: 12.5, color: colorBase),
      ),
      1 => Text(
        _formatoFecha.format(cuota.fechaEmision),
        style: AppTheme.mono(size: 12.5, color: colorSecundario),
      ),
      2 => Text(
        _formatoFecha.format(cuota.fechaVencimiento),
        style: AppTheme.mono(size: 12.5, color: colorSecundario),
      ),
      3 => Text(
        '${cuota.numero} de ${cuota.totalCuotas}',
        style: TextStyle(fontSize: 12.5, color: colorSecundario),
      ),
      4 => AmountText(cuota.monto, fontSize: 12.5, color: colorBase),
      5 => AmountText(
        cuota.saldo,
        fontSize: 12.5,
        fontWeight: cancelada ? FontWeight.w400 : FontWeight.w500,
        color: switch (cuota.estado) {
          EstadoCuota.vencida => AppColor.danger,
          EstadoCuota.cancelada => AppColor.inkDisabled,
          EstadoCuota.porVencer => AppColor.ink,
        },
      ),
      _ => _EstadoCuotaPill(estado: cuota.estado),
    };
  }
}

class _EstadoCuotaPill extends StatelessWidget {
  const _EstadoCuotaPill({required this.estado});

  final EstadoCuota estado;

  @override
  Widget build(BuildContext context) {
    return switch (estado) {
      EstadoCuota.porVencer => const StatusPill(
        label: 'Por vencer',
        tone: AppStatusTone.info,
      ),
      EstadoCuota.vencida => const StatusPill(
        label: 'Vencida',
        tone: AppStatusTone.danger,
      ),
      EstadoCuota.cancelada => const StatusPill(
        label: 'Cancelada',
        tone: AppStatusTone.primary,
      ),
    };
  }
}

class _SinMovimientos extends StatelessWidget {
  const _SinMovimientos();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(AppSpace.cardPadding),
      child: Text(
        'Sin documentos a crédito.',
        style: TextStyle(fontSize: 12.5, color: AppColor.inkFaint),
      ),
    );
  }
}
