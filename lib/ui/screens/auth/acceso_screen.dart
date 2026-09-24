// lib/ui/screens/auth/acceso_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../state/perfil_providers.dart';
import '../../../state/session_providers.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/app_field.dart';

/// Ruta `/acceso`. Sin `AppShell`: panel de marca fijo de 560 px a la
/// izquierda, formulario de 388 px centrado a la derecha.
///
/// Tras `signInWithPassword`, guarda el perfil en
/// [perfilActualProvider] y navega según el rol (ver `rutaSegunRol`
/// en `state/perfil_providers.dart`).
class AccesoScreen extends ConsumerStatefulWidget {
  const AccesoScreen({super.key});

  @override
  ConsumerState<AccesoScreen> createState() => _AccesoScreenState();
}

class _AccesoScreenState extends ConsumerState<AccesoScreen> {
  final _emailController = TextEditingController(text: '');
  final _passwordController = TextEditingController();

  String? _almacenId;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _recuperarContrasena() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(
        () => _error = 'Escribe tu correo para recuperar la contraseña.',
      );
      return;
    }
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Si el correo existe, te enviamos un enlace.'),
        ),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _entrar(List<AlmacenOption> opciones) async {
    if (_submitting) return;

    final almacenId = _almacenId;
    if (almacenId == null) {
      setState(() => _error = 'Elige una sucursal y almacén.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      final userId = response.user?.id;
      if (userId == null) {
        setState(() => _error = 'No se pudo iniciar sesión. Intenta de nuevo.');
        return;
      }

      final perfil = await Supabase.instance.client
          .from('profiles')
          .select(
            'rol_id, nombre, rol:roles(codigo, nombre), sucursal:sucursales(nombre)',
          )
          .eq('id', userId)
          .single();
      final rol = perfil['rol'] as Map;
      final rolCodigo = rol['codigo'] as String;
      final sucursal = perfil['sucursal'] as Map?;

      final permisosRows = await Supabase.instance.client
          .from('permisos')
          .select('recurso, accion')
          .eq('rol_id', perfil['rol_id'] as String);
      final permisos = {
        for (final p in permisosRows) '${p['recurso']}.${p['accion']}',
      };

      final opcion = opciones.firstWhere((o) => o.almacenId == almacenId);
      ref
          .read(sesionProvider.notifier)
          .seleccionar(
            SesionSeleccion(
              sucursalId: opcion.sucursalId,
              almacenId: opcion.almacenId,
            ),
          );
      ref
          .read(perfilActualProvider.notifier)
          .establecer(
            PerfilActual(
              nombre: perfil['nombre'] as String,
              rolCodigo: rolCodigo,
              rolLabel:
                  '${rol['nombre']} · ${sucursal?['nombre'] ?? 'Sin sucursal'}',
              permisos: permisos,
            ),
          );

      if (!mounted) return;
      context.go(rutaSegunRol(rolCodigo));
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'No se pudo iniciar sesión. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final opcionesAsync = ref.watch(almacenOptionsProvider);

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
                      almacenId: _almacenId,
                      onAlmacenChanged: (value) =>
                          setState(() => _almacenId = value),
                      error: _error,
                      submitting: _submitting,
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
