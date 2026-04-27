import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/local/app_repositories.dart';
import '../data/local/kviz_cache.dart';
import '../data/remote/ad_reward_quota.dart';
import '../data/remote/api_client.dart';
import '../data/remote/api_config.dart';
import '../data/remote/analytics_service.dart';
import '../data/remote/auth_models.dart';
import '../data/remote/integrity_flow_service.dart';
import '../data/remote/laravel_api_service.dart';
import '../data/remote/play_games_service.dart';
import '../data/remote/quiz_subscription_status.dart';
import '../data/remote/session_launcher.dart';
import '../domain/entities.dart';
import '../domain/models.dart';
import '../features/queue/solo_queue_page.dart';
import '../shared/quiz_modes.dart';
import '../shared/utils.dart';
import '../shared/widgets/app_title.dart';
import '../shared/widgets/dark_progress_card.dart';
import '../shared/widgets/kviz_bottom_nav.dart';
import '../shared/widgets/leaderboard_entry_tile.dart';
import '../shared/widgets/notice_card.dart';
import '../shared/widgets/section_title.dart';
import '../shared/widgets/toggle_pill.dart';
import 'admob_banner.dart';
import 'home/mode_preview_page.dart';
import 'home/widgets/daily_challenge_card.dart';
import 'home/widgets/hero_card.dart';
import 'home/widgets/mode_badge_icon.dart';
import 'home/widgets/mode_card.dart';
import 'home/widgets/stats_grid.dart';
import 'kviz_theme.dart';
import 'profile/achievements_page.dart';
import 'profile/widgets/profile_info_card.dart';
import 'settings/widgets/iap_subscription_settings_card.dart';
import 'settings/widgets/rewarded_game_settings_card.dart';
import 'settings/widgets/settings_account_panel.dart';
import 'settings/widgets/settings_header_card.dart';
import 'settings/widgets/settings_info_card.dart';
import 'settings/widgets/settings_row.dart';
import 'update_notice_banner.dart';

const _settingsLargeTextKey = 'kviz.settings.large_text';
const _presenceStatsCacheKey = 'presence_stats';
const _textSizeModeSystem = 'system';
const _textSizeModeNormal = 'normal';
const _textSizeModeLarge = 'large';

enum _DailyChallengeChoice { classicOnline, classicSolo, kvizPlus }

class LandingPage extends StatefulWidget {
  const LandingPage({
    super.key,
    required this.repositories,
    required this.useCyrillic,
    required this.themeMode,
    required this.scriptMode,
    required this.onThemeModeChanged,
    required this.onScriptModeChanged,
    required this.onLogoutTap,
    required this.signedInUserLabel,
    required this.authSession,
    required this.deviceId,
    required this.apiConfig,
    required this.accessTokenRefresher,
  });

  final AppRepositories repositories;
  final bool useCyrillic;
  final ThemeMode themeMode;
  final String scriptMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final ValueChanged<String> onScriptModeChanged;
  final VoidCallback onLogoutTap;
  final String signedInUserLabel;
  final AuthSession authSession;
  final String deviceId;
  final ApiConfig apiConfig;
  final AccessTokenRefresher accessTokenRefresher;

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  static const List<String> _statsModes = <String>[
    'solo',
    'solo_duel',
    'pitanja',
    'asocijacije',
    'moj_broj',
    'tangram',
    'kviz_plus',
    premierModeKey,
  ];
  static const List<String> _dailyTaskModes = <String>[
    'pitanja',
    'asocijacije',
    'moj_broj',
  ];

  final KvizCache _cache = KvizCache();
  late Future<LandingStats> _statsFuture;
  late Future<KvizAdQuotaSnapshot> _adQuotaFuture;
  late Future<PresenceStats> _presenceFuture;
  Timer? _presenceTimer;
  String _textSizeMode = _textSizeModeSystem;
  int _selectedTab = 0;
  String _leaderboardMode = 'solo';
  String _leaderboardPeriod = 'all_time';
  bool _leaderboardExcludePremier = false;
  Future<Map<String, dynamic>>? _leaderboardFuture;
  Future<Map<String, dynamic>>? _seasonFuture;
  bool _rewardAdInProgress = false;
  bool _hasNoAdsEntitlement = false;

  String? _rewardMessage;

  String t(String latin, String cyr) => tr(widget.useCyrillic, latin, cyr);

  @override
  void initState() {
    super.initState();
    _statsFuture = _loadStats();
    _adQuotaFuture = _loadAdQuota();
    _presenceFuture = _loadPresenceStats();
    _startPresencePolling();
    unawaited(_refreshAdEntitlements());
    KvizAnalytics.screenView('landing');
    _applyAnalyticsContext();
    _restoreLargeTextPreference();
  }

