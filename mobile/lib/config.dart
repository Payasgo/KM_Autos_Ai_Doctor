class AppConfig {
  // Android emulator: 10.0.2.2; iOS simulator: 127.0.0.1.
  // For a physical phone, use your computer's LAN IP address.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );
}
