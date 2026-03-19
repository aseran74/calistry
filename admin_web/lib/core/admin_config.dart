class AdminConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://swd7siw3.eu-central.insforge.app',
  );

  static const String anonKey = String.fromEnvironment(
    'API_ANON_KEY',
    defaultValue: '',
  );

  static const String mediaBucket = String.fromEnvironment(
    'ADMIN_MEDIA_BUCKET',
    defaultValue: 'exercises-media',
  );
}
