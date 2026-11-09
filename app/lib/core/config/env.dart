/// Compile-time environment configuration.
///
/// Values come from `--dart-define-from-file=config/<env>.json`.
/// Never call `String.fromEnvironment` anywhere else in the app.
abstract final class Env {
  static const String name = String.fromEnvironment('APP_ENV', defaultValue: 'dev');
  static const String appName = String.fromEnvironment('APP_NAME', defaultValue: 'Protect JnU');

  /// Backend (`web/` Next.js API). Dev: `http://localhost:3000` on a USB phone via `adb reverse`.
  static const String apiBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  /// Supabase publishable (public by design) key. Never put the secret/service-role key here.
  static const String supabasePublishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  static const bool enableHttpLogs = bool.fromEnvironment('ENABLE_HTTP_LOGS');

  static bool get isProd => name == 'prod';
}
