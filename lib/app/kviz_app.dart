import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/local/app_repositories.dart';
import '../data/remote/achievement_sync_service.dart';
import '../data/remote/api_client.dart';
import '../data/remote/api_config.dart';
import '../data/remote/api_exception.dart';
import '../data/remote/analytics_service.dart';
import '../data/remote/auth_manager.dart';
import '../data/remote/auth_models.dart';
import '../data/remote/auth_refresh_coordinator.dart';
import '../data/remote/auth_session_store.dart';
import '../data/remote/integrity_flow_service.dart';
import '../data/remote/laravel_api_service.dart';
import '../data/remote/play_games_service.dart';
import '../data/remote/play_integrity_service.dart';
import '../data/remote/push_notification_service.dart';
import '../presentation/app_theme.dart';
import '../presentation/google_sign_in_button.dart';
import '../presentation/kviz_theme.dart';
import '../presentation/landing_page.dart';
import '../presentation/online_session_page.dart';
import '../shared/online_round_parser.dart';
import '../shared/utils.dart';
import '../shared/widgets/toggle_pill.dart';

const _settingsThemeModeKey = 'kviz.settings.theme_mode';
const _settingsCyrillicKey = 'kviz.settings.use_cyrillic';
const _settingsScriptModeKey = 'kviz.settings.script_mode';
const _scriptModeSystem = 'system';
const _scriptModeLatin = 'latin';
const _scriptModeCyrillic = 'cyrillic';

String? _achievementUserKeyForSession(AuthSession session) {
  final user = session.user;
  final googleSub = user.googleSub?.trim();
  if (googleSub != null && googleSub.isNotEmpty) {
    return 'google:$googleSub';
  }

  final id = user.id;
  if (id != null) {
    return 'user:$id';
  }

  final email = user.email?.trim();
  if (email != null && email.isNotEmpty) {
    return 'email:$email';
  }

  return null;
}

class KvizApp extends StatefulWidget {
  const KvizApp({
    super.key,
    required this.repositories,
    required this.firebaseReadyFuture,
  });

  final AppRepositories repositories;
  final Future<bool> firebaseReadyFuture;

  @override
  State<KvizApp> createState() => _KvizAppState();
}

class _KvizAppState extends State<KvizApp> {
  ThemeMode _themeMode = ThemeMode.system;
  String _scriptMode = _scriptModeSystem;
  bool _useCyrillic = _systemPrefersCyrillic();
  late final ApiConfig _apiConfig;
  late final AuthManager _authManager;
  late final AuthRefreshCoordinator _authRefreshCoordinator;
  late final AuthSessionStore _sessionStore;
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final PushNotificationService _pushNotifications = PushNotificationService();
  AuthSession? _authSession;
  String _deviceId = '';
  bool _restoringAuth = true;
  bool _authInProgress = false;
  bool _firebaseReady = false;
  String? _authError;
  StreamSubscription<AuthSession>? _webAuthSubscription;

  String t(String latin, String cyr) => tr(_useCyrillic, latin, cyr);

  static bool _systemPrefersCyrillic() {
    final dispatcher = WidgetsBinding.instance.platformDispatcher;
    final locales = dispatcher.locales.isEmpty
        ? <Locale>[dispatcher.locale]
        : dispatcher.locales;

    for (final locale in locales) {
      final script = locale.scriptCode?.toLowerCase();
      if (script == 'cyrl') return true;
      if (script == 'latn') return false;

      final language = locale.languageCode.toLowerCase();
      if (<String>{'bg', 'mk', 'ru', 'sr', 'uk'}.contains(language)) {
        return true;
      }
    }

    return false;
  }

  static bool _resolveCyrillicForMode(String mode) {
    if (mode == _scriptModeCyrillic) {
      return true;
    }
    if (mode == _scriptModeLatin) {
      return false;
    }

    return _systemPrefersCyrillic();
  }

  @override
  void initState() {
    super.initState();
    _apiConfig = ApiConfig.fromEnvironment();
    _applyAnalyticsContext();
    _sessionStore = AuthSessionStore();
    _authManager = AuthManager(config: _apiConfig, sessionStore: _sessionStore);
    _authRefreshCoordinator = AuthRefreshCoordinator(
      config: _apiConfig,
      sessionStore: _sessionStore,
    );
    unawaited(_observeFirebaseReady());
    _setupWebAuthListener();
    _restoreUserSettings();
    _restoreAuthSession();
  }

  @override
  void dispose() {
    _webAuthSubscription?.cancel();
    super.dispose();
  }

  void _setupWebAuthListener() {
    if (!_authManager.usesWebGoogleButton) {
      return;
    }

    _webAuthSubscription = _authManager.webAuthSessions.listen(
      _completeGoogleSignIn,
      onError: (Object error) {
        if (!mounted) {
          return;
        }
        setState(() {
          _authInProgress = false;
          _authError = _mapAuthError(error);
        });
      },
    );
  }

