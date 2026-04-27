import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PlayGamesService {
  const PlayGamesService();

  static const MethodChannel _channel = MethodChannel(
    'rs.in.dbase.kviz/play_games',
  );

  static const String firstGameAchievement = 'first_game';
  static const String sevenCorrectStreakAchievement = 'seven_correct_streak';
  static const String oneThousandPointsAchievement = 'one_thousand_points';
  static const String myNumberPerfectAchievement = 'my_number_perfect';
  static const String top10LeaderboardAchievement = 'top_10_leaderboard';
  static const String dailyStreak7Achievement = 'daily_streak_7';
  static const String perfectKvizAchievement = 'perfect_kviz';
  static const String associationsMasterAchievement = 'asocijacije_master';
  static const String speedDemonAchievement = 'speed_demon';
  static const String centurionAchievement = 'centurion';
  static const String marathonAchievement = 'marathon';

  static const Set<String> achievementKeys = <String>{
    firstGameAchievement,
    sevenCorrectStreakAchievement,
    oneThousandPointsAchievement,
    myNumberPerfectAchievement,
    top10LeaderboardAchievement,
    dailyStreak7Achievement,
    perfectKvizAchievement,
    associationsMasterAchievement,
    speedDemonAchievement,
    centurionAchievement,
    marathonAchievement,
  };

  static const Set<String> googleLeaderboardModes = <String>{
    'pitanja',
    'questions',
    'ko_zna_zna',
    'asocijacije',
    'associations',
    'moj_broj',
    'my_number',
    'tangram',
    'tangram_plus',
    'daily',
    'dnevni_izazov',
    'kviz_plus',
  };

  static const String _firstGameAchievementUnlockedKey =
      'kviz_first_game_achievement_unlocked_v1';
  static const String _firstGameAchievementCompletedKey =
      'kviz_first_game_achievement_completed_v1';
  static const String _achievementSyncedPrefix =
      'kviz_play_games_achievement_synced_v1';
  static const String _achievementCompletedPrefix =
      'kviz_play_games_achievement_completed_v1';

  Future<bool> unlockFirstGameAchievementOnce({String? userKey}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(
      _achievementPrefKey(_firstGameAchievementCompletedKey, userKey),
      true,
    );

    final synced = await unlockAchievementOnce(
      firstGameAchievement,
      userKey: userKey,
    );
    if (synced) {
      await prefs.setBool(
        _achievementPrefKey(_firstGameAchievementUnlockedKey, userKey),
        true,
      );
    }
    return synced;
  }

  Future<bool> unlockAchievementOnce(
    String achievementKey, {
    String? userKey,
  }) async {
    if (!achievementKeys.contains(achievementKey)) {
      return false;
    }

    final prefs = await SharedPreferences.getInstance();
    final completedKey = _scopedAchievementPrefKey(
      _achievementCompletedPrefix,
      achievementKey,
      userKey,
    );
    await prefs.setBool(completedKey, true);

    final syncedKey = _scopedAchievementPrefKey(
      _achievementSyncedPrefix,
      achievementKey,
      userKey,
    );
    if (prefs.getBool(syncedKey) == true) {
      return false;
    }

    final unlocked = await unlockAchievement(achievementKey);
    if (unlocked) {
      await prefs.setBool(syncedKey, true);
    }
    return unlocked;
  }

  Future<void> syncProfileAchievements({
    required int gamesPlayed,
    required int totalScore,
    required int? bestRank,
    required int dailyCompletedTasks,
    String? userKey,
  }) async {
    if (gamesPlayed > 0) {
      await unlockFirstGameAchievementOnce(userKey: userKey);
    }
    if (totalScore >= 1000) {
      await unlockAchievementOnce(
        oneThousandPointsAchievement,
        userKey: userKey,
      );
    }
    if (bestRank != null && bestRank > 0 && bestRank <= 10) {
      await unlockAchievementOnce(
        top10LeaderboardAchievement,
        userKey: userKey,
      );
    }
    if (gamesPlayed >= 100) {
      await unlockAchievementOnce(centurionAchievement, userKey: userKey);
    }
    if (gamesPlayed >= 500) {
      await unlockAchievementOnce(marathonAchievement, userKey: userKey);
    }
    if (dailyCompletedTasks >= 7) {
      await unlockAchievementOnce(dailyStreak7Achievement, userKey: userKey);
    }
  }

  Future<void> syncCompletedAchievements({String? userKey}) async {
    final prefs = await SharedPreferences.getInstance();

    for (final achievementKey in achievementKeys) {
      final completed = prefs.getBool(
        _scopedAchievementPrefKey(
          _achievementCompletedPrefix,
          achievementKey,
          userKey,
        ),
      );
      final synced = prefs.getBool(
        _scopedAchievementPrefKey(
          _achievementSyncedPrefix,
          achievementKey,
          userKey,
        ),
      );

      if (completed == true && synced != true) {
        await unlockAchievementOnce(achievementKey, userKey: userKey);
      }
    }
  }

  Future<void> syncSessionResult({
    required String mode,
    required int finalScore,
    required int bestStreak,
    required bool myNumberPerfect,
    required bool perfectKviz,
    required bool associationsMaster,
    required int speedDemonCount,
    required List<String> serverConfirmedAchievements,
    String? userKey,
  }) async {
    await submitScoreForMode(mode: mode, score: finalScore);
    await unlockFirstGameAchievementOnce(userKey: userKey);

    // Only unlock achievements that the server has confirmed.
    // Client-side flags are NOT trusted for security.
    for (final key in serverConfirmedAchievements) {
      if (achievementKeys.contains(key)) {
        await unlockAchievementOnce(key, userKey: userKey);
      }
    }
  }

  Future<bool> isFirstGameAchievementCompleted({String? userKey}) async {
    final genericComplete = await isAchievementCompleted(
      firstGameAchievement,
      userKey: userKey,
    );
    if (genericComplete) {
      return true;
    }

    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(
          _achievementPrefKey(_firstGameAchievementCompletedKey, userKey),
        ) ==
        true;
  }

  Future<bool> isAchievementCompleted(
    String achievementKey, {
    String? userKey,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(
          _scopedAchievementPrefKey(
            _achievementCompletedPrefix,
            achievementKey,
            userKey,
          ),
        ) ==
        true;
  }

  Future<bool> unlockFirstGameAchievement() async {
    return unlockAchievement(firstGameAchievement);
  }

  Future<bool> unlockAchievement(String achievementKey) async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'unlockAchievement',
        <String, Object?>{'achievementKey': achievementKey},
      );
      return result ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> submitScoreForMode({
    required String mode,
    required int score,
  }) async {
    if (!hasGoogleLeaderboardForMode(mode) || score < 0) {
      return false;
    }

    try {
      final result = await _channel.invokeMethod<bool>(
        'submitLeaderboardScore',
        <String, Object?>{'leaderboardMode': mode, 'score': score},
      );
      return result ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> showLeaderboard(String mode) async {
    if (!hasGoogleLeaderboardForMode(mode)) {
      return false;
    }

    try {
      final result = await _channel.invokeMethod<bool>(
        'showLeaderboard',
        <String, Object?>{'leaderboardMode': mode},
      );
      return result ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> showAllLeaderboards() async {
    try {
      final result = await _channel.invokeMethod<bool>('showAllLeaderboards');
      return result ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> showAchievements() async {
    try {
      final result = await _channel.invokeMethod<bool>('showAchievements');
      return result ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  static bool hasGoogleLeaderboardForMode(String mode) {
    return googleLeaderboardModes.contains(mode.trim());
  }

  static String normalizeGoogleLeaderboardMode(String mode) {
    final normalized = mode.trim();
    return switch (normalized) {
      'questions' || 'ko_zna_zna' => 'pitanja',
      'associations' => 'asocijacije',
      'my_number' => 'moj_broj',
      'tangram_plus' => 'tangram',
      'daily' || 'dnevni_izazov' => 'kviz_plus',
      _ => normalized,
    };
  }

  static String _achievementPrefKey(String prefix, String? userKey) {
    final normalizedUserKey = userKey?.trim();
    if (normalizedUserKey == null || normalizedUserKey.isEmpty) {
      return prefix;
    }

    final encodedUserKey = base64Url
        .encode(utf8.encode(normalizedUserKey))
        .replaceAll('=', '');
    return '${prefix}_$encodedUserKey';
  }

  static String _scopedAchievementPrefKey(
    String prefix,
    String achievementKey,
    String? userKey,
  ) {
    final normalizedAchievementKey = achievementKey.trim();
    return _achievementPrefKey('${prefix}_$normalizedAchievementKey', userKey);
  }
}
