// lib/ui/screens/clientes/clientes_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../state/clientes_lista_providers.dart';
import '../../../state/doc_identidad.dart';
import '../../../state/perfil_providers.dart';
import '../../shell/app_shell.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/amount_text.dart';
import '../../widgets/app_field.dart';
import '../../widgets/data_table_shell.dart';
import '../../widgets/status_pill.dart';

const _columnas = [
  DataTableColumn(label: 'Documento', width: FixedColumnWidth(150)),
  DataTableColumn(label: 'Razón social', width: FlexColumnWidth()),
  DataTableColumn(label: 'Zona', width: FixedColumnWidth(150)),
  DataTableColumn(label: 'Vendedor', width: FixedColumnWidth(130)),
  DataTableColumn(
    label: 'Límite crédito',
    width: FixedColumnWidth(130),
    numeric: true,
  ),
  DataTableColumn(label: 'Estado', width: FixedColumnWidth(106)),
];

/// Ruta `/clientes`. Listado de entrada a la ficha de cliente
/// (`/clientes/:id`, pantalla "6. Ficha de cliente" de
/// `docs/ui-spec.md`). No tiene artboard propio: se compone con los
/// mismos `AppShell`, `AppField` y `DataTableShell` del resto.
class ClientesScreen extends ConsumerWidget {
  const ClientesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perfil = ref.watch(perfilActualProvider);
    final clientes = ref.watch(clientesListaProvider);

    return AppShell(
      activeRoute: '/clientes',
      userName: perfil?.nombre ?? '—',
      userRoleLabel: perfil?.rolLabel ?? '—',
      canView: perfil?.tienePermiso,
      onNavigate: (route) => context.go(route),
      headerChildren: [
        Text('Clientes', style: Theme.of(context).textTheme.titleLarge),
        const Spacer(),
        if (perfil?.tienePermiso('clientes', 'create') ?? false)
          FilledButton(
            onPressed: () => context.go('/clientes/nuevo'),
            child: const Text('Nuevo cliente'),
          ),
      ],
      body: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.xl,
          vertical: AppSpace.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _Buscador(),
            const SizedBox(height: AppSpace.md),
            Expanded(
              child: clientes.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(
                  child: Text('No se pudo cargar el listado.\n$error'),
                ),
                data: (lista) => _TablaClientes(clientes: lista),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Buscador extends ConsumerWidget {
  const _Buscador();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Align(
      alignment: Alignment.centerLeft,
      child: SizedBox(
        width: AppSize.listSearchFieldWidth,
        child: AppField(
          label: 'Buscar',
          child: TextField(
            autofocus: true,
            style: AppField.textStyleFor(context),
            decoration: AppField.decoration().copyWith(
              hintText: 'Razón social o número de documento · Enter',
            ),
            onSubmitted: (termino) =>
                ref.read(clientesListaQueryProvider.notifier).state = termino,
          ),
        ),
      ),
    );
  }
}

class _TablaClientes extends StatelessWidget {
  const _TablaClientes({required this.clientes});

  final List<ClienteListado> clientes;

  @override
  Widget build(BuildContext context) {
    return DataTableShell(
      columns: _columnas,
      rowCount: clientes.length,
      onRowTap: (row) => context.go('/clientes/${clientes[row].id}'),
      cellBuilder: (context, row, column) =>
          _Celda(cliente: clientes[row], column: column),
      trailingRow: clientes.isEmpty ? const _SinResultados() : null,
    );
  }
}

class _Celda extends StatelessWidget {
  const _Celda({required this.cliente, required this.column});

  final ClienteListado cliente;
  final int column;

  @override
  Widget build(BuildContext context) {
    return switch (column) {
      0 => Text(
        '${abreviaturaDocIdentidad(cliente.tipoDocIdentidad)} '
        '${cliente.numeroDocumento}',
        style: AppTheme.mono(size: 12.5),
      ),
      1 => Text(
        cliente.razonSocial,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      2 => _TextoSecundario(cliente.zona),
      3 => _TextoSecundario(cliente.vendedor),
      4 => AmountText(cliente.limiteCredito, fontSize: 12.5),
      _ =>
        cliente.bloqueado
            ? const StatusPill(label: 'Bloqueado', tone: AppStatusTone.danger)
            : const StatusPill(label: 'Activo', tone: AppStatusTone.primary),
    };
  }
}

class _TextoSecundario extends StatelessWidget {
  const _TextoSecundario(this.texto);

  final String? texto;

  @override
  Widget build(BuildContext context) {
    return Text(
      texto ?? '—',
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 12.5, color: AppColor.inkMuted),
    );
  }
}

class _SinResultados extends StatelessWidget {
  const _SinResultados();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(AppSpace.cardPadding),
      child: Text(
        'No hay clientes que coincidan.',
        style: TextStyle(fontSize: 12.5, color: AppColor.inkFaint),
      ),
    );
  }
}
