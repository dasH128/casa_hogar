// lib/routing/app_router.dart
//
// Rutas de la app. `/acceso` es la única sin sesión; el resto exige
// una sesión de Supabase viva — si no la hay, `redirect` manda de
// vuelta a `/acceso` antes de construir la pantalla.
//
// No cubre restaurar sucursal/almacén (`state/session_providers.dart`)
// ni el perfil (`state/perfil_providers.dart`) tras un refresco de
// página con una sesión ya persistida por Supabase: eso vive solo en
// memoria y se pierde. Con la sesión viva pero sin esos datos, la
// pantalla que los necesite (p. ej. `VentaFormScreen`) lo dice con un
// mensaje de error en vez de romper, pero hay que volver a `/acceso`.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../ui/screens/auth/acceso_screen.dart';
import '../ui/screens/pantalla_pendiente_screen.dart';
import '../ui/screens/ventas/venta_form_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/acceso',
  refreshListenable: GoRouterRefreshStream(
    Supabase.instance.client.auth.onAuthStateChange,
  ),
  redirect: (context, state) {
    final autenticado = Supabase.instance.client.auth.currentSession != null;
    final enAcceso = state.matchedLocation == '/acceso';
    if (!autenticado) return enAcceso ? null : '/acceso';
    return null;
  },
  routes: [
    GoRoute(path: '/acceso', builder: (context, state) => const AccesoScreen()),
    GoRoute(
      path: '/ventas/nueva',
      builder: (context, state) => const VentaFormScreen(),
    ),
    GoRoute(
      path: '/ventas/:id',
      builder: (context, state) =>
          VentaFormScreen(documentoId: state.pathParameters['id']),
    ),
    GoRoute(
      path: '/compras',
      builder: (context, state) =>
          const PantallaPendienteScreen(route: '/compras', titulo: 'Compras'),
    ),
    GoRoute(
      path: '/documentos',
      builder: (context, state) => const PantallaPendienteScreen(
        route: '/documentos',
        titulo: 'Documentos',
      ),
    ),
    GoRoute(
      path: '/catalogo',
      builder: (context, state) =>
          const PantallaPendienteScreen(route: '/catalogo', titulo: 'Catálogo'),
    ),
    GoRoute(
      path: '/clientes',
      builder: (context, state) =>
          const PantallaPendienteScreen(route: '/clientes', titulo: 'Clientes'),
    ),
    GoRoute(
      path: '/usuarios',
      builder: (context, state) =>
          const PantallaPendienteScreen(route: '/usuarios', titulo: 'Usuarios'),
    ),
  ],
);

/// Receta estándar de `go_router`: reevalúa `redirect` cada vez que
/// cambia el estado de autenticación de Supabase (login, logout,
/// refresh de token), no solo al navegar.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<AuthState> stream) {
    notifyListeners();
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<AuthState> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
