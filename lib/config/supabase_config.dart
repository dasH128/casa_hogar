// lib/config/supabase_config.dart

import 'package:supabase_flutter/supabase_flutter.dart';

/// Credenciales del proyecto Supabase, leídas en tiempo de compilación.
///
/// Copia `.env.example` a `.env`, complétalo y ejecuta con
/// `flutter run --dart-define-from-file=.env` (`.env` no se versiona,
/// ver `.gitignore`).
class SupabaseConfig {
  const SupabaseConfig._();

  static const url = String.fromEnvironment('SUPABASE_URL');
  static const publishableKey = String.fromEnvironment('SUPABASE_KEY');

  static bool get isConfigured => url.isNotEmpty && publishableKey.isNotEmpty;

  /// No-op si faltan credenciales; la app arranca igual mostrando
  /// `SupabaseNotConfiguredScreen`.
  static Future<void> initialize() async {
    if (!isConfigured) return;
    await Supabase.initialize(url: url, publishableKey: publishableKey);
  }
}
