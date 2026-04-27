import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_models.dart';

class AuthSessionStore {
  AuthSessionStore({FlutterSecureStorage? secureStorage})
    : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  static const String _sessionKey = 'kviz_auth_session_v1';
  static const String _deviceIdKey = 'kviz_device_id_v1';

  final FlutterSecureStorage _secureStorage;

  Future<AuthSession?> readSession() async {
    final raw = await _readRawSession();
    if (raw.trim().isEmpty) {
      return null;
    }

    return _decodeSession(raw);
  }

  Future<void> writeSession(AuthSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await _secureStorage.write(
      key: _sessionKey,
      value: jsonEncode(session.toJson()),
    );
    await prefs.remove(_sessionKey);
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await _secureStorage.delete(key: _sessionKey);
    await prefs.remove(_sessionKey);
  }

  Future<String> _readRawSession() async {
    final secureRaw = await _secureStorage.read(key: _sessionKey);
    if (secureRaw != null && secureRaw.trim().isNotEmpty) {
      return secureRaw;
    }

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_sessionKey);
    if (raw == null || raw.trim().isEmpty) {
      return '';
    }

    await _secureStorage.write(key: _sessionKey, value: raw);
    await prefs.remove(_sessionKey);
    return raw;
  }

  AuthSession? _decodeSession(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return null;
      }

      final map = decoded.map(
        (key, dynamic value) => MapEntry(key.toString(), value),
      );
      return AuthSession.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  Future<String> readOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_deviceIdKey);
    if (stored != null && stored.trim().isNotEmpty) {
      return stored;
    }

    final generated = _generateDeviceId();
    await prefs.setString(_deviceIdKey, generated);
    return generated;
  }

  String _generateDeviceId() {
    final random = Random.secure();
    final bytes = Uint8List(18);
    for (var i = 0; i < bytes.length; i += 1) {
      bytes[i] = random.nextInt(256);
    }

    final encoded = base64UrlEncode(bytes).replaceAll('=', '');
    return 'android-$encoded';
  }
}
