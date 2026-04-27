import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter/material.dart' show NavigatorObserver;

class KvizAnalytics {
  KvizAnalytics._();

  static bool _enabled = false;

  static FirebaseAnalytics get _analytics => FirebaseAnalytics.instance;

  static List<NavigatorObserver> get navigatorObservers {
    if (!_enabled) {
      return const <NavigatorObserver>[];
    }

    return <NavigatorObserver>[
      FirebaseAnalyticsObserver(analytics: _analytics),
    ];
  }

  static Future<void> initialize({required bool enabled}) async {
    if (!enabled) {
      _enabled = false;
      return;
    }

    try {
      final supported = await _analytics.isSupported();
      _enabled = supported;
      if (!_enabled) {
        return;
      }

      await _analytics.setAnalyticsCollectionEnabled(true);
      appStarted();
    } catch (error) {
      _enabled = false;
      _debug('Analytics init failed', error);
    }
  }

  static void setAppContext({
    required String appVersion,
    required String theme,
    required bool useCyrillic,
    required bool largeText,
    required bool signedIn,
  }) {
    _send(
      () => _analytics.setDefaultEventParameters(<String, Object?>{
        'app_version': appVersion,
        'theme': theme,
        'script': useCyrillic ? 'cyrillic' : 'latin',
        'large_text': largeText ? 'true' : 'false',
        'auth_state': signedIn ? 'signed_in' : 'signed_out',
      }),
    );
    _setUserProperty('theme', theme);
    _setUserProperty('script', useCyrillic ? 'cyrillic' : 'latin');
    _setUserProperty('large_text', largeText ? 'true' : 'false');
    _setUserProperty('signed_in', signedIn ? 'true' : 'false');
  }

  static void appStarted() {
    event('kviz_app_started');
  }

  static void loginStart({required String method}) {
    event(
      'auth_action',
      parameters: <String, Object?>{'action': 'login_start', 'method': method},
    );
  }

  static void loginSuccess({required String method}) {
    event('login', parameters: <String, Object?>{'method': method});
    event(
      'auth_action',
      parameters: <String, Object?>{
        'action': 'login_success',
        'method': method,
      },
    );
  }

  static void loginFailure({required String method, required String reason}) {
    event(
      'auth_action',
      parameters: <String, Object?>{
        'action': 'login_failure',
        'method': method,
        'reason': _bucketReason(reason),
      },
    );
  }

  static void logout() {
    event(
      'auth_action',
      parameters: const <String, Object?>{
        'action': 'logout',
        'method': 'google',
      },
    );
  }

  static void screenView(
    String screenName, {
    Map<String, Object?>? parameters,
  }) {
    _send(
      () => _analytics.logScreenView(
        screenName: screenName,
        screenClass: 'Flutter',
      ),
    );
    if (parameters != null && parameters.isNotEmpty) {
      event(
        'screen_context',
        parameters: <String, Object?>{'screen': screenName, ...parameters},
      );
    }
  }

  static void uiAction({
    required String screen,
    required String area,
    required String target,
    String action = 'tap',
    Map<String, Object?>? parameters,
  }) {
    event(
      'ui_action',
      parameters: <String, Object?>{
        'screen': screen,
        'area': area,
        'target': target,
        'action': action,
        ...?parameters,
      },
    );
  }

  static void modeSelected({
    required String mode,
    required String source,
    String? onlineMode,
  }) {
    event(
      'select_content',
      parameters: <String, Object?>{
        'content_type': 'mode',
        'item_id': mode,
        'source': source,
        'online_mode': onlineMode,
      },
    );
    event(
      'mode_preview_open',
      parameters: <String, Object?>{
        'mode': mode,
        'online_mode': onlineMode,
        'source': source,
      },
    );
  }

  static void gameSessionStart({
    required String mode,
    required String sessionType,
    required int roundCount,
  }) {
    event(
      'level_start',
      parameters: <String, Object?>{
        'level_name': mode,
        'mode': mode,
        'session_type': sessionType,
        'round_count': roundCount,
      },
    );
    event(
      'game_session_start',
      parameters: <String, Object?>{
        'mode': mode,
        'session_type': sessionType,
        'round_count': roundCount,
      },
    );
  }

  static void gameSessionEnd({
    required String mode,
    required String sessionType,
    required String status,
    required int finalScore,
    required int answeredCount,
    required int correctCount,
    required int durationMs,
    required int averageResponseMs,
  }) {
    final success = status == 'completed' ? 1 : 0;
    event(
      'level_end',
      parameters: <String, Object?>{
        'level_name': mode,
        'success': success,
        'mode': mode,
        'session_type': sessionType,
        'status': status,
        'score': finalScore,
      },
    );
    event(
      'post_score',
      parameters: <String, Object?>{
        'score': finalScore,
        'level': mode,
        'mode': mode,
        'session_type': sessionType,
      },
    );
    event(
      'game_session_end',
      parameters: <String, Object?>{
        'mode': mode,
        'session_type': sessionType,
        'status': status,
        'score': finalScore,
        'answered_count': answeredCount,
        'correct_count': correctCount,
        'duration_ms': durationMs,
        'avg_response_ms': averageResponseMs,
      },
    );
  }

