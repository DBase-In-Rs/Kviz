import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:kviz/data/remote/api_client.dart';
import 'package:kviz/data/remote/api_config.dart';
import 'package:kviz/data/remote/auth_manager.dart';
import 'package:kviz/data/remote/auth_models.dart';
import 'package:kviz/data/remote/auth_session_store.dart';
import 'package:kviz/data/remote/laravel_api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const config = ApiConfig(
    baseUrl: 'https://api.example.test/api/v1',
    appVersion: 'test-version',
    googleServerClientId: 'web-client-id.apps.googleusercontent.com',
  );

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  group('AuthManager Google Sign-In v7 migration', () {
    test('uses authenticate id token for backend mobile login', () async {
      final googleSignIn = _FakeGoogleSignIn(
        authenticatedAccount: const _FakeGoogleAccount('id-token-123'),
      );
      final api = _FakeLaravelApiService();
      final store = _FakeAuthSessionStore(deviceId: 'device-123');
      final manager = AuthManager(
        config: config,
        api: api,
        sessionStore: store,
        googleSignIn: googleSignIn,
      );

      final session = await manager.signInWithGoogle();

      expect(googleSignIn.signOutCalls, 1);
      expect(googleSignIn.authenticateCalls, 1);
      expect(api.lastGoogleIdToken, 'id-token-123');
      expect(api.lastDeviceId, 'device-123');
      expect(api.lastAppVersion, 'test-version');
      expect(session.accessToken, 'access-token');
      expect(store.writtenSession, same(session));
    });

    test('maps canceled Google authentication to AuthFlowException', () async {
      final googleSignIn = _FakeGoogleSignIn(
        authenticateError: const GoogleSignInException(
          code: GoogleSignInExceptionCode.canceled,
          description: 'User canceled',
        ),
      );
      final manager = AuthManager(
        config: config,
        api: _FakeLaravelApiService(),
        sessionStore: _FakeAuthSessionStore(deviceId: 'device-123'),
        googleSignIn: googleSignIn,
      );

      expect(
        manager.signInWithGoogle(),
        throwsA(
          isA<AuthFlowException>().having(
            (error) => error.message,
            'message',
            'Google prijava je otkazana.',
          ),
        ),
      );
    });

    test('does not call backend when Google returns no id token', () async {
      final googleSignIn = _FakeGoogleSignIn(
        authenticatedAccount: const _FakeGoogleAccount(null),
      );
      final api = _FakeLaravelApiService();
      final manager = AuthManager(
        config: config,
        api: api,
        sessionStore: _FakeAuthSessionStore(deviceId: 'device-123'),
        googleSignIn: googleSignIn,
      );

      await expectLater(
        manager.signInWithGoogle(),
        throwsA(isA<AuthFlowException>()),
      );
      expect(api.googleMobileLoginCalls, 0);
    });
  });
}

class _FakeGoogleAccount implements KvizGoogleAccount {
  const _FakeGoogleAccount(this.idToken);

  @override
  final String? idToken;
}

class _FakeGoogleSignIn implements KvizGoogleSignIn {
  _FakeGoogleSignIn({this.authenticatedAccount, this.authenticateError});

  final KvizGoogleAccount? authenticatedAccount;
  final GoogleSignInException? authenticateError;

  int authenticateCalls = 0;
  int signOutCalls = 0;

  @override
  Stream<KvizGoogleAccount> get authenticatedAccounts =>
      const Stream<KvizGoogleAccount>.empty();

  @override
  Future<KvizGoogleAccount?> attemptLightweightAuthentication() async {
    return authenticatedAccount;
  }

  @override
  Future<KvizGoogleAccount> authenticate() async {
    authenticateCalls += 1;
    final error = authenticateError;
    if (error != null) {
      throw error;
    }
    return authenticatedAccount ?? const _FakeGoogleAccount('id-token');
  }

  @override
  Future<void> signOut() async {
    signOutCalls += 1;
  }
}

class _FakeAuthSessionStore extends AuthSessionStore {
  _FakeAuthSessionStore({required this.deviceId});

  final String deviceId;
  AuthSession? writtenSession;

  @override
  Future<String> readOrCreateDeviceId() async => deviceId;

  @override
  Future<void> writeSession(AuthSession session) async {
    writtenSession = session;
  }

  @override
  Future<AuthSession?> readSession() async => writtenSession;

  @override
  Future<void> clearSession() async {
    writtenSession = null;
  }
}

class _FakeLaravelApiService extends LaravelApiService {
  _FakeLaravelApiService()
    : super(apiClient: ApiClient(baseUrl: 'https://api.example.test/api/v1'));

  int googleMobileLoginCalls = 0;
  String? lastGoogleIdToken;
  String? lastDeviceId;
  String? lastAppVersion;

  @override
  Future<Map<String, dynamic>> googleMobileLogin({
    required String idToken,
    required String deviceId,
    required String appVersion,
  }) async {
    googleMobileLoginCalls += 1;
    lastGoogleIdToken = idToken;
    lastDeviceId = deviceId;
    lastAppVersion = appVersion;

    return <String, dynamic>{
      'access_token': 'access-token',
      'refresh_token': 'refresh-token',
      'token_type': 'Bearer',
      'user': <String, dynamic>{
        'id': 7,
        'email': 'player@example.test',
        'first_name': 'Kviz',
        'last_name': 'Player',
        'avatar_url': null,
        'google_sub': 'google-sub',
      },
    };
  }
}
