import 'api_client.dart';
import 'api_config.dart';
import 'api_exception.dart';
import 'auth_models.dart';
import 'auth_session_store.dart';
import 'laravel_api_service.dart';

class AuthRefreshCoordinator {
  AuthRefreshCoordinator({
    required ApiConfig config,
    AuthSessionStore? sessionStore,
  }) : _config = config,
       _sessionStore = sessionStore ?? AuthSessionStore();

  final ApiConfig _config;
  final AuthSessionStore _sessionStore;
  Future<AuthSession?>? _inFlight;

  Future<String?> refreshAccessToken(String rejectedAccessToken) async {
    final stored = await _sessionStore.readSession();
    if (stored == null) {
      return null;
    }

    final currentAccessToken = stored.accessToken.trim();
    if (currentAccessToken.isNotEmpty &&
        currentAccessToken != rejectedAccessToken) {
      return currentAccessToken;
    }

    final refreshed = await _refreshOnce(stored);
    return refreshed?.accessToken;
  }

  Future<AuthSession?> _refreshOnce(AuthSession previousSession) {
    final running = _inFlight;
    if (running != null) {
      return running;
    }

    final future = _refresh(previousSession);
    _inFlight = future.whenComplete(() {
      _inFlight = null;
    });

    return _inFlight!;
  }

  Future<AuthSession?> _refresh(AuthSession previousSession) async {
    try {
      final deviceId = await _sessionStore.readOrCreateDeviceId();
      final api = LaravelApiService(
        apiClient: ApiClient(baseUrl: _config.baseUrl),
      );
      final response = await api.refreshAccessToken(
        refreshToken: previousSession.refreshToken,
        deviceId: deviceId,
        appVersion: _config.appVersion,
      );
      final refreshed = previousSession.copyWith(
        accessToken: _requiredString(response, 'access_token'),
        refreshToken: _requiredString(response, 'refresh_token'),
        tokenType:
            _readString(response, 'token_type') ?? previousSession.tokenType,
      );

      final userResponse = await api.getMe(accessToken: refreshed.accessToken);
      final withUser = refreshed.copyWith(
        user: AuthUser.fromJson(_extractUser(userResponse)),
      );
      await _sessionStore.writeSession(withUser);

      return withUser;
    } on ApiException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        await _sessionStore.clearSession();
        return null;
      }

      rethrow;
    }
  }

  Map<String, dynamic> _extractUser(Map<String, dynamic> payload) {
    final nested = _asMap(payload['user']);
    if (nested != null) {
      return nested;
    }

    return payload;
  }

  String _requiredString(Map<String, dynamic> payload, String key) {
    final value = _readString(payload, key);
    if (value == null || value.isEmpty) {
      throw AuthFlowException('Nedostaje obavezno polje: $key');
    }

    return value;
  }

  String? _readString(Map<String, dynamic> payload, String key) {
    final value = payload[key];
    if (value == null) {
      return null;
    }

    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return value.map((key, dynamic data) => MapEntry(key.toString(), data));
    }

    return null;
  }
}