  static void roundStart({
    required String mode,
    required String sessionType,
    required String game,
    required int roundOrder,
    int? durationSeconds,
    int? questionId,
    String? questionSource,
    String? difficulty,
  }) {
    event(
      'round_start',
      parameters: <String, Object?>{
        'mode': mode,
        'session_type': sessionType,
        'game': game,
        'round_order': roundOrder,
        'duration_sec': durationSeconds,
        'question_id': questionId,
        'question_source': questionSource,
        'difficulty': difficulty,
      },
    );
  }

  static void roundEnd({
    required String mode,
    required String sessionType,
    required String game,
    required int roundOrder,
    required String status,
    required int elapsedMs,
    int? score,
    int? answeredCount,
    int? correctCount,
  }) {
    event(
      'round_end',
      parameters: <String, Object?>{
        'mode': mode,
        'session_type': sessionType,
        'game': game,
        'round_order': roundOrder,
        'status': status,
        'elapsed_ms': elapsedMs,
        'score': score,
        'answered_count': answeredCount,
        'correct_count': correctCount,
      },
    );
  }

  static void answerResult({
    required String mode,
    required String sessionType,
    required String game,
    required int roundOrder,
    required bool correct,
    required int responseTimeMs,
    required String inputType,
    int? points,
    int? score,
    int? questionId,
    String? questionSource,
    String? difficulty,
    int? answerLength,
    int? tokenCount,
    int? distance,
  }) {
    event(
      'answer_submit',
      parameters: <String, Object?>{
        'mode': mode,
        'session_type': sessionType,
        'game': game,
        'round_order': roundOrder,
        'result': correct ? 'correct' : 'wrong',
        'success': correct ? 1 : 0,
        'response_time_ms': responseTimeMs,
        'input_type': inputType,
        'points': points,
        'score': score,
        'question_id': questionId,
        'question_source': questionSource,
        'difficulty': difficulty,
        'answer_length': answerLength,
        'token_count': tokenCount,
        'distance': distance,
      },
    );
  }

  static void validationError({
    required String mode,
    required String sessionType,
    required String game,
    required String reason,
  }) {
    event(
      'answer_validation_error',
      parameters: <String, Object?>{
        'mode': mode,
        'session_type': sessionType,
        'game': game,
        'reason': _bucketReason(reason),
      },
    );
  }

  static void contentReportDraftSaved({
    required String mode,
    required String contentType,
    required String reason,
  }) {
    event(
      'content_report_draft_saved',
      parameters: <String, Object?>{
        'mode': mode,
        'content_type': contentType,
        'reason': _bucketReason(reason),
      },
    );
  }

  static void contentReportSubmitSuccess({
    required String mode,
    required String contentType,
    required String reason,
  }) {
    event(
      'content_report_submit_success',
      parameters: <String, Object?>{
        'mode': mode,
        'content_type': contentType,
        'reason': _bucketReason(reason),
      },
    );
  }

  static void contentReportSubmitFailed({
    required String mode,
    required String contentType,
    required String reason,
  }) {
    event(
      'content_report_submit_failed',
      parameters: <String, Object?>{
        'mode': mode,
        'content_type': contentType,
        'reason': _bucketReason(reason),
      },
    );
  }

  static void ruleBroken({
    required String mode,
    required String sessionType,
    required String reason,
  }) {
    event(
      'session_rule_broken',
      parameters: <String, Object?>{
        'mode': mode,
        'session_type': sessionType,
        'reason': _bucketReason(reason),
      },
    );
  }

  static void adBannerLoaded({required String adUnitId}) {
    event(
      'ad_banner_loaded',
      parameters: <String, Object?>{'ad_unit': _shortAdUnit(adUnitId)},
    );
  }

  static void adBannerFailed({required String adUnitId, required int code}) {
    event(
      'ad_banner_failed',
      parameters: <String, Object?>{
        'ad_unit': _shortAdUnit(adUnitId),
        'error_code': code,
      },
    );
  }

  static void event(String name, {Map<String, Object?>? parameters}) {
    final normalized = _normalizeParameters(parameters);
    _send(() => _analytics.logEvent(name: name, parameters: normalized));
  }

  static void _setUserProperty(String name, String value) {
    _send(() => _analytics.setUserProperty(name: name, value: value));
  }

  static void _send(Future<void> Function() operation) {
    if (!_enabled) {
      return;
    }

    unawaited(
      operation().catchError((Object error) {
        _debug('Analytics event failed', error);
      }),
    );
  }

