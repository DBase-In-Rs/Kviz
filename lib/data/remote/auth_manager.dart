import 'dart:async';

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:google_sign_in/google_sign_in.dart';

import 'api_client.dart';
import 'api_config.dart';
import 'api_exception.dart';
import 'auth_models.dart';
import 'auth_session_store.dart';
import 'laravel_api_service.dart';

const List<String> _googleSignInScopes = <String>['email', 'profile'];

abstract class KvizGoogleAccount {
  String? get idToken;
}

abstract class KvizGoogleSignIn {
  Stream<KvizGoogleAccount> get authenticatedAccounts;

  Future<KvizGoogleAccount?> attemptLightweightAuthentication();

  Future<KvizGoogleAccount> authenticate();

  Future<void> signOut();
}

class GoogleSignInV7Adapter implements KvizGoogleSignIn {
  GoogleSignInV7Adapter({required ApiConfig config})
    : _clientId = _googleClientIdForWeb(config),
      _serverClientId = _googleServerClientIdForNative(config);

  final String? _clientId;
  final String? _serverClientId;
  final GoogleSignIn _signIn = GoogleSignIn.instance;

  static Future<void>? _initializeFuture;

  Future<void> _ensureInitialized() {
    return _initializeFuture ??= _signIn.initialize(
      clientId: _clientId,
      serverClientId: _serverClientId,
    );
  }

  @override
  Stream<KvizGoogleAccount> get authenticatedAccounts {
    return Stream<void>.fromFuture(_ensureInitialized()).asyncExpand((_) {
      return _signIn.authenticationEvents
          .where((event) => event is GoogleSignInAuthenticationEventSignIn)
          .cast<GoogleSignInAuthenticationEventSignIn>()
          .map((event) => _GoogleSignInV7Account(event.user));
    });
  }

  @override
  Future<KvizGoogleAccount?> attemptLightweightAuthentication() async {
    await _ensureInitialized();
    final account = await _signIn.attemptLightweightAuthentication();
    return account == null ? null : _GoogleSignInV7Account(account);
  }

  @override
  Future<KvizGoogleAccount> authenticate() async {
    await _ensureInitialized();
    final account = await _signIn.authenticate(scopeHint: _googleSignInScopes);
    return _GoogleSignInV7Account(account);
  }

  @override
  Future<void> signOut() async {
    await _ensureInitialized();
    await _signIn.signOut();
  }
}

class _GoogleSignInV7Account implements KvizGoogleAccount {
  const _GoogleSignInV7Account(this._account);

  final GoogleSignInAccount _account;

  @override
  String? get idToken => _account.authentication.idToken;
}

class AuthManager {
  AuthManager({
    required ApiConfig config,
    AuthSessionStore? sessionStore,
    LaravelApiService? api,
    KvizGoogleSignIn? googleSignIn,
  }) : _config = config,
       _sessionStore = sessionStore ?? AuthSessionStore(),
       _api =
           api ??
           LaravelApiService(apiClient: ApiClient(baseUrl: config.baseUrl)),
       _googleSignIn = googleSignIn ?? GoogleSignInV7Adapter(config: config);

  final ApiConfig _config;
  final AuthSessionStore _sessionStore;
  final LaravelApiService _api;
  final KvizGoogleSignIn _googleSignIn;

  bool get usesWebGoogleButton => kIsWeb;

  Stream<AuthSession> get webAuthSessions {
    if (!kIsWeb) {
      return const Stream<AuthSession>.empty();
    }

    return _googleSignIn.authenticatedAccounts.asyncMap(
      _loginWithGoogleAccount,
    );
  }

  Future<void> startWebOneTap() async {
    if (!kIsWeb) {
      return;
    }

    try {
      await _googleSignIn.attemptLightweightAuthentication();
    } on GoogleSignInException {
      // The visible GIS button remains available if One Tap is dismissed or
      // blocked by browser/account policy.
    }
  }

  Future<AuthSession?> restoreSession() async {
    final stored = await _sessionStore.readSession();
    if (stored == null) {
      return null;
    }

    try {
      return await _loadUserWithAccess(stored);
    } on ApiException catch (error) {
      if (error.statusCode != 401 && error.statusCode != 403) {
        rethrow;
      }

      final refreshed = await _tryRefresh(stored);
      if (refreshed == null) {
        await _sessionStore.clearSession();
      }
      return refreshed;
    }
  }

  Future<AuthSession> signInWithGoogle() async {
    if (!_isGoogleSignInSupportedPlatform) {
      throw AuthFlowException(
        'Google prijava trenutno nije podrzana u Windows desktop build-u. '
        'Koristi Android ili web build za Google login.',
      );
    }

    if (kIsWeb) {
      final account = await _googleSignIn.attemptLightweightAuthentication();
      if (account == null) {
        throw AuthFlowException(
          'Na web-u koristi Google dugme ili dozvoli Google One Tap prijavu.',
        );
      }
      return _loginWithGoogleAccount(account);
    }

    await _googleSignIn.signOut();
    try {
      final account = await _googleSignIn.authenticate();
      return _loginWithGoogleAccount(account);
    } on GoogleSignInException catch (error) {
      final mapped = _mapGoogleSignInFailure(error);
      if (mapped != null) {
        throw mapped;
      }
      rethrow;
    }
  }