  @override
  void dispose() {
    _presenceTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant LandingPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.themeMode != widget.themeMode ||
        oldWidget.scriptMode != widget.scriptMode ||
        oldWidget.useCyrillic != widget.useCyrillic) {
      _applyAnalyticsContext();
    }
  }

  Future<void> _restoreLargeTextPreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    final rawMode = prefs.get(_settingsLargeTextKey);
    setState(() {
      if (rawMode == _textSizeModeNormal || rawMode == false) {
        _textSizeMode = _textSizeModeNormal;
      } else if (rawMode == _textSizeModeLarge || rawMode == true) {
        _textSizeMode = _textSizeModeLarge;
      } else {
        _textSizeMode = _textSizeModeSystem;
      }
    });
    _applyAnalyticsContext();
  }

  void _setTextSizeMode(String value) {
    KvizAnalytics.uiAction(
      screen: 'settings',
      area: 'display',
      target: 'text_size_$value',
    );
    setState(() {
      _textSizeMode = value;
    });
    _applyAnalyticsContext();
    unawaited(_saveTextSizeMode(value));
  }

  void _applyAnalyticsContext() {
    KvizAnalytics.setAppContext(
      appVersion: widget.apiConfig.appVersion,
      theme: widget.themeMode.name,
      useCyrillic: widget.useCyrillic,
      largeText: _textSizeMode == _textSizeModeLarge,
      signedIn: true,
    );
  }

  Future<void> _saveTextSizeMode(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_settingsLargeTextKey, value);
  }

  SessionLauncher get _sessionLauncher => SessionLauncher(
    apiConfig: widget.apiConfig,
    accessTokenRefresher: widget.accessTokenRefresher,
  );

  LaravelApiService _newLaravelApi() {
    return LaravelApiService(
      apiClient: ApiClient(
        baseUrl: widget.apiConfig.baseUrl,
        accessTokenRefresher: widget.accessTokenRefresher,
      ),
    );
  }

  Future<String> _acquireMobileSessionToken() {
    return _sessionLauncher.acquireMobileSessionToken(
      accessToken: widget.authSession.accessToken,
      deviceId: widget.deviceId,
      appVersion: widget.apiConfig.appVersion,
    );
  }

  Future<KvizAdQuotaSnapshot> _loadAdQuota() async {
    final api = _newLaravelApi();
    final mobileSessionToken = await _acquireMobileSessionToken();
    return api.getQuizAdQuota(
      accessToken: widget.authSession.accessToken,
      mobileSessionToken: mobileSessionToken,
    );
  }

  Future<PresenceStats> _loadPresenceStats() async {
    return _cache.fetch(_presenceStatsCacheKey, () async {
      final payload = await _newLaravelApi().pingPresence(
        accessToken: widget.authSession.accessToken,
        deviceId: widget.deviceId,
        appVersion: widget.apiConfig.appVersion,
      );

      return PresenceStats.fromJson(payload);
    }, ttl: const Duration(seconds: 30));
  }

  void _startPresencePolling() {
    _presenceTimer?.cancel();
    _presenceTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _refreshPresence();
    });
  }

  void _refreshPresence({bool force = false}) {
    if (!mounted) return;
    if (force) {
      _cache.invalidate(_presenceStatsCacheKey);
    }
    setState(() {
      _presenceFuture = _loadPresenceStats();
    });
  }

  void _refreshAdQuota() {
    if (!mounted) return;
    setState(() {
      _adQuotaFuture = _loadAdQuota();
    });
  }

  Widget _buildTopAdBanner() {
    if (_hasNoAdsEntitlement) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<KvizAdQuotaSnapshot>(
      future: _adQuotaFuture,
      builder: (context, snapshot) {
        final quota = snapshot.data;
        if (snapshot.connectionState != ConnectionState.done ||
            quota == null ||
            !quota.shouldShowAds) {
          return const SizedBox.shrink();
        }

        return const KvizAdMobBanner();
      },
    );
  }

  Future<KvizSubscriptionSnapshot> _loadSubscriptionStatus() async {
    final api = _newLaravelApi();
    final mobileSessionToken = await _acquireMobileSessionToken();
    final status = await api.getQuizSubscriptions(
      accessToken: widget.authSession.accessToken,
      mobileSessionToken: mobileSessionToken,
    );
    _applyAdEntitlement(status);
    return status;
  }

  Future<KvizSubscriptionSnapshot> _verifySubscriptionPurchase(
    String productId,
    String purchaseToken,
  ) async {
    final api = _newLaravelApi();
    final mobileSessionToken = await _acquireMobileSessionToken();
    final status = await api.verifySubscriptionPurchase(
      accessToken: widget.authSession.accessToken,
      mobileSessionToken: mobileSessionToken,
      productId: productId,
      purchaseToken: purchaseToken,
    );
    _applyAdEntitlement(status);
    return status;
  }

  Future<void> _refreshAdEntitlements() async {
    try {
      await _loadSubscriptionStatus();
    } catch (_) {
      // Quota remains the primary source; subscription refresh is best-effort.
    }
  }

  void _applyAdEntitlement(KvizSubscriptionSnapshot status) {
    final removesAds =
        status.adsRemoved || status.hasNoAds || status.hasPremier;
    if (_hasNoAdsEntitlement == removesAds) {
      return;
    }
    if (!mounted) {
      _hasNoAdsEntitlement = removesAds;
      return;
    }
    setState(() => _hasNoAdsEntitlement = removesAds);
  }

  Future<void> _watchRewardedAdForBonusGame() async {
    if (_rewardAdInProgress) {
      return;
    }

    KvizAnalytics.uiAction(
      screen: 'settings',
      area: 'rewarded_games',
      target: 'watch_rewarded_ad',
    );

    setState(() {
      _rewardAdInProgress = true;
      _rewardMessage = null;
    });

    try {
      final api = _newLaravelApi();
      final mobileSessionToken = await _acquireMobileSessionToken();
      final currentQuota = await api.getQuizAdQuota(
        accessToken: widget.authSession.accessToken,
        mobileSessionToken: mobileSessionToken,
      );
      if (!currentQuota.canGrantReward) {
        if (!mounted) return;
        KvizAnalytics.rewardQuotaExhausted();
        setState(() {
          _rewardMessage = t(
            'Danas si iskoristio sve bonus reklame.',
            'Данас си искористио све бонус рекламе.',
          );
          _adQuotaFuture = Future.value(currentQuota);
        });
        return;
      }

      final earned = await const KvizAdMobFullScreenAds().showRewarded(
        placement: 'settings_bonus_game',
      );
      if (!mounted) {
        return;
      }

      if (!earned) {
        setState(() {
          _rewardMessage = t(
            'Reklama nije završena. Bonus partija nije dodata.',
            'Реклама није завршена. Бонус партија није додата.',
          );
        });
        return;
      }

      final grantResp = await api.grantRewardedGame(
        accessToken: widget.authSession.accessToken,
        mobileSessionToken: mobileSessionToken,
        clientEventId: _newRewardClientEventId(),
        adUnitId: KvizAdMob.androidRewardedAdUnitId,
        placement: 'settings_bonus_game',
        rewardType: 'game',
        rewardAmount: 1,
      );
      final quotaPayload = grantResp['quota'];
      final updated = quotaPayload is Map
          ? KvizAdQuotaSnapshot.fromJson(
              quotaPayload.map(
                (key, dynamic value) => MapEntry(key.toString(), value),
              ),
            )
          : await api.getQuizAdQuota(
              accessToken: widget.authSession.accessToken,
              mobileSessionToken: mobileSessionToken,
            );
      if (!mounted) {
        return;
      }
      KvizAnalytics.event(
        'rewarded_game_granted',
        parameters: <String, Object?>{
          'reward_grants_today': updated.rewardGrantsToday,
          'games_started_today': updated.gamesStartedToday,
        },
      );
      setState(() {
        _rewardMessage = t(
          'Dodata je jedna bonus partija za danas.',
          'Додата је једна бонус партија за данас.',
        );
        _adQuotaFuture = Future.value(updated);
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _rewardMessage = mapIntegrityError(error, widget.useCyrillic);
        _adQuotaFuture = _loadAdQuota();
      });
    } finally {
      if (mounted) {
        setState(() => _rewardAdInProgress = false);
      }
    }
  }

  String _newRewardClientEventId() {
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final deviceHash = widget.deviceId.hashCode.abs();
    return 'reward_${timestamp}_$deviceHash';
  }

  bool _effectiveLargeText(MediaQueryData media) {
    if (_textSizeMode == _textSizeModeLarge) {
      return true;
    }
    if (_textSizeMode == _textSizeModeNormal) {
      return false;
    }

    return media.textScaler.scale(16) >= 17.2;
  }

  Future<LandingStats> _loadStats() async {
    return _cache.fetch('landing_stats', _loadStatsInternal);
  }

  Future<LandingStats> _loadStatsInternal() async {
    final timers = await _loadTimerMap();
    final playerStats = await _loadPlayerStats();
    final quotaStats = await _loadQuotaStats();

    return LandingStats(
      timers: timers,
      playerStats: playerStats,
      quota: quotaStats,
    );
  }

  Future<QuotaStats> _loadQuotaStats() async {
    try {
      final api = _newLaravelApi();
      final accessToken = widget.authSession.accessToken;
      final quota = await api.getQuizQuota(accessToken: accessToken);
      return QuotaStats(streak: _asInt(quota['streak']));
    } catch (_) {
      return QuotaStats.empty();
    }
  }

  Future<Map<String, int>> _loadTimerMap() async {
    try {
      return await widget.repositories.timerConfigRepository.fetchTimerMap();
    } catch (_) {
      return LandingStats.empty().timers;
    }
  }

  Future<PlayerStats> _loadPlayerStats() async {
    final api = _newLaravelApi();
    final accessToken = widget.authSession.accessToken;
    final allTimeResponses = await Future.wait(
      _statsModes.map(
        (mode) => _loadMyLeaderboardEntry(
          api: api,
          mode: mode,
          period: 'all_time',
          accessToken: accessToken,
        ),
      ),
    );
    final dailyResponses = await Future.wait(
      _statsModes.map(
        (mode) => _loadMyLeaderboardEntry(
          api: api,
          mode: mode,
          period: 'daily',
          accessToken: accessToken,
        ),
      ),
    );

    final allTimeEntries = <String, Map<String, dynamic>>{};
    final dailyEntries = <String, Map<String, dynamic>>{};
    for (var i = 0; i < _statsModes.length; i += 1) {
      allTimeEntries[_statsModes[i]] = allTimeResponses[i];
      dailyEntries[_statsModes[i]] = dailyResponses[i];
    }

    final totalScore = allTimeEntries.values.fold<int>(
      0,
      (sum, entry) => sum + _asInt(entry['score']),
    );
    final totalGames = allTimeEntries.values.fold<int>(
      0,
      (sum, entry) => sum + _asInt(entry['games_played']),
    );
    final wins = allTimeEntries.values.fold<int>(
      0,
      (sum, entry) => sum + _asInt(entry['wins']),
    );
    final losses = allTimeEntries.values.fold<int>(
      0,
      (sum, entry) => sum + _asInt(entry['losses']),
    );
    final draws = allTimeEntries.values.fold<int>(
      0,
      (sum, entry) => sum + _asInt(entry['draws']),
    );
    final ranks = allTimeEntries.values
        .map((entry) => _asNullableInt(entry['rank']))
        .whereType<int>()
        .toList(growable: false);
    final bestRank = ranks.isEmpty
        ? null
        : ranks.reduce((a, b) => a < b ? a : b);
    final dailyChallengeDone =
        _asInt(dailyEntries['kviz_plus']?['games_played']) > 0;
    final dailyCompletedTasks = dailyChallengeDone
        ? PlayerStats.dailyTaskGoal
        : _dailyTaskModes
              .where((mode) => _asInt(dailyEntries[mode]?['games_played']) > 0)
              .length;

    final clampedDailyTasks = dailyCompletedTasks > PlayerStats.dailyTaskGoal
        ? PlayerStats.dailyTaskGoal
        : dailyCompletedTasks;

    final playerStats = PlayerStats(
      totalScore: totalScore,
      gamesPlayed: totalGames,
      wins: wins,
      losses: losses,
      draws: draws,
      rank: ranks.isEmpty ? 0 : ranks.first,
      bestRank: bestRank,
      dailyCompletedTasks: clampedDailyTasks < 0 ? 0 : clampedDailyTasks,
    );
    unawaited(_syncProfileAchievements(playerStats));
    return playerStats;
  }

  Future<void> _syncProfileAchievements(PlayerStats playerStats) async {
    try {
      await const PlayGamesService().syncProfileAchievements(
        gamesPlayed: playerStats.gamesPlayed,
        totalScore: playerStats.totalScore,
        bestRank: playerStats.bestRank,
        dailyCompletedTasks: playerStats.dailyCompletedTasks,
        userKey: achievementUserKeyForSession(widget.authSession),
      );
      KvizAnalytics.achievementUnlocked(
        achievementKey: 'profile_sync',
        source: 'stats_loaded',
      );
    } catch (_) {
      // Server stats must still render if Google Play services are unavailable.
    }
  }

  Future<Map<String, dynamic>> _loadMyLeaderboardEntry({
    required LaravelApiService api,
    required String mode,
    required String period,
    required String accessToken,
  }) async {
    try {
      return _extractLeaderboardEntry(
        await api.getMyLeaderboard(
          mode: mode,
          period: period,
          accessToken: accessToken,
        ),
      );
    } catch (_) {
      // Primary /me endpoint failed; fall back to public leaderboard.
      // If this also fails, let the exception propagate so the caller
      // knows the backend is unreachable instead of silently showing zeros.
      final fallback = await api.getLeaderboard(
        mode: mode,
        period: period,
        accessToken: accessToken,
      );
      final entries = (fallback['entries'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (entry) => entry.map(
              (key, dynamic value) => MapEntry(key.toString(), value),
            ),
          );
      final userId = widget.authSession.user.id;
      if (userId == null) {
        return const <String, dynamic>{};
      }

      return entries.firstWhere(
        (entry) => _asNullableInt(entry['user_id']) == userId,
        orElse: () => const <String, dynamic>{},
      );
    }
  }

  Map<String, dynamic> _extractLeaderboardEntry(Map<String, dynamic> payload) {
    final entry = payload['entry'];
    if (entry is Map<String, dynamic>) {
      return entry;
    }
    if (entry is Map) {
      return entry.map((key, dynamic value) => MapEntry(key.toString(), value));
    }

    return const <String, dynamic>{};
  }

  Map<String, dynamic>? _mapFrom(Object? raw) {
    if (raw is Map<String, dynamic>) {
      return raw;
    }
    if (raw is Map) {
      return raw.map((key, dynamic value) => MapEntry(key.toString(), value));
    }

    return null;
  }

  int _asInt(dynamic value) => _asNullableInt(value) ?? 0;

  int? _asNullableInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  void _refreshStats() {
    if (!mounted) return;
    _cache.invalidateByPrefix('landing');
    _cache.invalidateByPrefix('my_leaderboard');
    _cache.invalidateByPrefix('leaderboard_');
    _cache.invalidate(_presenceStatsCacheKey);
    setState(() {
      _statsFuture = _loadStats();
      _presenceFuture = _loadPresenceStats();
    });
  }

  List<RoundInfo> _buildRounds(String modeKey) {
    final koZnaZna = RoundInfo(
      gameKey: 'ko_zna_zna',
      title: t('Ko zna zna', 'Ко зна зна'),
    );
    final asocijacije = RoundInfo(
      gameKey: 'asocijacije',
      title: t('Asocijacije', 'Асоцијације'),
    );
    final mojBroj = RoundInfo(
      gameKey: 'moj_broj',
      title: t('Moj Broj', 'Мој Број'),
    );
    final tangram = RoundInfo(
      gameKey: 'tangram',
      title: t('Tangram', 'Танграм'),
    );

    if (modeKey == 'kviz_plus' || modeKey == premierModeKey) {
      return [koZnaZna, asocijacije, mojBroj, tangram];
    }
    return [koZnaZna, asocijacije, mojBroj];
  }

  List<RoundInfo> _buildGameRounds(String gameKey) {
    final titleByKey = <String, String>{
      'ko_zna_zna': t('Pitanja', 'Питања'),
      'asocijacije': t('Asocijacije', 'Асоцијације'),
      'moj_broj': t('Moj Broj', 'Мој Број'),
      'tangram': t('Tangram+', 'Танграм+'),
    };

    if (gameKey == 'daily') {
      return _buildRounds('kviz_plus');
    }

    if (gameKey == 'tangram') {
      return [
        RoundInfo(gameKey: 'tangram', title: t('Tangram 1', 'Танграм 1')),
        RoundInfo(gameKey: 'tangram', title: t('Tangram 2', 'Танграм 2')),
      ];
    }

    return [RoundInfo(gameKey: gameKey, title: titleByKey[gameKey] ?? gameKey)];
  }

  void _openModePreview({
    required String modeKey,
    required String modeTitle,
    required String modeDescription,
    required List<RoundInfo> rounds,
    required Map<String, int> timersByGame,
    String source = 'home',
    String? onlineModeKey,
    bool isDuel = false,
  }) {
    KvizAnalytics.modeSelected(
      mode: modeKey,
      onlineMode: onlineModeKey,
      source: source,
    );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ModePreviewPage(
          modeKey: modeKey,
          onlineModeKey: onlineModeKey,
          modeTitle: modeTitle,
          modeDescription: modeDescription,
          rounds: rounds,
          timersByGame: timersByGame,
          repositories: widget.repositories,
          useCyrillic: widget.useCyrillic,
          authSession: widget.authSession,
          deviceId: widget.deviceId,
          apiConfig: widget.apiConfig,
          accessTokenRefresher: widget.accessTokenRefresher,
          onAdQuotaChanged: _refreshAdQuota,
          adsRemoved: _hasNoAdsEntitlement,
          onLeaderboardUpdated: _handleLeaderboardUpdated,
          onSessionCompleted: _refreshStats,
          isDuel: isDuel,
        ),
      ),
    );
  }

  void _openDuelQueueFromPresence({
    required String modeKey,
    required String modeTitle,
  }) {
    KvizAnalytics.uiAction(
      screen: 'home',
      area: 'presence',
      target: 'join_$modeKey',
    );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SoloQueuePage(
          modeKey: modeKey,
          modeTitle: modeTitle,
          useCyrillic: widget.useCyrillic,
          authSession: widget.authSession,
          deviceId: widget.deviceId,
          apiConfig: widget.apiConfig,
          accessTokenRefresher: widget.accessTokenRefresher,
          onAdQuotaChanged: _refreshAdQuota,
          onLeaderboardUpdated: _handleLeaderboardUpdated,
          onSessionCompleted: _refreshStats,
        ),
      ),
    );
  }

  Future<void> _openDailyChallengePicker(
    Map<String, int> timersByGame, {
    required String source,
  }) async {
    KvizAnalytics.uiAction(
      screen: source == 'app_bar' ? 'landing' : 'home',
      area: 'daily_challenge',
      target: 'choose_mode',
    );

    final choice = await showModalBottomSheet<_DailyChallengeChoice>(
      context: context,
      useSafeArea: true,
      backgroundColor: context.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.local_fire_department_rounded,
                    color: context.scoreColor,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      t('Izaberi dnevni izazov', 'Изабери дневни изазов'),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: context.strongText,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _dailyChallengeOption(
                sheetContext,
                choice: _DailyChallengeChoice.classicOnline,
                icon: Icons.groups_rounded,
                title: t('Klasičan kviz online', 'Класичан квиз онлајн'),
                subtitle: t(
                  'Traži protivnika za 3 runde.',
                  'Тражи противника за 3 рунде.',
                ),
              ),
              const SizedBox(height: 8),
              _dailyChallengeOption(
                sheetContext,
                choice: _DailyChallengeChoice.classicSolo,
                icon: Icons.person_rounded,
                title: t('Klasičan kviz solo', 'Класичан квиз соло'),
                subtitle: t(
                  'Igraj samostalno bez čekanja protivnika.',
                  'Играј самостално без чекања противника.',
                ),
              ),
              const SizedBox(height: 8),
              _dailyChallengeOption(
                sheetContext,
                choice: _DailyChallengeChoice.kvizPlus,
                icon: Icons.extension_rounded,
                title: t('Kviz+', 'Квиз+'),
                subtitle: t(
                  'Duel sa 4 runde, uključujući Tangram.',
                  'Дуел са 4 рунде, укључујући Танграм.',
                ),
              ),
            ],
          ),
        );
      },
    );

    if (!mounted || choice == null) {
      return;
    }

    switch (choice) {
      case _DailyChallengeChoice.classicOnline:
        _openModePreview(
          modeKey: 'kviz',
          onlineModeKey: 'kviz',
          isDuel: true,
          source: source,
          modeTitle: t('Kviz Duel', 'Квиз Дуел'),
          modeDescription: t(
            'Klasičan dnevni duel sa pitanjima, asocijacijama i Moj Broj rundom.',
            'Класичан дневни дуел са питањима, асоцијацијама и Мој Број рундом.',
          ),
          rounds: _buildRounds('kviz'),
          timersByGame: timersByGame,
        );
      case _DailyChallengeChoice.classicSolo:
        _openModePreview(
          modeKey: 'solo',
          onlineModeKey: 'solo',
          source: source,
          modeTitle: t('Kviz Solo', 'Квиз Соло'),
          modeDescription: t(
            'Klasična solo partija sa tri runde. Rezultat ide na Solo rang listu.',
            'Класична соло партија са три рунде. Резултат иде на Соло ранг листу.',
          ),
          rounds: _buildRounds('solo'),
          timersByGame: timersByGame,
        );
      case _DailyChallengeChoice.kvizPlus:
        _openModePreview(
          modeKey: 'kviz_plus',
          onlineModeKey: 'kviz_plus',
          isDuel: true,
          source: source,
          modeTitle: t('Kviz+ Duel', 'Квиз+ Дуел'),
          modeDescription: t(
            'Dnevni Kviz+ duel sa četiri runde, uključujući Tangram.',
            'Дневни Квиз+ дуел са четири рунде, укључујући Танграм.',
          ),
          rounds: _buildRounds('kviz_plus'),
          timersByGame: timersByGame,
        );
    }
  }

  Widget _dailyChallengeOption(
    BuildContext sheetContext, {
    required _DailyChallengeChoice choice,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Material(
      color: context.innerBg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.of(sheetContext).pop(choice),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: context.actionBlue, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: context.strongText,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: context.mutedText,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: context.mutedText),
            ],
          ),
        ),
      ),
    );
  }

  Future<Map<String, dynamic>> _loadLeaderboard() {
    final excludePremier =
        _leaderboardMode != premierModeKey && _leaderboardExcludePremier;
    final cacheKey =
        'leaderboard_${_leaderboardMode}_${_leaderboardPeriod}_exclude_premier_$excludePremier';
    return _cache.fetch(cacheKey, () async {
      final api = _newLaravelApi();
      if (_leaderboardPeriod == 'season') {
        return _loadSeasonLeaderboard(api, excludePremier: excludePremier);
      }
      return api.getLeaderboard(
        mode: _leaderboardMode,
        period: _leaderboardPeriod,
        accessToken: widget.authSession.accessToken,
        excludePremier: excludePremier,
      );
    }, ttl: const Duration(seconds: 30));
  }

  Future<Map<String, dynamic>> _loadCurrentSeason() {
    final api = _newLaravelApi();

    return api.getCurrentSeason(accessToken: widget.authSession.accessToken);
  }

  Future<Map<String, dynamic>> _loadSeasonLeaderboard(
    LaravelApiService api, {
    bool excludePremier = false,
  }) async {
    final seasonPayload = await (_seasonFuture ??= _loadCurrentSeason());
    final season = _mapFrom(seasonPayload['season']);
    final seasonId = season?['id'];
    if (seasonId == null) {
      return <String, dynamic>{
        'mode': _leaderboardMode,
        'period': 'season',
        'entries': const <Map<String, dynamic>>[],
      };
    }

    final payload = await api.getSeasonLeaderboard(
      seasonId: seasonId,
      mode: _leaderboardMode,
      accessToken: widget.authSession.accessToken,
      excludePremier: excludePremier,
    );
    payload['period'] = 'season';
    return payload;
  }

  void _refreshLeaderboard() {
    KvizAnalytics.uiAction(
      screen: 'leaderboard',
      area: 'leaderboard',
      target: 'refresh',
      parameters: <String, Object?>{
        'mode': _leaderboardMode,
        'period': _leaderboardPeriod,
      },
    );
    setState(() {
      _cache.invalidateByPrefix('leaderboard_');
      if (_leaderboardPeriod == 'season') {
        _seasonFuture = _loadCurrentSeason();
      }
      _leaderboardFuture = _loadLeaderboard();
    });
  }

  void _handleLeaderboardUpdated(String mode) {
    final normalizedMode = mode.trim();
    if (normalizedMode.isEmpty) return;

    _cache.invalidateByPrefix('leaderboard_');
    setState(() {
      _leaderboardMode = normalizedMode;
      if (normalizedMode == premierModeKey) {
        _leaderboardExcludePremier = false;
      }
      _leaderboardFuture = _selectedTab == 1 ? _loadLeaderboard() : null;
    });
  }

  Future<void> _openAchievementsPage(LandingStats stats) async {
    KvizAnalytics.uiAction(
      screen: 'profile',
      area: 'achievements',
      target: 'open',
    );
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AchievementsPage(
          useCyrillic: widget.useCyrillic,
          userKey: achievementUserKeyForSession(widget.authSession),
          stats: stats.playerStats,
          apiConfig: widget.apiConfig,
          accessToken: widget.authSession.accessToken,
          accessTokenRefresher: widget.accessTokenRefresher,
        ),
      ),
    );
  }

  Future<void> _openGooglePlayLeaderboard() async {
    if (!PlayGamesService.hasGoogleLeaderboardForMode(_leaderboardMode)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t(
              'Google Play rang lista nije povezana za ovaj mod.',
              'Google Play ранг листа није повезана за овај мод.',
            ),
          ),
        ),
      );
      return;
    }

    KvizAnalytics.uiAction(
      screen: 'leaderboard',
      area: 'leaderboard',
      target: 'google_play_open',
      parameters: <String, Object?>{'mode': _leaderboardMode},
    );
    final service = const PlayGamesService();
    final opened = await service.showLeaderboard(_leaderboardMode);
    if (!mounted || opened) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          t(
            'Google Play rang liste trenutno nisu dostupne.',
            'Google Play ранг листе тренутно нису доступне.',
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LandingStats>(
      future: _statsFuture,
      builder: (context, snapshot) {
        final hasError = snapshot.hasError;
        final isLoading = snapshot.connectionState != ConnectionState.done;
        final stats = hasError || !snapshot.hasData
            ? LandingStats.empty()
            : snapshot.data!;

        final baseMedia = MediaQuery.of(context);
        final effectiveLargeText = _effectiveLargeText(baseMedia);
        final media = baseMedia.copyWith(
          textScaler: TextScaler.linear(effectiveLargeText ? 1.12 : 1.0),
        );

        return MediaQuery(
          data: media,
          child: Scaffold(
            backgroundColor: context.pageBg,
            appBar: AppBar(
              backgroundColor: context.pageBg,
              elevation: 0,
              leading: IconButton(
                icon: Icon(Icons.menu_rounded, color: context.strongText),
                onPressed: () {
                  KvizAnalytics.uiAction(
                    screen: _tabAnalyticsName(_selectedTab),
                    area: 'app_bar',
                    target: 'settings',
                  );
                  setState(() => _selectedTab = 3);
                },
              ),
              title: AppTitle(text: _tabTitle()),
              centerTitle: true,
              actions: [
                IconButton(
                  tooltip: t('Dnevni izazov', 'Дневни изазов'),
                  icon: Icon(
                    Icons.local_fire_department_rounded,
                    color: context.strongText,
                  ),
                  onPressed: () {
                    KvizAnalytics.uiAction(
                      screen: 'landing',
                      area: 'app_bar',
                      target: 'daily_challenge',
                    );
                    _openDailyChallengePicker(stats.timers, source: 'app_bar');
                  },
                ),
              ],
            ),
            bottomNavigationBar: KvizBottomNav(
              useCyrillic: widget.useCyrillic,
              selectedIndex: _selectedTab,
              onTap: (index) {
                KvizAnalytics.uiAction(
                  screen: _tabAnalyticsName(_selectedTab),
                  area: 'bottom_nav',
                  target: _tabAnalyticsName(index),
                  parameters: <String, Object?>{
                    'from_tab': _tabAnalyticsName(_selectedTab),
                    'to_tab': _tabAnalyticsName(index),
                  },
                );
                setState(() {
                  _selectedTab = index;
                  if (index == 1) {
                    _leaderboardFuture ??= _loadLeaderboard();
                  }
                });
                switch (index) {
                  case 0:
                    KvizAnalytics.homeTabOpened();
                  case 1:
                    KvizAnalytics.leaderboardTabOpened(
                      mode: _leaderboardMode,
                      period: _leaderboardPeriod,
                    );
                  case 2:
                    KvizAnalytics.profileTabOpened();
                  case 3:
                    KvizAnalytics.settingsTabOpened();
                }
              },
            ),
            body: Column(
              children: [
                _buildTopAdBanner(),
                KvizUpdateNoticeBanner(useCyrillic: widget.useCyrillic),
                Expanded(
                  child: SafeArea(
                    bottom: false,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 900),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                          child: _buildSelectedTab(
                            stats,
                            isLoading,
                            hasError,
                            effectiveLargeText,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _tabTitle() {
    return switch (_selectedTab) {
      1 => t('Rang lista', 'Ранг листа'),
      2 => t('Profil', 'Профил'),
      3 => t('Podešavanja', 'Подешавања'),
      _ => 'Kviz DBase',
    };
  }

  String _tabAnalyticsName(int index) {
    return switch (index) {
      1 => 'leaderboard',
      2 => 'profile',
      3 => 'settings',
      _ => 'home',
    };
  }

  Widget _buildSelectedTab(
    LandingStats stats,
    bool isLoading,
    bool hasStatsError,
    bool effectiveLargeText,
  ) {
    return switch (_selectedTab) {
      1 => _buildLeaderboardTab(),
      2 => _buildProfileTab(stats, isLoading, hasStatsError),
      3 => _buildSettingsTab(effectiveLargeText),
      _ => _buildHomeTab(stats, isLoading, hasStatsError),
    };
  }

  Widget _buildHomeTab(LandingStats stats, bool isLoading, bool hasStatsError) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HeroCard(
          isLoading: isLoading || hasStatsError,
          stats: stats,
          useCyrillic: widget.useCyrillic,
          signedInUserLabel: widget.signedInUserLabel,
          avatarUrl: widget.authSession.user.avatarUrl,
        ),
        const SizedBox(height: 20),
        SectionTitle(title: t('Duel partije', 'Дуел партије')),
        FutureBuilder<PresenceStats>(
          future: _presenceFuture,
          builder: (context, snapshot) {
            return _buildPresenceCard(
              presence: snapshot.data,
              isLoading: snapshot.connectionState != ConnectionState.done,
              hasError: snapshot.hasError,
            );
          },
        ),
        const SizedBox(height: 10),
        ModeCard(
          badge: const ModeBadgeIcon(kind: ModeKind.quiz),
          title: t('Kviz Duel', 'Квиз Дуел'),
          subtitle: t(
            'Duel sa protivnikom (3 runde: Pitanja, Asocijacije, Moj Broj)',
            'Дуел са противником (3 рунде: Питања, Асоцијације, Мој Број)',
          ),
          accent: context.actionBlue,
          cta: '',
          onTap: () => _openModePreview(
            modeKey: 'kviz',
            onlineModeKey: 'kviz',
            isDuel: true,
            source: 'home_card',
            modeTitle: t('Kviz Duel', 'Квиз Дуел'),
            modeDescription: t(
              'Pronađi protivnika i pokaži ko je bolji u tri runde.',
              'Пронађи противника и покажи ко је бољи у три рунде.',
            ),
            rounds: _buildRounds('kviz'),
            timersByGame: stats.timers,
          ),
        ),
        const SizedBox(height: 10),
        ModeCard(
          badge: const ModeBadgeIcon(kind: ModeKind.tangram),
          title: t('Kviz+ Duel', 'Квиз+ Дуел'),
          subtitle: t(
            'Duel sa protivnikom (4 runde: + Tangram)',
            'Дуел са противником (4 рунде: + Танграм)',
          ),
          accent: const Color(0xFFEF5350),
          cta: '',
          onTap: () => _openModePreview(
            modeKey: 'kviz_plus',
            onlineModeKey: 'kviz_plus',
            isDuel: true,
            source: 'home_card',
            modeTitle: t('Kviz+ Duel', 'Квиз+ Дуел'),
            modeDescription: t(
              'Full duel partija sa četiri runde, uključujući i Tangram+.',
              'Пун дуел са четири рунде, укључујући и Танграм+.',
            ),
            rounds: _buildRounds('kviz_plus'),
            timersByGame: stats.timers,
          ),
        ),
        FutureBuilder<KvizAdQuotaSnapshot>(
          future: _adQuotaFuture,
          builder: (context, snapshot) {
            final hasPremier = snapshot.data?.hasPremier ?? false;
            if (!hasPremier) {
              return const SizedBox.shrink();
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 10),
                ModeCard(
                  badge: const ModeBadgeIcon(kind: ModeKind.premier),
                  title: t('Premier Kviz', 'Премијер Квиз'),
                  subtitle: t(
                    'Duel samo za Premier ligu, sa posebnom rang listom',
                    'Дуел само за Премијер лигу, са посебном ранг листом',
                  ),
                  accent: const Color(0xFFE0A800),
                  cta: '',
                  onTap: () => _openModePreview(
                    modeKey: premierModeKey,
                    onlineModeKey: premierModeKey,
                    isDuel: true,
                    source: 'home_card',
                    modeTitle: t('Premier Kviz', 'Премијер Квиз'),
                    modeDescription: t(
                      'Premier duel sa četiri runde i rang listom odvojenom od standardne lige.',
                      'Премијер дуел са четири рунде и ранг листом одвојеном од стандардне лиге.',
                    ),
                    rounds: _buildRounds(premierModeKey),
                    timersByGame: stats.timers,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        SectionTitle(title: t('Solo igranje', 'Соло играње')),
        ModeCard(
          badge: const ModeBadgeIcon(kind: ModeKind.quiz),
          title: t('Kviz Solo', 'Квиз Соло'),
          subtitle: t(
            'Igraj samostalno za solo rang listu (3 runde)',
            'Играј самостално за соло ранг листу (3 рунде)',
          ),
          accent: const Color(0xFF2E7D32),
          cta: '',
          onTap: () => _openModePreview(
            modeKey: 'solo',
            onlineModeKey: 'solo',
            isDuel: false,
            source: 'home_card',
            modeTitle: t('Kviz Solo', 'Квиз Соло'),
            modeDescription: t(
              'Klasična solo partija sa tri runde. Rezultat ide na Solo rang listu.',
              'Класична соло партија са три рунде. Резултат иде на Соло ранг листу.',
            ),
            rounds: _buildRounds('solo'),
            timersByGame: stats.timers,
          ),
        ),
        const SizedBox(height: 10),
        ModeCard(
          badge: const ModeBadgeIcon(kind: ModeKind.questions),
          title: t('Pitanja', 'Питања'),
          subtitle: t(
            'Odgovori na pitanja iz opšte kulture',
            'Одговори на питања из опште културе',
          ),
          accent: const Color(0xFF4FC3F7),
          cta: '',
          onTap: () => _openModePreview(
            modeKey: 'questions',
            onlineModeKey: 'pitanja',
            source: 'home_card',
            modeTitle: t('Pitanja', 'Питања'),
            modeDescription: t(
              'Online runda sa pitanjima i slobodnim unosom odgovora.',
              'Онлајн рунда са питањима и слободним уносом одговора.',
            ),
            rounds: _buildGameRounds('ko_zna_zna'),
            timersByGame: stats.timers,
          ),
        ),
        const SizedBox(height: 10),
        ModeCard(
          badge: const ModeBadgeIcon(kind: ModeKind.associations),
          title: t('Asocijacije', 'Асоцијације'),
          subtitle: t(
            'Poveži pojmove i pogodi rešenje',
            'Повежи појмове и погоди решење',
          ),
          accent: const Color(0xFFEF5350),
          cta: '',
          onTap: () => _openModePreview(
            modeKey: 'associations',
            onlineModeKey: 'asocijacije',
            source: 'home_card',
            modeTitle: t('Asocijacije', 'Асоцијације'),
            modeDescription: t(
              'Pogodi konačno rešenje iz četiri kolone pojmova.',
              'Погоди коначно решење из четири колоне појмова.',
            ),
            rounds: _buildGameRounds('asocijacije'),
            timersByGame: stats.timers,
          ),
        ),
        const SizedBox(height: 10),
        ModeCard(
          badge: const ModeBadgeIcon(kind: ModeKind.myNumber),
          title: t('Moj Broj', 'Мој Број'),
          subtitle: t(
            'Koristi brojeve i operacije da dođeš do cilja',
            'Користи бројеве и операције да дођеш до циља',
          ),
          accent: const Color(0xFF4FC3F7),
          cta: '',
          onTap: () => _openModePreview(
            modeKey: 'my_number',
            onlineModeKey: 'moj_broj',
            source: 'home_card',
            modeTitle: t('Moj Broj', 'Мој Број'),
            modeDescription: t(
              'Unesi broj koji dobijaš zadatim brojevima.',
              'Унеси број који добијаш задатим бројевима.',
            ),
            rounds: _buildGameRounds('moj_broj'),
            timersByGame: stats.timers,
          ),
        ),
        const SizedBox(height: 10),
        ModeCard(
          badge: const ModeBadgeIcon(kind: ModeKind.tangram),
          title: t('Tangram+', 'Танграм+'),
          subtitle: t(
            'Složi oblike i testiraj svoju logiku',
            'Сложи облике и тестирај своју логику',
          ),
          accent: const Color(0xFFEF5350),
          cta: '',
          onTap: () => _openModePreview(
            modeKey: 'tangram',
            onlineModeKey: 'tangram',
            source: 'home_card',
            modeTitle: t('Tangram+', 'Танграм+'),
            modeDescription: t(
              'Probna Tangram runda sa merenjem vremena.',
              'Пробна Танграм рунда са мерењем времена.',
            ),
            rounds: _buildGameRounds('tangram'),
            timersByGame: stats.timers,
          ),
        ),
        const SizedBox(height: 16),
        DailyChallengeCard(
          useCyrillic: widget.useCyrillic,
          completedTasks: stats.playerStats.dailyCompletedTasks,
          totalTasks: PlayerStats.dailyTaskGoal,
          onTap: () =>
              _openDailyChallengePicker(stats.timers, source: 'daily_card'),
        ),
        if (hasStatsError) ...[
          const SizedBox(height: 12),
          NoticeCard(
            text: t(
              'Neki podaci nisu učitani. Prikazujemo podrazumevane vrednosti.',
              'Неки подаци нису учитани. Приказујемо подразумеване вредности.',
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPresenceCard({
    required PresenceStats? presence,
    required bool isLoading,
    required bool hasError,
  }) {
    final stats = presence ?? const PresenceStats.empty();
    final showPlaceholder = isLoading && presence == null && !hasError;
    final statusText = hasError
        ? t('Stanje trenutno nije dostupno.', 'Стање тренутно није доступно.')
        : isLoading
        ? t('Osvežava se...', 'Освежава се...')
        : t('Aktivni u poslednjem minutu', 'Активни у последњем минуту');

    String countText(int value) {
      if (hasError) return '-';
      if (showPlaceholder) return '...';
      return value.toString();
    }

    final kvizWaiting = stats.waitingForMode('kviz');
    final kvizPlusWaiting = stats.waitingForMode('kviz_plus');
    final canJoinQueue = !hasError && !showPlaceholder;
    final VoidCallback? waitingTotalTap;
    if (canJoinQueue && kvizWaiting > 0 && kvizPlusWaiting == 0) {
      waitingTotalTap = () => _openDuelQueueFromPresence(
        modeKey: 'kviz',
        modeTitle: t('Kviz Duel', 'Квиз Дуел'),
      );
    } else if (canJoinQueue && kvizPlusWaiting > 0 && kvizWaiting == 0) {
      waitingTotalTap = () => _openDuelQueueFromPresence(
        modeKey: 'kviz_plus',
        modeTitle: t('Kviz+ Duel', 'Квиз+ Дуел'),
      );
    } else {
      waitingTotalTap = null;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: context.actionBlue.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.groups_2_rounded,
                  color: context.actionBlue,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t('Igrači trenutno online', 'Играчи тренутно онлајн'),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: context.strongText,
                      ),
                    ),
                    Text(
                      statusText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: hasError
                            ? context.errorColor
                            : context.mutedText,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: t('Osveži', 'Освежи'),
                onPressed: () => _refreshPresence(force: true),
                icon: Icon(Icons.refresh_rounded, color: context.mutedText),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              const spacing = 8.0;
              final metricWidth = (constraints.maxWidth - spacing) / 2;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  _presenceMetric(
                    width: metricWidth,
                    icon: Icons.people_alt_rounded,
                    value: countText(stats.onlineCount),
                    label: t('online', 'онлајн'),
                    color: context.successColor,
                  ),
                  _presenceMetric(
                    width: metricWidth,
                    icon: Icons.hourglass_bottom_rounded,
                    value: countText(stats.waitingTotal),
                    label: t('čeka duel', 'чека дуел'),
                    color: context.scoreColor,
                    onTap: waitingTotalTap,
                  ),
                  _presenceMetric(
                    width: metricWidth,
                    icon: Icons.quiz_rounded,
                    value: countText(kvizWaiting),
                    label: t('Kviz', 'Квиз'),
                    color: const Color(0xFF7E57C2),
                    onTap: canJoinQueue && kvizWaiting > 0
                        ? () => _openDuelQueueFromPresence(
                            modeKey: 'kviz',
                            modeTitle: t('Kviz Duel', 'Квиз Дуел'),
                          )
                        : null,
                  ),
                  _presenceMetric(
                    width: metricWidth,
                    icon: Icons.extension_rounded,
                    value: countText(kvizPlusWaiting),
                    label: t('Kviz+', 'Квиз+'),
                    color: const Color(0xFFEF5350),
                    onTap: canJoinQueue && kvizPlusWaiting > 0
                        ? () => _openDuelQueueFromPresence(
                            modeKey: 'kviz_plus',
                            modeTitle: t('Kviz+ Duel', 'Квиз+ Дуел'),
                          )
                        : null,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _presenceMetric({
    required double width,
    required IconData icon,
    required String value,
    required String label,
    required Color color,
    VoidCallback? onTap,
  }) {
    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: context.strongText,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: context.mutedText,
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 4),
            Icon(Icons.login_rounded, size: 16, color: color),
          ],
        ],
      ),
    );

    return SizedBox(
      width: width,
      child: onTap == null
          ? content
          : Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: onTap,
                child: content,
              ),
            ),
    );
  }

  Widget _buildLeaderboardTab() {
    final future = _leaderboardFuture ??= _loadLeaderboard();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _leaderboardModeToggle(
              mode: 'solo',
              icon: Icons.person_rounded,
              label: t('Solo', 'Соло'),
            ),
            _leaderboardModeToggle(
              mode: 'solo_duel',
              icon: Icons.groups_rounded,
              label: t('Duel', 'Дуел'),
            ),
            _leaderboardModeToggle(
              mode: 'kviz',
              icon: Icons.groups_rounded,
              label: t('Kviz', 'Квиз'),
            ),
            _leaderboardModeToggle(
              mode: 'kviz_plus',
              icon: Icons.extension_rounded,
              label: t('Kviz+', 'Квиз+'),
            ),
            FutureBuilder<KvizAdQuotaSnapshot>(
              future: _adQuotaFuture,
              builder: (context, snapshot) {
                final hasPremier = snapshot.data?.hasPremier ?? false;
                if (!hasPremier) {
                  return const SizedBox.shrink();
                }

                return _leaderboardModeToggle(
                  mode: premierModeKey,
                  icon: Icons.workspace_premium_rounded,
                  label: t('Premier', 'Премијер'),
                );
              },
            ),
            _leaderboardModeToggle(
              mode: 'pitanja',
              icon: Icons.menu_book_rounded,
              label: t('Pitanja', 'Питања'),
            ),
            _leaderboardModeToggle(
              mode: 'asocijacije',
              icon: Icons.link_rounded,
              label: t('Asocijacije', 'Асоцијације'),
            ),
            _leaderboardModeToggle(
              mode: 'moj_broj',
              icon: Icons.pin_rounded,
              label: t('Moj Broj', 'Мој Број'),
            ),
            _leaderboardModeToggle(
              mode: 'tangram',
              icon: Icons.extension_rounded,
              label: t('Tangram', 'Танграм'),
            ),
            TogglePill(
              selected: _leaderboardPeriod == 'weekly',
              icon: Icons.calendar_view_week_rounded,
              label: t('Nedelja', 'Недеља'),
              onTap: () {
                KvizAnalytics.uiAction(
                  screen: 'leaderboard',
                  area: 'filter',
                  target: _leaderboardPeriod == 'weekly'
                      ? 'period_all_time'
                      : 'period_weekly',
                  parameters: <String, Object?>{'mode': _leaderboardMode},
                );
                setState(() {
                  _leaderboardPeriod = _leaderboardPeriod == 'weekly'
                      ? 'all_time'
                      : 'weekly';
                  _leaderboardFuture = _loadLeaderboard();
                });
                KvizAnalytics.leaderboardPeriodFilter(
                  period: _leaderboardPeriod,
                );
              },
            ),
            TogglePill(
              selected: _leaderboardPeriod == 'daily',
              icon: Icons.today_rounded,
              label: t('Danas', 'Данас'),
              onTap: () {
                KvizAnalytics.uiAction(
                  screen: 'leaderboard',
                  area: 'filter',
                  target: _leaderboardPeriod == 'daily'
                      ? 'period_all_time'
                      : 'period_daily',
                  parameters: <String, Object?>{'mode': _leaderboardMode},
                );
                setState(() {
                  _leaderboardPeriod = _leaderboardPeriod == 'daily'
                      ? 'all_time'
                      : 'daily';
                  _leaderboardFuture = _loadLeaderboard();
                });
                KvizAnalytics.leaderboardPeriodFilter(
                  period: _leaderboardPeriod,
                );
              },
            ),
            TogglePill(
              selected: _leaderboardPeriod == 'season',
              icon: Icons.workspace_premium_rounded,
              label: t('Sezona', 'Сезона'),
              onTap: () {
                KvizAnalytics.uiAction(
                  screen: 'leaderboard',
                  area: 'filter',
                  target: _leaderboardPeriod == 'season'
                      ? 'period_all_time'
                      : 'period_season',
                  parameters: <String, Object?>{'mode': _leaderboardMode},
                );
                setState(() {
                  _leaderboardPeriod = _leaderboardPeriod == 'season'
                      ? 'all_time'
                      : 'season';
                  _seasonFuture ??= _loadCurrentSeason();
                  _leaderboardFuture = _loadLeaderboard();
                });
                KvizAnalytics.leaderboardPeriodFilter(
                  period: _leaderboardPeriod,
                );
              },
            ),
            if (_leaderboardMode != premierModeKey)
              TogglePill(
                selected: _leaderboardExcludePremier,
                icon: Icons.workspace_premium_rounded,
                label: t('Bez Premier', 'Без Премијер'),
                onTap: () {
                  final nextValue = !_leaderboardExcludePremier;
                  KvizAnalytics.uiAction(
                    screen: 'leaderboard',
                    area: 'filter',
                    target: nextValue
                        ? 'exclude_premier_on'
                        : 'exclude_premier_off',
                    parameters: <String, Object?>{
                      'mode': _leaderboardMode,
                      'period': _leaderboardPeriod,
                    },
                  );
                  setState(() {
                    _leaderboardExcludePremier = nextValue;
                    _leaderboardFuture = _loadLeaderboard();
                  });
                },
              ),
          ],
        ),
        const SizedBox(height: 10),
        _buildSeasonBanner(compact: true),
        const SizedBox(height: 10),
        if (PlayGamesService.hasGoogleLeaderboardForMode(_leaderboardMode)) ...[
          OutlinedButton.icon(
            onPressed: _openGooglePlayLeaderboard,
            icon: const Icon(Icons.sports_esports_rounded),
            label: Text(t('Google Play rang lista', 'Google Play ранг листа')),
          ),
          const SizedBox(height: 14),
        ],
        FutureBuilder<Map<String, dynamic>>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const DarkProgressCard();
            }

            if (snapshot.hasError) {
              return NoticeCard(
                text: t(
                  'Server trenutno ne vraća rang listu.',
                  'Сервер тренутно не враћа ранг листу.',
                ),
              );
            }

            final entries = (snapshot.data?['entries'] as List? ?? const [])
                .whereType<Map>()
                .map(
                  (entry) => entry.map(
                    (key, dynamic value) => MapEntry(key.toString(), value),
                  ),
                )
                .toList(growable: false);

            if (entries.isEmpty) {
              return NoticeCard(
                text: t(
                  'Rang lista je trenutno prazna za izabrani mod.',
                  'Ранг листа је тренутно празна за изабрани мод.',
                ),
              );
            }

            return Column(
              children: [
                ...entries.map((entry) => LeaderboardEntryTile(entry: entry)),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _refreshLeaderboard,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(t('Osveži', 'Освежи')),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _leaderboardModeToggle({
    required String mode,
    required IconData icon,
    required String label,
  }) {
    return TogglePill(
      selected: _leaderboardMode == mode,
      icon: icon,
      label: label,
      onTap: () {
        KvizAnalytics.uiAction(
          screen: 'leaderboard',
          area: 'filter',
          target: 'mode_$mode',
          parameters: <String, Object?>{
            'mode': mode,
            'period': _leaderboardPeriod,
          },
        );
        setState(() {
          _leaderboardMode = mode;
          if (mode == premierModeKey) {
            _leaderboardExcludePremier = false;
          }
          _leaderboardFuture = _loadLeaderboard();
        });
        KvizAnalytics.leaderboardModeFilter(mode: mode);
      },
    );
  }

  Widget _buildSeasonBanner({bool compact = false}) {
    final future = _seasonFuture ??= _loadCurrentSeason();

    return FutureBuilder<Map<String, dynamic>>(
      future: future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final season = _mapFrom(snapshot.data?['season']);
        if (season == null) {
          return const SizedBox.shrink();
        }

        final label = season['label']?.toString().trim();
        final secondsLeft = _asInt(season['seconds_left']);
        final daysLeft = secondsLeft <= 0 ? 0 : (secondsLeft / 86400).ceil();
        final text = compact
            ? t(
                'Sezona ${label ?? ''}: još $daysLeft dana.',
                'Сезона ${label ?? ''}: још $daysLeft дана.',
              )
            : t(
                'Sezonski rang: ${label ?? ''}. Preostalo $daysLeft dana.',
                'Сезонски ранг: ${label ?? ''}. Преостало $daysLeft дана.',
              );

        return NoticeCard(text: text);
      },
    );
  }

  Widget _buildProfileTab(
    LandingStats stats,
    bool isLoading,
    bool hasStatsError,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HeroCard(
          isLoading: isLoading || hasStatsError,
          stats: stats,
          useCyrillic: widget.useCyrillic,
          signedInUserLabel: widget.signedInUserLabel,
          avatarUrl: widget.authSession.user.avatarUrl,
        ),
        const SizedBox(height: 14),
        ProfileInfoCard(
          useCyrillic: widget.useCyrillic,
          authSession: widget.authSession,
          onAchievementsTap: () => _openAchievementsPage(stats),
        ),
        const SizedBox(height: 14),
        _buildSeasonBanner(),
        const SizedBox(height: 14),
        StatsGrid(stats: stats, useCyrillic: widget.useCyrillic),
      ],
    );
  }

  Widget _buildSettingsTab(bool effectiveLargeText) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsHeaderCard(useCyrillic: widget.useCyrillic),
        const SizedBox(height: 14),
        FutureBuilder<KvizAdQuotaSnapshot>(
          future: _adQuotaFuture,
          builder: (context, snapshot) {
            return RewardedGameSettingsCard(
              useCyrillic: widget.useCyrillic,
              quota: snapshot.data,
              isLoading: snapshot.connectionState != ConnectionState.done,
              hasError: snapshot.hasError,
              inProgress: _rewardAdInProgress,
              message: _rewardMessage,
              onWatchAd: _watchRewardedAdForBonusGame,
            );
          },
        ),
        const SizedBox(height: 14),
        IapSubscriptionSettingsCard(
          useCyrillic: widget.useCyrillic,
          onLoadSubscriptions: _loadSubscriptionStatus,
          onVerifyPurchase: _verifySubscriptionPurchase,
          onSubscriptionChanged: _refreshAdQuota,
        ),
        const SizedBox(height: 14),
        SettingsRow(
          useCyrillic: widget.useCyrillic,
          themeMode: widget.themeMode,
          scriptMode: widget.scriptMode,
          textSizeMode: _textSizeMode,
          largeText: effectiveLargeText,
          onThemeModeChanged: widget.onThemeModeChanged,
          onScriptModeChanged: widget.onScriptModeChanged,
          onTextSizeModeChanged: _setTextSizeMode,
        ),
        const SizedBox(height: 14),
        SettingsInfoCard(
          useCyrillic: widget.useCyrillic,
          deviceId: widget.deviceId,
          appVersion: widget.apiConfig.appVersion,
        ),
        const SizedBox(height: 14),
        SettingsAccountPanel(
          useCyrillic: widget.useCyrillic,
          onLogoutTap: widget.onLogoutTap,
        ),
      ],
    );
  }
}
