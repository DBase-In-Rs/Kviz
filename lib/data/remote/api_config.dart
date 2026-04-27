class ApiConfig {
  const ApiConfig({
    required this.baseUrl,
    required this.appVersion,
    required this.googleServerClientId,
  });

  factory ApiConfig.fromEnvironment() {
    return const ApiConfig(
      baseUrl: String.fromEnvironment(
        'KVIZ_API_BASE_URL',
        defaultValue: 'https://api.dbase.in.rs/api/v1',
      ),
      appVersion: String.fromEnvironment(
        'KVIZ_APP_VERSION',
        defaultValue: '1.0.0',
      ),
      googleServerClientId: String.fromEnvironment(
        'KVIZ_GOOGLE_SERVER_CLIENT_ID',
        defaultValue: '',
      ),
    );
  }

  final String baseUrl;
  final String appVersion;
  final String googleServerClientId;
}
