// lib/ui/features/documentos/views/documentos_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../state/perfil_providers.dart';
import '../../../core/shell/app_shell.dart';
import '../../../core/theme/app_tokens.dart';
import '../providers/documentos_providers.dart';
import 'widgets/documentos_filtros_card.dart';
import 'widgets/documentos_resumen_card.dart';
import 'widgets/documentos_tabla_card.dart';

/// Ruta `/documentos`. Ver `docs/ui-spec.md`, pantalla "3. Documentos".
/// Listado de solo lectura: observa los providers de `providers/`
/// directamente, sin ViewModel.
class DocumentosScreen extends ConsumerWidget {
  const DocumentosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perfil = ref.watch(perfilActualProvider);
    final resumen = ref.watch(documentosResumenProvider).value;
    final documentos = ref.watch(documentosListaProvider);

    return AppShell(
      activeRoute: '/documentos',
      userName: perfil?.nombre ?? '—',
      userRoleLabel: perfil?.rolLabel ?? '—',
      canView: perfil?.tienePermiso,
      onNavigate: (route) => context.go(route),
      headerChildren: [
        Text('Documentos', style: Theme.of(context).textTheme.titleLarge),
        const Spacer(),
        const Tooltip(
          message: 'Exportar a CSV: pendiente de implementar',
          child: OutlinedButton(onPressed: null, child: Text('Exportar')),
        ),
        if (perfil?.tienePermiso('ventas', 'create') ?? false)
          FilledButton(
            onPressed: () => context.go('/ventas/nueva'),
            child: const Text('Nueva venta'),
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
            DocumentosResumenCard(resumen: resumen),
            const SizedBox(height: AppSpace.md),
            const DocumentosFiltrosCard(),
            const SizedBox(height: AppSpace.md),
            Expanded(
              child: documentos.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(
                  child: Text('No se pudo cargar los documentos.\n$error'),
                ),
                data: (lista) => DocumentosTablaCard(documentos: lista),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
