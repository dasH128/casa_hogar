// lib/ui/screens/supabase_not_configured_screen.dart

import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Pantalla de aviso cuando faltan las credenciales de Supabase.
class SupabaseNotConfiguredScreen extends StatelessWidget {
  const SupabaseNotConfiguredScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColor.ground,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.xl),
          child: Text(
            'Falta configurar Supabase.\n\n'
            'Copia .env.example a .env, complétalo y ejecuta con:\n'
            'flutter run --dart-define-from-file=.env',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ),
    );
  }
}
