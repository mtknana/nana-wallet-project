/// API endpoint selected at build time, e.g. --dart-define=API_BASE_URL=https://api.example.com/api.
class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000/api',
  );
}
