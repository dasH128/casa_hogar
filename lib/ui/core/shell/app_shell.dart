// lib/ui/core/shell/app_shell.dart

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';

/// Un ítem del rail. [recurso]/[accion] son los valores de
/// `permisos.recurso`/`permisos.accion` (ver `001_fundamentos.sql` /
/// `006_rls.sql`) que deciden si se muestra: ocultarlo es cosmética,
/// la autorización real la aplica RLS. [accion] es `'create'` en los
/// que van directo a un formulario de alta (Ventas, Compras): un rol
/// de solo lectura no debería ni ver la opción de crear uno.
class AppShellNavItem {
  const AppShellNavItem({
    required this.label,
    required this.icon,
    required this.route,
    required this.recurso,
    this.accion = 'read',
  });

  final String label;
  final IconData icon;
  final String route;
  final String recurso;
  final String accion;
}

/// Rail de navegación por defecto, uno por artboard
/// (`Main`, `Compra`, `Documentos`, `Producto`, `Cliente`, `Usuarios`).
///
/// `documentos` no tiene un recurso propio en la matriz de permisos:
/// usa `informes`, el recurso de lectura transversal más cercano.
const List<AppShellNavItem> appShellNavItems = [
  AppShellNavItem(
    label: 'Ventas',
    icon: Icons.format_list_bulleted_rounded,
    route: '/ventas/nueva',
    recurso: 'ventas',
    accion: 'create',
  ),
  AppShellNavItem(
    label: 'Compras',
    icon: Icons.shopping_cart_outlined,
    route: '/compras',
    recurso: 'compras',
    accion: 'create',
  ),
  AppShellNavItem(
    label: 'Documentos',
    icon: Icons.description_outlined,
    route: '/documentos',
    recurso: 'informes',
  ),
  AppShellNavItem(
    label: 'Catálogo',
    icon: Icons.inventory_2_outlined,
    route: '/catalogo',
    recurso: 'productos',
  ),
  AppShellNavItem(
    label: 'Clientes',
    icon: Icons.people_outline,
    route: '/clientes',
    recurso: 'clientes',
  ),
  AppShellNavItem(
    label: 'Usuarios',
    icon: Icons.shield_outlined,
    route: '/usuarios',
    recurso: 'usuarios',
  ),
];

/// Rail de 216 px + header de 62 px + contenido, reutilizado en todas
/// las pantallas autenticadas.
class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.activeRoute,
    required this.userName,
    required this.userRoleLabel,
    required this.headerChildren,
    required this.body,
    this.brand = 'Morella',
    this.tagline = 'Ventas y almacén',
    this.items = appShellNavItems,
    this.canView,
    this.onNavigate,
  });

  final String activeRoute;
  final String userName;

  /// "Rol · Sucursal", ya formateado por quien arma la pantalla.
  final String userRoleLabel;

  /// Título, chips y acciones del header, en orden; `AppShell` los
  /// separa con el gap de 14 px del artboard.
  final List<Widget> headerChildren;
  final Widget body;

  final String brand;
  final String tagline;
  final List<AppShellNavItem> items;

  /// Si es null, se muestran todos los ítems. Ocultar un ítem aquí es
  /// cortesía visual; RLS decide de verdad.
  final bool Function(String recurso, String accion)? canView;
  final void Function(String route)? onNavigate;

  @override
  Widget build(BuildContext context) {
    final visibleItems = items
        .where((item) => canView?.call(item.recurso, item.accion) ?? true)
        .toList();

    return Scaffold(
      backgroundColor: AppColor.ground,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Rail(
            items: visibleItems,
            activeRoute: activeRoute,
            brand: brand,
            tagline: tagline,
            userName: userName,
            userRoleLabel: userRoleLabel,
            onNavigate: onNavigate,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Header(children: headerChildren),
                Expanded(child: body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppSize.headerHeight,
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.xl),
      decoration: const BoxDecoration(
        color: AppColor.surface,
        border: Border(bottom: BorderSide(color: AppColor.line)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: AppSpace.md),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _Rail extends StatelessWidget {
  const _Rail({
    required this.items,
    required this.activeRoute,
    required this.brand,
    required this.tagline,
    required this.userName,
    required this.userRoleLabel,
    required this.onNavigate,
  });

  final List<AppShellNavItem> items;
  final String activeRoute;
  final String brand;
  final String tagline;
  final String userName;
  final String userRoleLabel;
  final void Function(String route)? onNavigate;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppSize.railWidth,
      color: AppColor.rail,
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, AppSpace.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  brand,
                  style: AppTheme.serif(color: AppColor.railTextStrong),
                ),
                const SizedBox(height: AppSpace.xs),
                Text(
                  tagline.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.1,
                    color: AppColor.railTextMuted,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              children: [
                for (final item in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: _RailItem(
                      item: item,
                      active: item.route == activeRoute,
                      onTap: onNavigate == null
                          ? null
                          : () => onNavigate!(item.route),
                    ),
                  ),
              ],
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
            child: DecoratedBox(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColor.railActive)),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      userName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColor.railTextStrong,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      userRoleLabel,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColor.railTextMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({required this.item, required this.active, this.onTap});

  final AppShellNavItem item;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColor.railTextStrong : AppColor.railText;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.button),
        child: Container(
          height: AppSize.railItemHeight,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: active ? AppColor.railActive : null,
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
          child: Row(
            children: [
              Icon(item.icon, size: 15, color: color),
              const SizedBox(width: 10),
              Text(
                item.label,
                style: TextStyle(
                  color: color,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
