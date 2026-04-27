import 'api_client.dart';
import 'api_config.dart';
import 'api_exception.dart';
import 'integrity_flow_service.dart';
import 'laravel_api_service.dart';
import 'play_integrity_service.dart';
import 'ad_reward_quota.dart';
import '../../shared/quiz_modes.dart';
import '../../shared/utils.dart';

/// Result of a session launch attempt.
sealed class SessionLaunchResult {
  const SessionLaunchResult();
}

/// Session was started successfully. Navigate to OnlineSessionPage with these values.
final class SessionLaunchSuccess extends SessionLaunchResult {
  const SessionLaunchSuccess({
    required this.sessionId,
    required this.mobileSessionToken,
    required this.modeKey,
    required this.roundsJson,
  });
  final String sessionId;
  final String mobileSessionToken;
  final String modeKey;
  final List<dynamic> roundsJson;
}

/// Quota exhausted. Show the user an explanation.
final class SessionLaunchQuotaExhausted extends SessionLaunchResult {
  const SessionLaunchQuotaExhausted({
    required this.message,
    required this.quotaSnapshot,
  });
  final String message;
  final KvizAdQuotaSnapshot quotaSnapshot;
}

/// An error occurred. Show the user an error message.
final class SessionLaunchError extends SessionLaunchResult {
  const SessionLaunchError({
    required this.message,
    this.hasActiveSession = false,
    this.quotaSnapshot,
  });
  final String message;
  final bool hasActiveSession;
  final KvizAdQuotaSnapshot? quotaSnapshot;
}

/// Encapsulates the full session-launch flow: Play Integrity → quota → start
/// session. Callers only need to wire up the resulting state in their UI.
class SessionLauncher {
  const SessionLauncher({
    required this.apiConfig,
    required this.accessTokenRefresher,
  });

  final ApiConfig apiConfig;
  final AccessTokenRefresher accessTokenRefresher;

  LaravelApiService _buildApi() {
    return LaravelApiService(
      apiClient: ApiClient(
        baseUrl: apiConfig.baseUrl,
        accessTokenRefresher: accessTokenRefresher,
      ),
    );
  }

  /// Acquire a fresh Play Integrity mobile session token.
  Future<String> acquireMobileSessionToken({
    required String accessToken,
    required String deviceId,
    required String appVersion,
  }) {
    final api = _buildApi();
    return IntegrityFlowService(
      api: api,
      playIntegrity: const PlayIntegrityService(),
    ).acquireMobileSessionToken(
      accessToken: accessToken,
      deviceId: deviceId,
      appVersion: appVersion,
    );
  }

  /// Start a session for [modeKey] and return a [SessionLaunchResult].
  ///
  /// If [skipQuotaCheck] is true the quota gate is skipped (e.g. premier modes
  /// that have unlimited access).
  Future<SessionLaunchResult> launch({
    required String accessToken,
    required String deviceId,
    required String appVersion,
    required String modeKey,
    required bool useCyrillic,
    bool skipQuotaCheck = false,
  }) async {
    KvizAdQuotaSnapshot? quota;

    try {
      // 1. Acquire mobile session token
      final mobileSessionToken = await acquireMobileSessionToken(
        accessToken: accessToken,
        deviceId: deviceId,
        appVersion: appVersion,
      );

      // 2. Quota check
      if (!skipQuotaCheck && usesStandardDailyQuota(modeKey)) {
        final api = _buildApi();
        quota = await api.getQuizAdQuota(
          accessToken: accessToken,
          mobileSessionToken: mobileSessionToken,
        );
        if (!quota.modeUsesStandardQuota(modeKey)) {
          // Premier users have unlimited access; backend remains authoritative.
        } else if (!quota.canStartGame) {
          return SessionLaunchQuotaExhausted(
            message: tr(
              useCyrillic,
              'Danas si iskoristio dostupne partije. U Podešavanjima pogledaj '
                  'nagrađenu reklamu za još jednu partiju.',
              'Данас си искористио доступне партије. У Подешавањима погледај '
                  'награђену рекламу за још једну партију.',
            ),
            quotaSnapshot: quota,
          );
        }
      }

      // 3. Start the session
      final api = _buildApi();
      final startResp = await api.startQuizSession(
        accessToken: accessToken,
        mobileSessionToken: mobileSessionToken,
        mode: modeKey,
      );
      final sessionId = startResp['session_id'] as String? ?? '';
      if (sessionId.isEmpty) {
        return const SessionLaunchError(
          message: 'Neispravan odgovor od servera pri pokretanju sesije.',
        );
      }

      return SessionLaunchSuccess(
        sessionId: sessionId,
        mobileSessionToken: mobileSessionToken,
        modeKey: modeKey,
        roundsJson: (startResp['rounds'] as List<dynamic>?) ?? [],
      );
    } on IntegrityFlowException {
      return const SessionLaunchError(
        message: 'Neispravan odgovor od servera pri pokretanju sesije.',
      );
    } on ApiException catch (error) {
      final activeSessionBlocked =
          error.statusCode == 409 &&
          error.message.toLowerCase().contains('active session');
      return SessionLaunchError(
        message: mapIntegrityError(error, useCyrillic),
        hasActiveSession: activeSessionBlocked,
        quotaSnapshot: quota,
      );
    } catch (error) {
      return SessionLaunchError(
        message: mapIntegrityError(error, useCyrillic),
        quotaSnapshot: quota,
      );
    }
  }
}
