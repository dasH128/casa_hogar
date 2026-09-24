import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config/supabase_config.dart';
import 'ui/screens/auth/acceso_screen.dart';
import 'ui/screens/supabase_not_configured_screen.dart';
import 'ui/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseConfig.initialize();
  runApp(const ProviderScope(child: MorellaApp()));
}

class MorellaApp extends StatelessWidget {
  const MorellaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Morella',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(),
      home: SupabaseConfig.isConfigured
          ? AccesoScreen(onAuthenticated: _handleAuthenticated)
          : const SupabaseNotConfiguredScreen(),
    );
  }

  // go_router llega con la pantalla de destino (screen 2 en adelante);
  // por ahora solo confirmamos a qué ruta se dirigiría tras autenticar.
  static void _handleAuthenticated(BuildContext context, String route) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Sesión iniciada. Redirigiría a $route.')),
    );
  }
}
