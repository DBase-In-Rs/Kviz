import 'package:shared_preferences/shared_preferences.dart';

import 'laravel_api_service.dart';

class AchievementSyncService {
  const AchievementSyncService({
    required LaravelApiService api,
    required String accessToken,
    String? userKey,
  }) : _api = api,
       _accessToken = accessToken,
       _userKey = userKey;

  static const String _pendingPrefix = 'kviz.achievements.pending_sync.v1';

  final LaravelApiService _api;
  final String _accessToken;
  final String? _userKey;

  Future<Map<String, dynamic>> fetch() async {
    await flushPending();
    return _api.getAchievements(accessToken: _accessToken);
  }

  Future<Map<String, dynamic>?> sync({
    List<String> achievementKeys = const <String>[],
  }) async {
    try {
      final response = await _api.syncAchievements(
        accessToken: _accessToken,
        achievementKeys: achievementKeys,
      );
      await _setPending(false);
      return response;
    } catch (_) {
      await _setPending(true);
      return null;
    }
  }

  Future<void> flushPending() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_pendingKey) != true) {
      return;
    }

    await sync();
  }

  Future<void> _setPending(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_pendingKey, value);
  }

  String get _pendingKey {
    final normalized = _userKey?.trim();
    if (normalized == null || normalized.isEmpty) {
      return _pendingPrefix;
    }

    return '${_pendingPrefix}_$normalized';
  }
}
