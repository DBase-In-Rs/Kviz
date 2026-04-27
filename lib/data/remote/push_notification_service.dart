import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_models.dart';
import 'laravel_api_service.dart';

class PushNotificationService {
  PushNotificationService();

  static const String _lastTokenKey = 'kviz.push.last_fcm_token.v1';
  static StreamSubscription<String>? _tokenRefreshSub;
  static StreamSubscription<RemoteMessage>? _foregroundSub;
  static StreamSubscription<RemoteMessage>? _openedSub;

  Future<void> initialize({
    required LaravelApiService api,
    required AuthSession session,
    required String deviceId,
    required String appVersion,
    GlobalKey<ScaffoldMessengerState>? messengerKey,
    required bool useCyrillic,
    ValueChanged<Map<String, dynamic>>? onOpened,
  }) async {
    if (!_isSupportedPlatform) {
      return;
    }

    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);

    final token = await _getToken(messaging);
    if (token != null && token.isNotEmpty) {
      await _registerToken(
        api: api,
        session: session,
        token: token,
        deviceId: deviceId,
        appVersion: appVersion,
      );
    }

    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = messaging.onTokenRefresh.listen((newToken) {
      _registerToken(
        api: api,
        session: session,
        token: newToken,
        deviceId: deviceId,
        appVersion: appVersion,
      ).ignore();
    });

    await _foregroundSub?.cancel();
    _foregroundSub = FirebaseMessaging.onMessage.listen((message) {
      _showForegroundMessage(message, messengerKey, useCyrillic);
    });

    await _openedSub?.cancel();
    _openedSub = FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _showForegroundMessage(message, messengerKey, useCyrillic);
      onOpened?.call(message.data);
    });

    final initial = await messaging.getInitialMessage();
    if (initial != null) {
      _showForegroundMessage(initial, messengerKey, useCyrillic);
      onOpened?.call(initial.data);
    }
  }

  Future<void> unregister({
    required LaravelApiService api,
    required AuthSession? session,
  }) async {
    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;
    await _foregroundSub?.cancel();
    _foregroundSub = null;
    await _openedSub?.cancel();
    _openedSub = null;

    if (session == null || !_isSupportedPlatform) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_lastTokenKey)?.trim();
    if (token == null || token.isEmpty) {
      return;
    }

    try {
      await api.unregisterPushToken(
        accessToken: session.accessToken,
        token: token,
      );
    } catch (_) {
      // Logout must not be blocked by push cleanup.
    } finally {
      await prefs.remove(_lastTokenKey);
    }
  }

  Future<String?> _getToken(FirebaseMessaging messaging) {
    if (kIsWeb) {
      const vapidKey = String.fromEnvironment('KVIZ_FIREBASE_VAPID_KEY');
      if (vapidKey.isEmpty) {
        return Future<String?>.value(null);
      }

      return messaging.getToken(vapidKey: vapidKey);
    }

    return messaging.getToken();
  }

  Future<void> _registerToken({
    required LaravelApiService api,
    required AuthSession session,
    required String token,
    required String deviceId,
    required String appVersion,
  }) async {
    await api.registerPushToken(
      accessToken: session.accessToken,
      token: token,
      platform: _platform,
      deviceId: deviceId,
      appVersion: appVersion,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastTokenKey, token);
  }

  void _showForegroundMessage(
    RemoteMessage message,
    GlobalKey<ScaffoldMessengerState>? messengerKey,
    bool useCyrillic,
  ) {
    final messenger = messengerKey?.currentState;
    if (messenger == null) {
      return;
    }

    final type = message.data['type']?.toString();
    final text = switch (type) {
      'queue_matched' =>
        useCyrillic ? 'Противник је пронађен!' : 'Protivnik je pronađen!',
      'content_report_resolved' =>
        useCyrillic ? 'Пријава је решена.' : 'Prijava je rešena.',
      _ => message.notification?.body ?? message.notification?.title,
    };
    if (text == null || text.trim().isEmpty) {
      return;
    }

    messenger.showSnackBar(SnackBar(content: Text(text.trim())));
  }

  bool get _isSupportedPlatform {
    if (kIsWeb) {
      return true;
    }

    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  String get _platform {
    if (kIsWeb) {
      return 'web';
    }

    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS => 'ios',
      _ => 'android',
    };
  }
}
