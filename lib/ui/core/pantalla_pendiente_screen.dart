// lib/ui/core/pantalla_pendiente_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../state/perfil_providers.dart';
import 'shell/app_shell.dart';
import 'theme/app_tokens.dart';

/// Placeholder para una ruta del rail que todavía no tiene pantalla
/// propia (`/compras`, `/documentos`, `/catalogo`,
/// `/usuarios`). Mantiene el `AppShell` real para poder navegar y ver
/// el rail funcionando mientras se construye cada pantalla.
class PantallaPendienteScreen extends ConsumerWidget {
  const PantallaPendienteScreen({
    super.key,
    required this.route,
    required this.titulo,
  });

  final String route;
  final String titulo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perfil = ref.watch(perfilActualProvider);

    return AppShell(
      activeRoute: route,
      userName: perfil?.nombre ?? '—',
      userRoleLabel: perfil?.rolLabel ?? '—',
      canView: perfil?.tienePermiso,
      onNavigate: (destino) => context.go(destino),
      headerChildren: [
        Text(titulo, style: Theme.of(context).textTheme.titleLarge),
      ],
      body: const Center(
        child: Text(
          'Todavía no hay pantalla aquí.',
          style: TextStyle(color: AppColor.inkFaint),
        ),
      ),
    );
  }
}
