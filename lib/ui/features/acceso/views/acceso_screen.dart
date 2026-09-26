// lib/ui/features/acceso/views/acceso_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../domain/failures.dart';
import '../../../../state/session_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_field.dart';
import '../view_models/acceso_view_model.dart';

/// Ruta `/acceso`. Sin `AppShell`: panel de marca fijo de 560 px a la
/// izquierda, formulario de 388 px centrado a la derecha.
///
/// Toda la lógica de login vive en [AccesoViewModel]; esta pantalla
/// solo pinta el formulario y reacciona a lo que el ViewModel devuelve.
class AccesoScreen extends ConsumerStatefulWidget {
  const AccesoScreen({super.key});

  @override
  ConsumerState<AccesoScreen> createState() => _AccesoScreenState();
}

class _AccesoScreenState extends ConsumerState<AccesoScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _recuperarContrasena() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final enviado = await ref
          .read(accesoProvider.notifier)
          .recuperarContrasena(_emailController.text);
      if (enviado) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Si el correo existe, te enviamos un enlace.'),
          ),
        );
      }
    } on AppFailure catch (failure) {
      messenger.showSnackBar(SnackBar(content: Text(failure.mensaje)));
    }
  }

  Future<void> _entrar(List<AlmacenOption> opciones) async {
    final ruta = await ref
        .read(accesoProvider.notifier)
        .entrar(
          email: _emailController.text,
          password: _passwordController.text,
          opciones: opciones,
        );
    if (ruta != null && mounted) context.go(ruta);
  }

  @override
  Widget build(BuildContext context) {
    final opcionesAsync = ref.watch(almacenOptionsProvider);
    final accesoState = ref.watch(accesoProvider);

    return Scaffold(
      backgroundColor: AppColor.ground,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _BrandPanel(),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: AppSpace.xl),
                child: SizedBox(
                  width: AppSize.authFormWidth,
                  child: opcionesAsync.when(
                    data: (opciones) => _FormularioAcceso(
                      emailController: _emailController,
                      passwordController: _passwordController,
                      opciones: opciones,
                      almacenId: accesoState.almacenId,
                      onAlmacenChanged: (value) => ref
                          .read(accesoProvider.notifier)
                          .seleccionarAlmacen(value),
                      error: accesoState.error,
                      submitting: accesoState.submitting,
                      onSubmit: () => _entrar(opciones),
                      onRecuperar: _recuperarContrasena,
                    ),
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 120),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppColor.primary,
                        ),
                      ),
                    ),
                    error: (error, stackTrace) => Text(
                      'No se pudo cargar sucursales y almacenes. Verifica tu conexión.',
                      style: const TextStyle(color: AppColor.danger),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FormularioAcceso extends StatelessWidget {
  const _FormularioAcceso({
    required this.emailController,
    required this.passwordController,
    required this.opciones,
    required this.almacenId,
    required this.onAlmacenChanged,
    required this.error,
    required this.submitting,
    required this.onSubmit,
    required this.onRecuperar,
  });

  final TextEditingController emailController;
  final TextEditingController passwordController;
  final List<AlmacenOption> opciones;
  final String? almacenId;
  final ValueChanged<String?> onAlmacenChanged;
  final String? error;
  final bool submitting;
  final VoidCallback onSubmit;
  final VoidCallback onRecuperar;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Entrar',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.39,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Usa la cuenta que te asignó tu administrador.',
          style: TextStyle(fontSize: 13.5, color: AppColor.inkMuted),
        ),
        const SizedBox(height: 28),
        AppField(
          label: 'Correo',
          dense: false,
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 16),
        AppField(
          label: 'Contraseña',
          dense: false,
          controller: passwordController,
          obscureText: true,
        ),
        const SizedBox(height: 16),
        AppField(
          label: 'Sucursal y almacén',
          dense: false,
          child: DropdownButtonFormField<String>(
            initialValue: almacenId,
            isExpanded: true,
            decoration: AppField.decoration(dense: false),
            style: AppField.textStyleFor(context, dense: false),
            items: [
              for (final opcion in opciones)
                DropdownMenuItem(
                  value: opcion.almacenId,
                  child: Text(opcion.label),
                ),
            ],
            onChanged: onAlmacenChanged,
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 16),
          Text(
            error!,
            style: const TextStyle(fontSize: 12.5, color: AppColor.danger),
          ),
        ],
        const SizedBox(height: 6),
        SizedBox(
          height: AppSize.authButtonHeight,
          child: FilledButton(
            onPressed: submitting ? null : onSubmit,
            style: FilledButton.styleFrom(
              backgroundColor: AppColor.primary,
              foregroundColor: AppColor.primaryOn,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.authControl),
              ),
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            child: submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColor.primaryOn,
                    ),
                  )
                : const Text('Entrar'),
          ),
        ),
        const SizedBox(height: 2),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
              child: GestureDetector(
                onTap: onRecuperar,
                child: const Text(
                  'He olvidado la contraseña',
                  style: TextStyle(fontSize: 12.5, color: AppColor.primary),
                ),
              ),
            ),
            const SizedBox(width: AppSpace.sm),
            const Flexible(
              child: Text(
                '¿Problemas? Escribe a tu administrador',
                textAlign: TextAlign.end,
                style: TextStyle(fontSize: 12, color: AppColor.inkFaint),
              ),
            ),
          ],
        ),
        Container(
          margin: const EdgeInsets.only(top: 34),
          padding: const EdgeInsets.only(top: 20),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColor.line)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.shield_outlined, size: 15, color: AppColor.inkFaint),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Tu rol decide qué ves y qué puedes cambiar. Si necesitas acceso a '
                  'compras o a costes, pídelo: no se activa desde aquí.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppColor.inkFaint,
                    height: 1.55,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppSize.authPanelWidth,
      color: AppColor.rail,
      padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 52),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Morella',
            style: AppTheme.serif(size: 40, color: AppColor.railTextStrong),
          ),
          const SizedBox(height: 10),
          const Text(
            'VENTAS Y ALMACÉN',
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 1.54,
              color: AppColor.railTextMuted,
            ),
          ),
          const Spacer(),
          Text(
            'Cada documento deja rastro. El stock es un libro, no una casilla.',
            style: AppTheme.serif(
              size: 34,
              color: AppColor.railTextStrong,
            ).copyWith(height: 1.32),
          ),
          const SizedBox(height: 36),
          const _BrandFeature(
            icon: Icons.shield_outlined,
            text: 'Los permisos se aplican en la base de datos. Lo que no te toca, no se descarga.',
          ),
          const SizedBox(height: AppSpace.md),
          const _BrandFeature(
            icon: Icons.description_outlined,
            text: 'Comprobantes electrónicos con envío en cola y constancia guardada.',
          ),
          const Spacer(),
          const Text(
            'Versión 1.0 · demo',
            style: TextStyle(fontSize: 11.5, color: AppColor.railTextFaint),
          ),
        ],
      ),
    );
  }
}

class _BrandFeature extends StatelessWidget {
  const _BrandFeature({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColor.railTextMuted),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: AppColor.railText,
              height: 1.55,
            ),
          ),
        ),
      ],
    );
  }
}
