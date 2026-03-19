/// Configuración del backend (Insforge / Supabase).
/// Sustituir con --dart-define en release o usar .env.
class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://swd7siw3.eu-central.insforge.app',
  );
  static const String anonKey = String.fromEnvironment(
    'API_ANON_KEY',
    defaultValue: '',
  );
  static const String authCallbackScheme = String.fromEnvironment(
    'AUTH_CALLBACK_SCHEME',
    defaultValue: 'calisteniaapp',
  );
  static const String authRedirectUri = '$authCallbackScheme://auth-callback';

  /// URL base de la app (web/PWA) para enlaces de invitación. El alumno abre
  /// [appWebBaseUrl]/teachers/[id] para iniciar sesión y solicitar ser alumno.
  static const String appWebBaseUrl = String.fromEnvironment(
    'APP_WEB_BASE_URL',
    defaultValue: 'https://swd7siw3.eu-central.insforge.app',
  );
}
