// lib/ui/screens/ventas/venta_form_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../state/perfil_providers.dart';
import '../../../state/venta_draft_controller.dart';
import '../../shell/app_shell.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/key_bar.dart';
import '../../widgets/status_pill.dart';
import 'widgets/venta_credito_aviso_card.dart';
import 'widgets/venta_header_card.dart';
import 'widgets/venta_lineas_card.dart';
import 'widgets/venta_stock_card.dart';
import 'widgets/venta_totales_card.dart';

class GrabarIntent extends Intent {
  const GrabarIntent();
}

class BuscarProductoIntent extends Intent {
  const BuscarProductoIntent();
}

class BorrarItemIntent extends Intent {
  const BorrarItemIntent();
}

/// Ruta `/ventas/nueva` y `/ventas/:id`. Ver `docs/ui-spec.md`,
/// pantalla "2. Nueva venta": es la pantalla crítica del sistema.
class VentaFormScreen extends ConsumerStatefulWidget {
  const VentaFormScreen({super.key, this.documentoId});

  final String? documentoId;

  @override
  ConsumerState<VentaFormScreen> createState() => _VentaFormScreenState();
}

class _VentaFormScreenState extends ConsumerState<VentaFormScreen> {
  final _buscadorFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(ventaDraftProvider.notifier).cargar(widget.documentoId),
    );
  }

  @override
  void dispose() {
    _buscadorFocus.dispose();
    super.dispose();
  }

  Future<void> _confirmar() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(ventaDraftProvider.notifier).confirmar();
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo confirmar: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(ventaDraftProvider);

    return asyncState.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) =>
          Scaffold(body: Center(child: Text(_mensajeError(error)))),
      data: _buildShell,
    );
  }

  /// El rol "lectura" no tiene permiso de crear una venta (matriz de
  /// `permisos`, ver `001_fundamentos.sql`): oculta el ítem "Ventas"
  /// del rail (ver `app_shell.dart`), pero si se llega igual por URL
  /// directa, RLS rechaza el `insert` y esto explica por qué en vez
  /// de mostrar la excepción cruda de Postgres.
  String _mensajeError(Object error) {
    if (error is PostgrestException && error.code == '42501') {
      return 'No tienes permiso para crear una venta. Pídeselo a tu administrador.';
    }
    return 'No se pudo abrir el documento.\n$error';
  }

  Widget _buildShell(VentaDraftState state) {
    final doc = state.documento;
    final perfil = ref.watch(perfilActualProvider);
    final numeroDocumento = doc.serie == null
        ? 'NS · Sin numerar'
        : 'NS ${doc.serie}-${doc.correlativo.toString().padLeft(7, '0')}';

    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.f2): GrabarIntent(),
        SingleActivator(LogicalKeyboardKey.f3): BuscarProductoIntent(),
        SingleActivator(LogicalKeyboardKey.delete, control: true):
            BorrarItemIntent(),
      },
      child: Actions(
        actions: {
          GrabarIntent: CallbackAction<GrabarIntent>(
            onInvoke: (_) {
              if (doc.esBorrador && !state.guardando) _confirmar();
              return null;
            },
          ),
          BuscarProductoIntent: CallbackAction<BuscarProductoIntent>(
            onInvoke: (_) {
              _buscadorFocus.requestFocus();
              return null;
            },
          ),
          BorrarItemIntent: CallbackAction<BorrarItemIntent>(
            onInvoke: (_) {
              final index = state.focusedLineIndex;
              if (index != null) {
                ref.read(ventaDraftProvider.notifier).eliminarLinea(index);
              }
              return null;
            },
          ),
        },
        child: FocusScope(
          child: AppShell(
            activeRoute: '/ventas/nueva',
            userName: perfil?.nombre ?? '—',
            userRoleLabel: perfil?.rolLabel ?? '—',
            canView: perfil?.tienePermiso,
            onNavigate: (route) => context.go(route),
            headerChildren: [
              Text(
                'Nueva venta',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              _DocChip(text: numeroDocumento),
              StatusPill.estadoDocumento(doc.estado),
              const Spacer(),
              Text(
                '${doc.moneda} · T.C. ${doc.tipoCambio.toStringAsFixed(3)}',
                style: AppTheme.mono(size: 12, color: AppColor.inkMuted),
              ),
              OutlinedButton(
                onPressed: () => context.go('/documentos'),
                child: const Text('Descartar'),
              ),
              FilledButton(
                onPressed: doc.esBorrador && !state.guardando
                    ? _confirmar
                    : null,
                child: Text(doc.esBorrador ? 'Confirmar · F2' : 'Confirmado'),
              ),
            ],
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.xl,
                      vertical: AppSpace.lg,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        VentaHeaderCard(state: state),
                        const SizedBox(height: AppSpace.md),
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: VentaLineasCard(
                                  state: state,
                                  buscadorFocus: _buscadorFocus,
                                ),
                              ),
                              const SizedBox(width: AppSpace.md),
                              SizedBox(
                                width: AppSize.asidePanelWidth,
                                child: SingleChildScrollView(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      VentaTotalesCard(documento: doc),
                                      if (state.lineaEnfocada != null) ...[
                                        const SizedBox(height: AppSpace.md),
                                        VentaStockCard(state: state),
                                      ],
                                      if (state.avisoCredito != null) ...[
                                        const SizedBox(height: AppSpace.md),
                                        VentaCreditoAvisoCard(
                                          mensaje: state.avisoCredito!,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const KeyBar(
                  items: [
                    KeyBarItem(keyLabel: 'F2', description: 'Grabar'),
                    KeyBarItem(keyLabel: 'F3', description: 'Buscar producto'),
                    KeyBarItem(keyLabel: 'F4', description: 'Copiar doc.'),
                    KeyBarItem(keyLabel: 'F5', description: 'Anular'),
                    KeyBarItem(keyLabel: 'F6', description: 'Notas'),
                    KeyBarItem(keyLabel: 'F8', description: 'Moneda'),
                    KeyBarItem(keyLabel: 'F9', description: 'Impuestos'),
                    KeyBarItem(
                      keyLabel: 'Ctrl+Supr',
                      description: 'Borrar ítem',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DocChip extends StatelessWidget {
  const _DocChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColor.tableHeader,
        border: Border.all(color: AppColor.line),
        borderRadius: BorderRadius.circular(AppRadius.field),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.sm,
          vertical: 3,
        ),
        child: Text(
          text,
          style: AppTheme.mono(size: 12, color: AppColor.inkMuted),
        ),
      ),
    );
  }
}
