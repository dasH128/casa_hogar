import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config/supabase_config.dart';
import 'routing/app_router.dart';
import 'ui/core/supabase_not_configured_screen.dart';
import 'ui/core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseConfig.initialize();
  runApp(const ProviderScope(child: MorellaApp()));
}

class MorellaApp extends StatelessWidget {
  const MorellaApp({super.key});

  @override
  Widget build(BuildContext context) {
    if (!SupabaseConfig.isConfigured) {
      return const MaterialApp(
        title: 'Morella',
        debugShowCheckedModeBanner: false,
        home: SupabaseNotConfiguredScreen(),
      );
    }

    return MaterialApp.router(
      title: 'Morella',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(),
      // Textos de Material (selector de fechas, menús) en español.
      locale: const Locale('es', 'PE'),
      supportedLocales: const [Locale('es', 'PE'), Locale('es')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      routerConfig: appRouter,
    );
  }
}