  Future<AuthSession> _loginWithGoogleAccount(KvizGoogleAccount account) async {
    final idToken = account.idToken?.trim();
    if (idToken == null || idToken.isEmpty) {
      throw AuthFlowException(
        kIsWeb
            ? 'Google web prijava nije vratila id_token. Proveri Web OAuth client ID i Authorized JavaScript origins.'
            : 'Google nije vratio id_token. KVIZ_GOOGLE_SERVER_CLIENT_ID nije postavljen ili ne odgovara Firebase projektu.',
      );
    }

    return _loginWithIdToken(idToken);
  }

  Future<void> logout(AuthSession? session) async {
    final currentSession = session ?? await _sessionStore.readSession();
    if (currentSession != null) {
      try {
        final deviceId = await _sessionStore.readOrCreateDeviceId();
        await _api.logout(
          accessToken: currentSession.accessToken,
          deviceId: deviceId,
          refreshToken: currentSession.refreshToken,
        );
      } catch (_) {
        // Ignore backend logout errors and clear local session anyway.
      }
    }

    await _googleSignIn.signOut();
    await _sessionStore.clearSession();
  }

  Future<AuthSession> _loginWithIdToken(String idToken) async {
    final deviceId = await _sessionStore.readOrCreateDeviceId();
    final response = await _api.googleMobileLogin(
      idToken: idToken,
      deviceId: deviceId,
      appVersion: _config.appVersion,
    );

    final session = AuthSession.fromLoginResponse(response);
    await _sessionStore.writeSession(session);
    return session;
  }

  Future<AuthSession> _loadUserWithAccess(AuthSession session) async {
    final userResponse = await _api.getMe(accessToken: session.accessToken);
    final normalizedUser = _extractUser(userResponse);
    final next = session.copyWith(user: AuthUser.fromJson(normalizedUser));
    await _sessionStore.writeSession(next);
    return next;
  }

  Future<AuthSession?> _tryRefresh(AuthSession previousSession) async {
    try {
      final deviceId = await _sessionStore.readOrCreateDeviceId();
      final response = await _api.refreshAccessToken(
        refreshToken: previousSession.refreshToken,
        deviceId: deviceId,
        appVersion: _config.appVersion,
      );

      final refreshed = previousSession.copyWith(
        accessToken: _readRequiredString(response, 'access_token'),
        refreshToken: _readRequiredString(response, 'refresh_token'),
        tokenType:
            _readString(response, 'token_type') ?? previousSession.tokenType,
      );

      return await _loadUserWithAccess(refreshed);
    } on ApiException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
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

  String _readRequiredString(Map<String, dynamic> payload, String key) {
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

  AuthFlowException? _mapGoogleSignInFailure(GoogleSignInException error) {
    if (error.code == GoogleSignInExceptionCode.canceled) {
      return AuthFlowException('Google prijava je otkazana.');
    }

    final rawMessage = '${error.code}: ${error.description} ${error.details}';
    final normalizedMessage = rawMessage.toLowerCase();
    final developerError =
        normalizedMessage.contains('apiexception: 10') ||
        normalizedMessage.contains('s0.d: 10') ||
        normalizedMessage.contains('developer_error') ||
        error.code == GoogleSignInExceptionCode.clientConfigurationError ||
        error.code == GoogleSignInExceptionCode.providerConfigurationError;

    if (developerError) {
      return AuthFlowException(
        'Google prijava nije pravilno podesena. '
        'Dodajte Play App Signing SHA-1/SHA-256 u Firebase konzolu za paket rs.in.dbase.kviz '
        'i postavite KVIZ_GOOGLE_SERVER_CLIENT_ID na Web OAuth client ID.',
      );
    }

    return null;
  }
}

bool get _isGoogleSignInSupportedPlatform {
  if (kIsWeb) {
    return true;
  }

  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
    case TargetPlatform.iOS:
    case TargetPlatform.macOS:
      return true;
    default:
      return false;
  }
}

String? _googleClientIdForWeb(ApiConfig config) {
  if (!kIsWeb) {
    return null;
  }

  final value = config.googleServerClientId.trim();
  return value.isEmpty ? null : value;
}

String? _googleServerClientIdForNative(ApiConfig config) {
  if (kIsWeb || !_isGoogleSignInSupportedPlatform) {
    return null;
  }

  final value = config.googleServerClientId.trim();
  return value.isEmpty ? null : value;
}
