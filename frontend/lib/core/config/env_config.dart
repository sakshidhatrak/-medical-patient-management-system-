enum Environment { development, staging, production }

class EnvConfig {
  static const String _env =
      String.fromEnvironment('ENV', defaultValue: 'development');
  static const String _baseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: 'https://dev-api.medimanage.com/v1',
  );
  static const String _apiKey =
      String.fromEnvironment('API_KEY', defaultValue: '');

  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://ddwaeeonsifzucajsovg.supabase.co',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable__8ASEYO_TeZd29ORPkicmA_HWgibZUf',
  );

  static Environment get environment => switch (_env) {
        'production' => Environment.production,
        'staging' => Environment.staging,
        _ => Environment.development,
      };

  static bool get isDevelopment => environment == Environment.development;
  static bool get isStaging => environment == Environment.staging;
  static bool get isProduction => environment == Environment.production;

  static String get baseUrl => _baseUrl;
  static String get apiKey => _apiKey;

  // Timeouts in milliseconds
  static const int connectTimeout = 30000;
  static const int receiveTimeout = 30000;
  static const int sendTimeout = 30000;
}