  Future<void> _restoreAuthSession() async {
    setState(() {
      _restoringAuth = true;
      _authError = null;
    });

    try {
      final results = await Future.wait([
        _authManager.restoreSession(),
        _sessionStore.readOrCreateDeviceId(),
      ]);
      if (!mounted) return;
      setState(() {
        _authSession = results[0] as AuthSession?;
        _deviceId = results[1] as String;
      });
      _applyAnalyticsContext();
      _afterAuthSessionReady(_authSession);
      if (_authSession == null) {
        unawaited(_authManager.startWebOneTap());
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _authError = _mapAuthError(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _restoringAuth = false;
        });
      }
    }
  }

  Future<void> _restoreUserSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    final savedTheme = prefs.getString(_settingsThemeModeKey);
    final savedScript = prefs.getString(_settingsScriptModeKey);
    final legacyCyrillic = prefs.getBool(_settingsCyrillicKey);
    setState(() {
      _themeMode = switch (savedTheme) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
      if (savedScript == _scriptModeLatin ||
          savedScript == _scriptModeCyrillic) {
        _scriptMode = savedScript!;
      } else if (legacyCyrillic != null) {
        _scriptMode = legacyCyrillic ? _scriptModeCyrillic : _scriptModeLatin;
      } else {
        _scriptMode = _scriptModeSystem;
      }
      _useCyrillic = _resolveCyrillicForMode(_scriptMode);
    });
    _applyAnalyticsContext();
  }

  Future<void> _observeFirebaseReady() async {
    try {
      final ready = await widget.firebaseReadyFuture;
      if (!mounted) {
        return;
      }

      setState(() {
        _firebaseReady = ready;
      });
      _applyAnalyticsContext();

      final session = _authSession;
      if (ready && session != null) {
        unawaited(_registerPushForSession(session));
      }
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _firebaseReady = false;
      });
    }
  }

  Future<void> _completeGoogleSignIn(AuthSession session) async {
    if (!mounted) {
      return;
    }

    setState(() {
      _authInProgress = true;
      _authError = null;
    });

    final devId = await _sessionStore.readOrCreateDeviceId();
    if (!mounted) {
      return;
    }

    setState(() {
      _authSession = session;
      _deviceId = devId;
      _authInProgress = false;
    });
    KvizAnalytics.loginSuccess(method: 'google');
    _applyAnalyticsContext();
    _afterAuthSessionReady(session);
  }

  Future<void> _signInWithGoogle() async {
    if (_authInProgress) {
      return;
    }

    KvizAnalytics.loginStart(method: 'google');
    setState(() {
      _authInProgress = true;
      _authError = null;
    });

    try {
      final session = await _authManager.signInWithGoogle();
      if (!mounted) return;
      final devId = await _sessionStore.readOrCreateDeviceId();
      if (!mounted) return;
      setState(() {
        _authSession = session;
        _deviceId = devId;
      });
      KvizAnalytics.loginSuccess(method: 'google');
      _applyAnalyticsContext();
      _afterAuthSessionReady(session);
    } catch (error) {
      if (!mounted) {
        return;
      }
      KvizAnalytics.loginFailure(
        method: 'google',
        reason: _mapAuthError(error),
      );
      setState(() {
        _authError = _mapAuthError(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _authInProgress = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    if (_authInProgress) {
      return;
    }

    setState(() {
      _authInProgress = true;
      _authError = null;
    });

    try {
      final currentSession = _authSession;
      await _pushNotifications.unregister(
        api: _newLaravelApi(),
        session: currentSession,
      );
      await _authManager.logout(currentSession);
    } finally {
      if (mounted) {
        setState(() {
          _authSession = null;
          _authInProgress = false;
        });
        KvizAnalytics.logout();
        _applyAnalyticsContext();
      }
    }
  }

  LaravelApiService _newLaravelApi() {
    return LaravelApiService(
      apiClient: ApiClient(
        baseUrl: _apiConfig.baseUrl,
        accessTokenRefresher: _refreshAccessTokenForApi,
      ),
    );
  }

  Future<String?> _refreshAccessTokenForApi(String rejectedAccessToken) async {
    final nextToken = await _authRefreshCoordinator.refreshAccessToken(
      rejectedAccessToken,
    );
    final stored = await _sessionStore.readSession();
    if (!mounted) {
      return nextToken;
    }

    if (stored == null) {
      setState(() {
        _authSession = null;
        _authError = t(
          'Sesija je istekla. Prijavi se ponovo.',
          'Сесија је истекла. Пријави се поново.',
        );
      });
      _applyAnalyticsContext();
      return nextToken;
    }

    if (_authSession?.accessToken != stored.accessToken ||
        _authSession?.refreshToken != stored.refreshToken) {
      setState(() {
        _authSession = stored;
      });
      _applyAnalyticsContext();
    }

    return nextToken;
  }

  void _afterAuthSessionReady(AuthSession? session) {
    if (session == null) {
      return;
    }

    unawaited(_registerPushForSession(session));
    unawaited(_syncAchievementsForSession(session));
  }

  Future<void> _registerPushForSession(AuthSession session) async {
    if (!_firebaseReady) {
      return;
    }

    try {
      await _pushNotifications.initialize(
        api: _newLaravelApi(),
        session: session,
        deviceId: _deviceId,
        appVersion: _apiConfig.appVersion,
        messengerKey: _scaffoldMessengerKey,
        useCyrillic: _useCyrillic,
        onOpened: _handlePushOpened,
      );
    } catch (_) {
      // Push is a convenience layer; gameplay must not depend on FCM.
    }
  }

  Future<void> _syncAchievementsForSession(AuthSession session) async {
    try {
      await AchievementSyncService(
        api: _newLaravelApi(),
        accessToken: session.accessToken,
        userKey: _achievementUserKeyForSession(session),
      ).sync();
    } catch (_) {
      // Achievement sync is retried from the profile and end-of-game flows.
    }
  }

  Future<void> _handlePushOpened(Map<String, dynamic> data) async {
    if (data['type'] != 'queue_matched') {
      return;
    }

    final session = _authSession;
    final matchId = data['match_id']?.trim();
    if (session == null || matchId == null || matchId.isEmpty) {
      return;
    }

    try {
      final api = _newLaravelApi();
      final mobileSessionToken =
          await IntegrityFlowService(
            api: api,
            playIntegrity: const PlayIntegrityService(),
          ).acquireMobileSessionToken(
            accessToken: session.accessToken,
            deviceId: _deviceId,
            appVersion: _apiConfig.appVersion,
          );
      final payload = await api.getQuizMatch(
        accessToken: session.accessToken,
        mobileSessionToken: mobileSessionToken,
        matchId: matchId,
      );
      final matchSession = _mapFrom(payload['session']);
      final sessionId = matchSession?['session_id']?.toString().trim();
      if (sessionId == null || sessionId.isEmpty) {
        return;
      }

      final mode = matchSession?['mode']?.toString().trim();
      final rounds = parseOnlineRoundsFromPayload(matchSession?['rounds']);
      final navigator = _navigatorKey.currentState;
      if (navigator == null || rounds.isEmpty) {
        return;
      }

      await navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => OnlineSessionPage(
            modeKey: mode == null || mode.isEmpty ? 'solo_duel' : mode,
            sessionId: sessionId,
            mobileSessionToken: mobileSessionToken,
            accessToken: session.accessToken,
            deviceId: _deviceId,
            appVersion: _apiConfig.appVersion,
            rounds: rounds,
            modeTitle: t('Duel', 'Дуел'),
            useCyrillic: _useCyrillic,
            api: api,
            isDuel: true,
            onSessionCompleted: (completion) async {
              await const PlayGamesService().syncSessionResult(
                mode: PlayGamesService.normalizeGoogleLeaderboardMode(
                  completion.googleLeaderboardMode,
                ),
                finalScore: completion.finalScore,
                bestStreak: completion.bestStreak,
                myNumberPerfect: completion.myNumberPerfect,
                perfectKviz: completion.perfectKviz,
                associationsMaster: completion.associationsMaster,
                speedDemonCount: completion.speedDemonCount,
                userKey: _achievementUserKeyForSession(session),
                serverConfirmedAchievements: completion.serverAchievements,
              );
            },
          ),
        ),
      );
    } catch (_) {
      // Tapping a push should never break normal app startup.
    }
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

  void _setThemeMode(ThemeMode mode) {
    KvizAnalytics.uiAction(
      screen: 'settings',
      area: 'display',
      target: 'theme_${mode.name}',
    );
    setState(() {
      _themeMode = mode;
    });
    _applyAnalyticsContext();
    unawaited(_saveThemeMode(mode));
  }

  void _setScriptMode(String mode) {
    KvizAnalytics.uiAction(
      screen: 'settings',
      area: 'display',
      target: 'script_$mode',
    );
    setState(() {
      _scriptMode = mode;
      _useCyrillic = _resolveCyrillicForMode(mode);
    });
    _applyAnalyticsContext();
    unawaited(_saveScriptMode(mode));
  }

  void _applyAnalyticsContext() {
    KvizAnalytics.setAppContext(
      appVersion: _apiConfig.appVersion,
      theme: _themeMode.name,
      useCyrillic: _useCyrillic,
      largeText: false,
      signedIn: _authSession != null,
    );
  }

  Future<void> _saveThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_settingsThemeModeKey, mode.name);
  }

  Future<void> _saveScriptMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_settingsScriptModeKey, mode);
  }

  String _mapAuthError(Object error) {
    if (error is AuthFlowException) {
      return error.message;
    }

    if (error is ApiException) {
      final status = error.statusCode;
      if (status == 401 || status == 403) {
        return t(
          'Prijava nije odobrena. Proveri Google podešavanja prijave.',
          'Пријава није одобрена. Провери Google подешавања пријаве.',
        );
      }

      if (status == 422) {
        return t(
          'Google token nije validan za backend. Proveri server client ID.',
          'Google token није валидан за backend. Провери server client ID.',
        );
      }

      return 'Server ${error.statusCode}: ${error.message}';
    }

    return error.toString();
  }

  Widget _buildAuthLoadingView() {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 14),
              Text(
                t('Provera prijave u toku...', 'Провера пријаве у току...'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSignInView() {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: context.pageBg,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const Spacer(flex: 2),
                  // Logo area
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(26),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF0E4C86), Color(0xFF1565C0)],
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x664FC3F7),
                          blurRadius: 24,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.quiz_rounded,
                        color: Colors.white,
                        size: 46,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Kviz DBase',
                    style: TextStyle(
                      color: context.accentText,
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    t(
                      'Prijavite se Google nalogom da biste pristupili igri.',
                      'Пријавите се Google налогом да бисте приступили игри.',
                    ),
                    style: TextStyle(
                      color: context.mutedText,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const Spacer(flex: 2),
                  // Error banner
                  if (_authError != null) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: scheme.errorContainer,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: scheme.error),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline_rounded,
                            color: scheme.error,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _authError!,
                              style: TextStyle(
                                color: scheme.onErrorContainer,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  KvizGoogleSignInButton(
                    inProgress: _authInProgress,
                    onPressed: _authInProgress ? null : _signInWithGoogle,
                    label: t(
                      'Prijavi se Google nalogom',
                      'Пријави се Google налогом',
                    ),
                    progressLabel: t('Prijava u toku...', 'Пријава у току...'),
                  ),
                  const SizedBox(height: 28),
                  // Language + theme toggles
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      TogglePill(
                        selected: _themeMode == ThemeMode.system,
                        icon: Icons.brightness_auto_rounded,
                        label: t('Auto', 'Ауто'),
                        onTap: () => _setThemeMode(ThemeMode.system),
                      ),
                      TogglePill(
                        selected: _themeMode == ThemeMode.light,
                        icon: Icons.light_mode_rounded,
                        label: t('Svetla', 'Светла'),
                        onTap: () => _setThemeMode(ThemeMode.light),
                      ),
                      TogglePill(
                        selected: _themeMode == ThemeMode.dark,
                        icon: Icons.dark_mode_rounded,
                        label: t('Tamna', 'Тамна'),
                        onTap: () => _setThemeMode(ThemeMode.dark),
                      ),
                      TogglePill(
                        selected: _scriptMode == _scriptModeSystem,
                        icon: Icons.language_rounded,
                        label: t('Pismo auto', 'Писмо ауто'),
                        onTap: () => _setScriptMode(_scriptModeSystem),
                      ),
                      TogglePill(
                        selected: _scriptMode == _scriptModeLatin,
                        icon: Icons.language_rounded,
                        label: 'Latinica',
                        onTap: () => _setScriptMode(_scriptModeLatin),
                      ),
                      TogglePill(
                        selected: _scriptMode == _scriptModeCyrillic,
                        icon: Icons.translate_rounded,
                        label: 'Ћирилица',
                        onTap: () => _setScriptMode(_scriptModeCyrillic),
                      ),
                    ],
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Widget home;
    if (_restoringAuth) {
      home = _buildAuthLoadingView();
    } else if (_authSession == null) {
      home = _buildSignInView();
    } else {
      home = LandingPage(
        repositories: widget.repositories,
        useCyrillic: _useCyrillic,
        themeMode: _themeMode,
        scriptMode: _scriptMode,
        onThemeModeChanged: _setThemeMode,
        onScriptModeChanged: _setScriptMode,
        onLogoutTap: _logout,
        signedInUserLabel: _authSession!.user.displayName,
        authSession: _authSession!,
        deviceId: _deviceId,
        apiConfig: _apiConfig,
        accessTokenRefresher: _refreshAccessTokenForApi,
      );
    }

    return MaterialApp(
      navigatorKey: _navigatorKey,
      scaffoldMessengerKey: _scaffoldMessengerKey,
      debugShowCheckedModeBanner: false,
      title: 'Kviz DBase',
      themeMode: _themeMode,
      theme: buildKvizLightTheme(),
      darkTheme: buildKvizDarkTheme(),
      navigatorObservers: _firebaseReady
          ? KvizAnalytics.navigatorObservers
          : const <NavigatorObserver>[],
      home: home,
    );
  }
}