  static Map<String, Object>? _normalizeParameters(
    Map<String, Object?>? parameters,
  ) {
    if (parameters == null || parameters.isEmpty) {
      return null;
    }

    final normalized = <String, Object>{};
    for (final entry in parameters.entries) {
      if (normalized.length >= 25) {
        break;
      }

      final value = entry.value;
      if (value == null) {
        continue;
      }

      if (value is bool) {
        normalized[entry.key] = value ? 'true' : 'false';
      } else if (value is String) {
        final trimmed = value.trim();
        if (trimmed.isNotEmpty) {
          normalized[entry.key] = _limit(trimmed);
        }
      } else if (value is int || value is double) {
        normalized[entry.key] = value;
      } else if (value is num) {
        normalized[entry.key] = value.toDouble();
      } else {
        normalized[entry.key] = _limit(value.toString());
      }
    }

    return normalized.isEmpty ? null : normalized;
  }

  static String _limit(String value) {
    if (value.length <= 100) {
      return value;
    }

    return value.substring(0, 100);
  }

  static String _bucketReason(String reason) {
    final value = reason.toLowerCase();
    if (value.contains('network') || value.contains('socket')) {
      return 'network';
    }
    if (value.contains('server') || value.contains('500')) {
      return 'server';
    }
    if (value.contains('integrity')) {
      return 'integrity';
    }
    if (value.contains('token') || value.contains('auth')) {
      return 'auth';
    }
    if (value.contains('background') || value.contains('napu')) {
      return 'background';
    }

    return _limit(value.replaceAll(RegExp(r'[^a-z0-9_]+'), '_'));
  }

  static String _shortAdUnit(String adUnitId) {
    final slash = adUnitId.lastIndexOf('/');
    if (slash < 0 || slash == adUnitId.length - 1) {
      return 'unknown';
    }

    return adUnitId.substring(slash + 1);
  }

  static void _debug(String message, Object error) {
    if (kDebugMode) {
      debugPrint('$message: $error');
    }
  }

  // ── Navigation ──────────────────────────────────────────────

  static void homeTabOpened() {
    screenView('home');
  }

  static void leaderboardTabOpened({
    required String mode,
    required String period,
  }) {
    screenView(
      'leaderboard',
      parameters: <String, Object?>{'mode': mode, 'period': period},
    );
  }

  static void leaderboardModeFilter({required String mode}) {
    uiAction(screen: 'leaderboard', area: 'filter', target: 'mode_$mode');
    event(
      'leaderboard_mode_changed',
      parameters: <String, Object?>{'mode': mode},
    );
  }

  static void leaderboardPeriodFilter({required String period}) {
    uiAction(screen: 'leaderboard', area: 'filter', target: 'period_$period');
    event(
      'leaderboard_period_changed',
      parameters: <String, Object?>{'period': period},
    );
  }

  static void profileTabOpened() {
    screenView('profile');
  }

  static void settingsTabOpened() {
    screenView('settings');
  }

  // ── Daily Challenge ─────────────────────────────────────────

  static void dailyChallengeStarted({required int streak}) {
    event(
      'daily_challenge_start',
      parameters: <String, Object?>{'streak': streak},
    );
    screenView('daily_challenge');
  }

  static void dailyChallengeCompleted({
    required int score,
    required int streak,
  }) {
    event(
      'daily_challenge_complete',
      parameters: <String, Object?>{'score': score, 'streak': streak},
    );
  }

  // ── Achievements ────────────────────────────────────────────

  static void achievementUnlocked({
    required String achievementKey,
    required String source,
  }) {
    event(
      'achievement_unlocked',
      parameters: <String, Object?>{
        'achievement': achievementKey,
        'source': source,
      },
    );
  }

  static void playGamesLeaderboardOpened({required String mode}) {
    uiAction(screen: 'leaderboard', area: 'gpg', target: 'open_leaderboard');
    event(
      'play_games_leaderboard_open',
      parameters: <String, Object?>{'mode': mode},
    );
  }

  static void playGamesAchievementsOpened() {
    uiAction(screen: 'profile', area: 'gpg', target: 'open_achievements');
    event('play_games_achievements_open');
  }

  // ── App Lifecycle ───────────────────────────────────────────

  static void appBackgrounded({String? reason}) {
    event('app_background', parameters: <String, Object?>{'reason': reason});
  }

  static void appForegrounded() {
    event('app_foreground');
  }

  // ── API & Errors ────────────────────────────────────────────

  static void apiErrorOccurred({
    required int statusCode,
    required String endpoint,
  }) {
    event(
      'api_error',
      parameters: <String, Object?>{
        'status_code': statusCode,
        'endpoint': endpoint,
      },
    );
  }

  // ── Queue ───────────────────────────────────────────────────

  static void queueWaitMeasured({required String mode, required int waitMs}) {
    event(
      'queue_wait_time',
      parameters: <String, Object?>{'mode': mode, 'wait_ms': waitMs},
    );
  }

  // ── Monetization ────────────────────────────────────────────

  static void rewardQuotaExhausted() {
    uiAction(screen: 'settings', area: 'rewarded_games', target: 'quota_full');
    event('reward_quota_exhausted');
  }
}
