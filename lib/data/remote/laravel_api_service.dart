import 'ad_reward_quota.dart';
import 'api_client.dart';
import 'quiz_subscription_status.dart';

class LaravelApiService {
  const LaravelApiService({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<Map<String, dynamic>> googleMobileLogin({
    required String idToken,
    required String deviceId,
    required String appVersion,
  }) {
    return _apiClient.postJson(
      '/auth/google/mobile',
      headers: _jsonHeaders(),
      body: <String, dynamic>{
        'id_token': idToken,
        'device_id': deviceId,
        'app_version': appVersion,
      },
    );
  }

  Future<Map<String, dynamic>> refreshAccessToken({
    required String refreshToken,
    required String deviceId,
    required String appVersion,
  }) {
    return _apiClient.postJson(
      '/auth/refresh',
      headers: _jsonHeaders(),
      body: <String, dynamic>{
        'refresh_token': refreshToken,
        'device_id': deviceId,
        'app_version': appVersion,
      },
    );
  }

  Future<Map<String, dynamic>> getMe({required String accessToken}) {
    return _apiClient.getJson(
      '/auth/me',
      headers: _jsonHeaders(accessToken: accessToken),
    );
  }

  Future<Map<String, dynamic>> logout({
    required String accessToken,
    required String deviceId,
    required String refreshToken,
  }) {
    return _apiClient.postJson(
      '/auth/logout',
      headers: _jsonHeaders(accessToken: accessToken),
      body: <String, dynamic>{
        'device_id': deviceId,
        'refresh_token': refreshToken,
      },
    );
  }

  Future<Map<String, dynamic>> getAchievements({required String accessToken}) {
    return _apiClient.getJson(
      '/achievements',
      headers: _jsonHeaders(accessToken: accessToken),
    );
  }

  Future<Map<String, dynamic>> syncAchievements({
    required String accessToken,
    List<String> achievementKeys = const <String>[],
  }) {
    return _apiClient.postJson(
      '/achievements/sync',
      headers: _jsonHeaders(accessToken: accessToken),
      body: <String, dynamic>{
        if (achievementKeys.isNotEmpty) 'achievement_keys': achievementKeys,
      },
    );
  }

  Future<Map<String, dynamic>> getCurrentSeason({required String accessToken}) {
    return _apiClient.getJson(
      '/seasons/current',
      headers: _jsonHeaders(accessToken: accessToken),
    );
  }

  Future<Map<String, dynamic>> getSeasonLeaderboard({
    required Object seasonId,
    required String mode,
    required String accessToken,
    bool excludePremier = false,
  }) {
    return _apiClient.getJson(
      '/seasons/$seasonId/leaderboard',
      queryParameters: <String, String>{
        'mode': mode,
        if (excludePremier) 'exclude_premier': '1',
      },
      headers: _jsonHeaders(accessToken: accessToken),
    );
  }

  Future<Map<String, dynamic>> registerPushToken({
    required String accessToken,
    required String token,
    required String platform,
    required String deviceId,
    required String appVersion,
  }) {
    return _apiClient.postJson(
      '/push/register',
      headers: _jsonHeaders(accessToken: accessToken),
      body: <String, dynamic>{
        'token': token,
        'platform': platform,
        'device_id': deviceId,
        'app_version': appVersion,
      },
    );
  }

  Future<Map<String, dynamic>> unregisterPushToken({
    required String accessToken,
    required String token,
  }) {
    return _apiClient.postJson(
      '/push/unregister',
      headers: _jsonHeaders(accessToken: accessToken),
      body: <String, dynamic>{'token': token},
    );
  }

  Future<Map<String, dynamic>> requestIntegrityNonce({
    required String accessToken,
    required String deviceId,
  }) {
    return _apiClient.postJson(
      '/mobile/integrity/nonce',
      headers: _jsonHeaders(accessToken: accessToken),
      body: <String, dynamic>{'device_id': deviceId},
    );
  }

  Future<Map<String, dynamic>> verifyIntegrity({
    required String accessToken,
    required String integrityToken,
    required String nonce,
    required String deviceId,
    required String appVersion,
  }) {
    return _apiClient.postJson(
      '/mobile/integrity/verify',
      headers: _jsonHeaders(accessToken: accessToken),
      body: <String, dynamic>{
        'integrity_token': integrityToken,
        'nonce': nonce,
        'device_id': deviceId,
        'app_version': appVersion,
      },
    );
  }

  Future<Map<String, dynamic>> startQuizSession({
    required String accessToken,
    required String mobileSessionToken,
    required String mode,
  }) {
    return _apiClient.postJson(
      '/quiz/sessions/start',
      headers: _jsonHeaders(
        accessToken: accessToken,
        mobileSessionToken: mobileSessionToken,
      ),
      body: <String, dynamic>{'mode': mode},
    );
  }

  Future<Map<String, dynamic>> joinSoloQueue({
    required String accessToken,
    required String mobileSessionToken,
    String mode = 'solo',
  }) {
    return _apiClient.postJson(
      '/quiz/queue/$mode/join',
      headers: _jsonHeaders(
        accessToken: accessToken,
        mobileSessionToken: mobileSessionToken,
      ),
      body: const <String, dynamic>{},
    );
  }

  Future<Map<String, dynamic>> getSoloQueueStatus({
    required String accessToken,
    required String mobileSessionToken,
    required String ticketId,
  }) {
    return _apiClient.getJson(
      '/quiz/queue/$ticketId/status',
      headers: _jsonHeaders(
        accessToken: accessToken,
        mobileSessionToken: mobileSessionToken,
      ),
    );
  }

  Future<Map<String, dynamic>> cancelSoloQueue({
    required String accessToken,
    required String mobileSessionToken,
    required String ticketId,
  }) {
    return _apiClient.postJson(
      '/quiz/queue/$ticketId/cancel',
      headers: _jsonHeaders(
        accessToken: accessToken,
        mobileSessionToken: mobileSessionToken,
      ),
      body: const <String, dynamic>{},
    );
  }

  Future<Map<String, dynamic>> getQuizMatch({
    required String accessToken,
    required String mobileSessionToken,
    required String matchId,
  }) {
    return _apiClient.getJson(
      '/quiz/matches/$matchId',
      headers: _jsonHeaders(
        accessToken: accessToken,
        mobileSessionToken: mobileSessionToken,
      ),
    );
  }

  Future<KvizAdQuotaSnapshot> getQuizAdQuota({
    required String accessToken,
    required String mobileSessionToken,
  }) async {
    final payload = await _apiClient.getJson(
      '/quiz/quota',
      headers: _jsonHeaders(
        accessToken: accessToken,
        mobileSessionToken: mobileSessionToken,
      ),
    );

    return KvizAdQuotaSnapshot.fromJson(payload);
  }

  Future<Map<String, dynamic>> getQuizQuota({required String accessToken}) {
    return _apiClient.getJson(
      '/quiz/quota',
      headers: _jsonHeaders(accessToken: accessToken),
    );
  }

  Future<KvizSubscriptionSnapshot> getQuizSubscriptions({
    required String accessToken,
    required String mobileSessionToken,
  }) async {
    final payload = await _apiClient.getJson(
      '/quiz/subscriptions/me',
      headers: _jsonHeaders(
        accessToken: accessToken,
        mobileSessionToken: mobileSessionToken,
      ),
    );

    return KvizSubscriptionSnapshot.fromJson(payload);
  }

  Future<KvizSubscriptionSnapshot> verifySubscriptionPurchase({
    required String accessToken,
    required String mobileSessionToken,
    required String productId,
    required String purchaseToken,
  }) async {
    final payload = await _apiClient.postJson(
      '/quiz/subscriptions/verify',
      headers: _jsonHeaders(
        accessToken: accessToken,
        mobileSessionToken: mobileSessionToken,
      ),
      body: <String, dynamic>{
        'product_id': productId,
        'purchase_token': purchaseToken,
      },
    );

    return KvizSubscriptionSnapshot.fromJson(payload);
  }

  Future<Map<String, dynamic>> pingPresence({
    required String accessToken,
    required String deviceId,
    required String appVersion,
    String platform = 'android',
  }) {
    return _apiClient.postJson(
      '/quiz/presence',
      headers: _jsonHeaders(accessToken: accessToken),
      body: <String, dynamic>{
        'device_id': deviceId,
        'platform': platform,
        'app_version': appVersion,
      },
    );
  }

  Future<Map<String, dynamic>> grantRewardedGame({
    required String accessToken,
    required String mobileSessionToken,
    required String clientEventId,
    required String adUnitId,
    required String placement,
    String? rewardType,
    num? rewardAmount,
  }) {
    final trimmedRewardType = rewardType?.trim();
    final body = <String, dynamic>{
      'client_event_id': clientEventId,
      'ad_unit_id': adUnitId,
      'placement': placement,
    };
    if (trimmedRewardType != null && trimmedRewardType.isNotEmpty) {
      body['reward_type'] = trimmedRewardType;
    }
    if (rewardAmount != null) {
      body['reward_amount'] = rewardAmount;
    }

    return _apiClient.postJson(
      '/quiz/ad-rewards/grant',
      headers: _jsonHeaders(
        accessToken: accessToken,
        mobileSessionToken: mobileSessionToken,
      ),
      body: body,
    );
  }

  Future<Map<String, dynamic>> getQuizSessionState({
    required String accessToken,
    required String mobileSessionToken,
    required String sessionId,
  }) {
    return _apiClient.getJson(
      '/quiz/sessions/$sessionId/state',
      headers: _jsonHeaders(
        accessToken: accessToken,
        mobileSessionToken: mobileSessionToken,
      ),
    );
  }

  Future<Map<String, dynamic>> submitAnswer({
    required String accessToken,
    required String mobileSessionToken,
    required String sessionId,
    required String roundKey,
    required String questionSource,
    required Object questionId,
    required String clientEventId,
    required Map<String, dynamic> answerPayload,
  }) {
    return _apiClient.postJson(
      '/quiz/sessions/$sessionId/answer',
      headers: _jsonHeaders(
        accessToken: accessToken,
        mobileSessionToken: mobileSessionToken,
      ),
      body: <String, dynamic>{
        'round_key': roundKey,
        'question_source': questionSource,
        'question_id': questionId,
        'client_event_id': clientEventId,
        'answer_payload': answerPayload,
      },
    );
  }

  Future<Map<String, dynamic>> postLifecycleEvent({
    required String accessToken,
    required String mobileSessionToken,
    required String sessionId,
    required String event,
    String? eventTimeClient,
  }) {
    final body = <String, dynamic>{'event': event};

    if (eventTimeClient != null && eventTimeClient.trim().isNotEmpty) {
      body['event_time_client'] = eventTimeClient.trim();
    }

    return _apiClient.postJson(
      '/quiz/sessions/$sessionId/lifecycle',
      headers: _jsonHeaders(
        accessToken: accessToken,
        mobileSessionToken: mobileSessionToken,
      ),
      body: body,
    );
  }

  Future<Map<String, dynamic>> finishQuizSession({
    required String accessToken,
    required String mobileSessionToken,
    required String sessionId,
  }) {
    return _apiClient.postJson(
      '/quiz/sessions/$sessionId/finish',
      headers: _jsonHeaders(
        accessToken: accessToken,
        mobileSessionToken: mobileSessionToken,
      ),
      body: const <String, dynamic>{},
    );
  }

  Future<Map<String, dynamic>> submitContentReport({
    required String accessToken,
    required String mobileSessionToken,
    required String clientReportId,
    required String sessionId,
    required String roundKey,
    required String mode,
    required String contentType,
    required String questionSource,
    required Object questionId,
    required String reason,
    String? associationTarget,
    String? userComment,
    String? suggestedFix,
    Map<String, dynamic>? contentSnapshot,
    Map<String, dynamic>? answerContext,
  }) {
    final body = <String, dynamic>{
      'client_report_id': clientReportId,
      'session_id': sessionId,
      'round_key': roundKey,
      'mode': mode,
      'content_type': contentType,
      'question_source': questionSource,
      'question_id': questionId,
      'reason': reason,
    };

    final trimmedTarget = associationTarget?.trim();
    if (trimmedTarget != null && trimmedTarget.isNotEmpty) {
      body['association_target'] = trimmedTarget;
    }

    final trimmedComment = userComment?.trim();
    if (trimmedComment != null && trimmedComment.isNotEmpty) {
      body['user_comment'] = trimmedComment;
    }

    final trimmedFix = suggestedFix?.trim();
    if (trimmedFix != null && trimmedFix.isNotEmpty) {
      body['suggested_fix'] = trimmedFix;
    }

    if (contentSnapshot != null && contentSnapshot.isNotEmpty) {
      body['content_snapshot'] = contentSnapshot;
    }

    if (answerContext != null && answerContext.isNotEmpty) {
      body['answer_context'] = answerContext;
    }

    return _apiClient.postJson(
      '/quiz/content-reports',
      headers: _jsonHeaders(
        accessToken: accessToken,
        mobileSessionToken: mobileSessionToken,
      ),
      body: body,
    );
  }

  Future<Map<String, dynamic>> getLeaderboard({
    required String mode,
    String period = 'all_time',
    String? accessToken,
    bool excludePremier = false,
  }) {
    return _apiClient.getJson(
      '/leaderboard/$mode',
      queryParameters: <String, String>{
        'period': period,
        if (excludePremier) 'exclude_premier': '1',
      },
      headers: _jsonHeaders(accessToken: accessToken),
    );
  }

  Future<Map<String, dynamic>> getMyLeaderboard({
    required String mode,
    String period = 'all_time',
    required String accessToken,
  }) {
    return _apiClient.getJson(
      '/leaderboard/$mode/me',
      queryParameters: <String, String>{'period': period},
      headers: _jsonHeaders(accessToken: accessToken),
    );
  }

  Map<String, String> _jsonHeaders({
    String? accessToken,
    String? mobileSessionToken,
  }) {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };

    if (accessToken != null && accessToken.trim().isNotEmpty) {
      headers['Authorization'] = 'Bearer ${accessToken.trim()}';
    }

    if (mobileSessionToken != null && mobileSessionToken.trim().isNotEmpty) {
      headers['X-Mobile-Session-Token'] = mobileSessionToken.trim();
    }

    return headers;
  }
}
