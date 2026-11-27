enum AppFlavor { dev, prod }

abstract final class AppEnv {
  static const String _flavorName = String.fromEnvironment(
    'FLAVOR',
    defaultValue: 'dev',
  );
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );
  static const bool useMockApi = bool.fromEnvironment(
    'USE_MOCK_API',
    defaultValue: true,
  );

  static AppFlavor get flavor =>
      _flavorName.toLowerCase() == 'prod' ? AppFlavor.prod : AppFlavor.dev;

  static bool get hasSupabaseConfig =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static String get edgeFunctionsBaseUrl {
    if (supabaseUrl.isNotEmpty) {
      final normalized = supabaseUrl.endsWith('/')
          ? supabaseUrl.substring(0, supabaseUrl.length - 1)
          : supabaseUrl;
      return '$normalized/functions/v1';
    }
    return 'https://example.supabase.co/functions/v1';
  }
}
