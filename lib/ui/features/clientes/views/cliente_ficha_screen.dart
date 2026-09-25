// lib/ui/features/clientes/views/cliente_ficha_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../domain/models/cliente_models.dart';
import '../../../../state/perfil_providers.dart';
import '../../../core/shell/app_shell.dart';
import '../../../core/theme/app_tokens.dart';
import '../view_models/cliente_ficha_view_model.dart';
import 'widgets/cliente_actividad_card.dart';
import 'widgets/cliente_credito_card.dart';
import 'widgets/cliente_cuenta_corriente_card.dart';
import 'widgets/cliente_identificacion_card.dart';
import 'widgets/cliente_vencidas_card.dart';

class GuardarClienteIntent extends Intent {
  const GuardarClienteIntent();
}

/// Ruta `/clientes/:id`. Ver `docs/ui-spec.md`, pantalla
/// "6. Ficha de cliente". Con [clienteId] null es `/clientes/nuevo`: la
/// misma ficha, sin cuenta corriente ni panel de crédito.
class ClienteFichaScreen extends ConsumerStatefulWidget {
  const ClienteFichaScreen({super.key, this.clienteId});

  final String? clienteId;

  @override
  ConsumerState<ClienteFichaScreen> createState() => _ClienteFichaScreenState();
}

class _ClienteFichaScreenState extends ConsumerState<ClienteFichaScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final notifier = ref.read(clienteFichaProvider.notifier);
      final id = widget.clienteId;
      if (id == null) {
        notifier.nuevo();
      } else {
        notifier.cargar(id);
      }
    });
  }

  Future<void> _guardar() async {
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final esAlta = widget.clienteId == null;
    try {
      final id = await ref.read(clienteFichaProvider.notifier).guardar();
      messenger.showSnackBar(
        SnackBar(content: Text(esAlta ? 'Cliente creado' : 'Cliente guardado')),
      );
      if (esAlta) router.go('/clientes/$id');
    } on GuardarClienteFailure catch (failure) {
      messenger.showSnackBar(SnackBar(content: Text(failure.mensaje)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(clienteFichaProvider);

    return asyncState.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(
        body: Center(child: Text('No se pudo abrir el cliente.\n$error')),
      ),
      data: _buildShell,
    );
  }

  Widget _buildShell(ClienteFichaState state) {
    final perfil = ref.watch(perfilActualProvider);
    final esAlta = state.ficha.esNuevo;
    final puedeGuardar =
        (perfil?.tienePermiso('clientes', esAlta ? 'create' : 'update') ??
            false) &&
        !state.guardando;

    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.f2): GuardarClienteIntent(),
      },
      child: Actions(
        actions: {
          GuardarClienteIntent: CallbackAction<GuardarClienteIntent>(
            onInvoke: (_) {
              if (puedeGuardar) _guardar();
              return null;
            },
          ),
        },
        child: FocusScope(
          autofocus: true,
          child: AppShell(
            activeRoute: '/clientes',
            userName: perfil?.nombre ?? '—',
            userRoleLabel: perfil?.rolLabel ?? '—',
            canView: perfil?.tienePermiso,
            onNavigate: (route) => context.go(route),
            headerChildren: [
              Text(
                esAlta ? 'Nuevo cliente' : state.ficha.razonSocial,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              _TipoPersonaChip(ficha: state.ficha),
              const Spacer(),
              if (esAlta)
                OutlinedButton(
                  onPressed: () => context.go('/clientes'),
                  child: const Text('Cancelar'),
                )
              else
                OutlinedButton(
                  onPressed: () => context.go('/ventas/nueva'),
                  child: const Text('Nueva venta'),
                ),
              FilledButton(
                onPressed: puedeGuardar ? _guardar : null,
                child: const Text('Guardar · F2'),
              ),
            ],
            body: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.xl,
                vertical: AppSpace.lg,
              ),
              child: esAlta
                  ? Align(
                      alignment: Alignment.topCenter,
                      child: ClienteIdentificacionCard(ficha: state.ficha),
                    )
                  : _FichaExistente(state: state),
            ),
          ),
        ),
      ),
    );
  }
}

class _FichaExistente extends StatelessWidget {
  const _FichaExistente({required this.state});

  final ClienteFichaState state;

  @override
  Widget build(BuildContext context) {
    final resumen = state.resumen!;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClienteIdentificacionCard(ficha: state.ficha),
              const SizedBox(height: AppSpace.md),
              Expanded(child: ClienteCuentaCorrienteCard(cuotas: state.cuotas)),
            ],
          ),
        ),
        const SizedBox(width: AppSpace.md),
        SizedBox(
          width: AppSize.clienteAsideWidth,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClienteCreditoCard(resumen: resumen),
                if (resumen.cuotasVencidas > 0) ...[
                  const SizedBox(height: AppSpace.md),
                  ClienteVencidasCard(resumen: resumen),
                ],
                const SizedBox(height: AppSpace.md),
                ClienteActividadCard(resumen: resumen),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TipoPersonaChip extends StatelessWidget {
  const _TipoPersonaChip({required this.ficha});

  final ClienteFicha ficha;

  @override
  Widget build(BuildContext context) {
    final texto = ficha.esPersonaJuridica
        ? 'Persona jurídica'
        : 'Persona natural';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColor.infoSoft,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        child: Text(
          texto.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.66,
            color: AppColor.info,
          ),
        ),
      ),
    );
  }
}
