import 'dart:async';
import '../../shared/online_round_parser.dart';

import 'package:flutter/material.dart';

import '../../data/remote/analytics_service.dart';
import '../../data/remote/api_client.dart';
import '../../data/remote/api_config.dart';
import '../../data/remote/api_exception.dart';
import '../../data/remote/auth_models.dart';
import '../../data/remote/integrity_flow_service.dart';
import '../../data/remote/laravel_api_service.dart';
import '../../data/remote/play_games_service.dart';
import '../../data/remote/session_launcher.dart';
import '../../presentation/kviz_theme.dart';
import '../../presentation/online_session_page.dart';
import '../../shared/quiz_modes.dart';
import '../../shared/utils.dart';

class SoloQueuePage extends StatefulWidget {
  const SoloQueuePage({
    super.key,
    required this.modeKey,
    required this.modeTitle,
    required this.useCyrillic,
    required this.authSession,
    required this.deviceId,
    required this.apiConfig,
    required this.accessTokenRefresher,
    required this.onAdQuotaChanged,
    this.onLeaderboardUpdated,
    this.onSessionCompleted,
    this.api,
    this.mobileSessionTokenProvider,
  });
  final String modeKey;
  final String modeTitle;
  final bool useCyrillic;
  final AuthSession authSession;
  final String deviceId;
  final ApiConfig apiConfig;
  final AccessTokenRefresher accessTokenRefresher;
  final VoidCallback onAdQuotaChanged;
  final ValueChanged<String>? onLeaderboardUpdated;
  final VoidCallback? onSessionCompleted;
  final LaravelApiService? api;
  final Future<String> Function(LaravelApiService api)?
  mobileSessionTokenProvider;
  @override
  State<SoloQueuePage> createState() => _SoloQueuePageState();
}

class _SoloQueuePageState extends State<SoloQueuePage>
    with WidgetsBindingObserver {
  late final LaravelApiService _api;
  Timer? _elapsedTimer;
  Timer? _pollTimer;
  String _status = 'joining';
  String? _ticketId;
  String? _mobileSessionToken;
  String? _error;
  String? _opponentName;
  DateTime? _searchStartedAt;
  DateTime? _searchDeadlineAt;
  int _elapsedSeconds = 0;
  bool _joining = true;
  bool _cancelling = false;
  bool _completed = false;
  String t(String latin, String cyr) => tr(widget.useCyrillic, latin, cyr);
  bool get _isWaiting => _status == 'joining' || _status == 'waiting';
  int? get _remainingSeconds {
    final deadline = _searchDeadlineAt;
    if (deadline == null) {
      return null;
    }
    final seconds = deadline.difference(DateTime.now()).inSeconds;
    return seconds < 0 ? 0 : seconds;
  }

  bool get _isExpandedSearch {
    final remaining = _remainingSeconds;
    return _elapsedSeconds >= 10 || (remaining != null && remaining <= 10);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _api =
        widget.api ??
        LaravelApiService(
          apiClient: ApiClient(
            baseUrl: widget.apiConfig.baseUrl,
            accessTokenRefresher: widget.accessTokenRefresher,
          ),
        );
    KvizAnalytics.screenView(
      'solo_queue',
      parameters: <String, Object?>{'mode': widget.modeKey},
    );
    _joinQueue();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _elapsedTimer?.cancel();
    _pollTimer?.cancel();
    final ticketId = _ticketId;
    final mobileSessionToken = _mobileSessionToken;
    if (!_completed &&
        _status == 'waiting' &&
        ticketId != null &&
        mobileSessionToken != null) {
      unawaited(
        _api
            .cancelSoloQueue(
              accessToken: widget.authSession.accessToken,
              mobileSessionToken: mobileSessionToken,
              ticketId: ticketId,
            )
            .then<void>((_) {})
            .catchError((Object _) {}),
      );
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      KvizAnalytics.appBackgrounded();
    }
    if (state == AppLifecycleState.resumed) {
      KvizAnalytics.appForegrounded();
    }
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_cancelQueueForLifecycle());
    }
  }

  Future<String> _acquireMobileSessionToken() {
    final provider = widget.mobileSessionTokenProvider;
    if (provider != null) {
      return provider(_api);
    }
    return SessionLauncher(
      apiConfig: widget.apiConfig,
      accessTokenRefresher: widget.accessTokenRefresher,
    ).acquireMobileSessionToken(
      accessToken: widget.authSession.accessToken,
      deviceId: widget.deviceId,
      appVersion: widget.apiConfig.appVersion,
    );
  }

  Future<T> _withMobileSessionRetry<T>(
    Future<T> Function(String mobileSessionToken) request,
  ) async {
    final currentToken = _mobileSessionToken;
    if (currentToken == null || currentToken.trim().isEmpty) {
      throw const IntegrityFlowException(
        'Neispravan odgovor od servera pri pokretanju sesije.',
      );
    }

    try {
      return await request(currentToken);
    } on ApiException catch (error) {
      if (error.statusCode != 401) {
        rethrow;
      }

      final nextToken = (await _acquireMobileSessionToken()).trim();
      if (nextToken.isEmpty || nextToken == currentToken) {
        rethrow;
      }

      _mobileSessionToken = nextToken;
      return request(nextToken);
    }
  }

  Future<void> _joinQueue() async {
    _elapsedTimer?.cancel();
    _pollTimer?.cancel();
    setState(() {
      _status = 'joining';
      _ticketId = null;
      _error = null;
      _opponentName = null;
      _searchStartedAt = null;
      _searchDeadlineAt = null;
      _elapsedSeconds = 0;
      _joining = true;
      _cancelling = false;
      _completed = false;
    });
    KvizAnalytics.uiAction(
      screen: 'solo_queue',
      area: 'matchmaking',
      target: 'join_queue',
      parameters: <String, Object?>{'mode': widget.modeKey},
    );
    KvizAnalytics.event(
      'queue_join',
      parameters: <String, Object?>{'mode': widget.modeKey},
    );
    try {
      final mobileSessionToken = await _acquireMobileSessionToken();
      if (usesStandardDailyQuota(widget.modeKey)) {
        final quota = await _api.getQuizAdQuota(
          accessToken: widget.authSession.accessToken,
          mobileSessionToken: mobileSessionToken,
        );
        if (!quota.modeUsesStandardQuota(widget.modeKey)) {
          // Premier users have unlimited access to this mode; backend remains authoritative.
        } else if (!quota.canStartGame) {
          if (!mounted) return;
          setState(() {
            _status = 'quota';
            _mobileSessionToken = mobileSessionToken;
            _joining = false;
            _error = t(
              'Danas si iskoristio dostupne partije. U Podešavanjima pogledaj nagrađenu reklamu za još jednu partiju.',
              'Данас си искористио доступне партије. У Подешавањима погледај награђену рекламу за још једну партију.',
            );
          });
          return;
        }
      }
      final payload = await _api.joinSoloQueue(
        accessToken: widget.authSession.accessToken,
        mobileSessionToken: mobileSessionToken,
        mode: widget.modeKey,
      );
      _mobileSessionToken = mobileSessionToken;
      await _handleQueuePayload(payload);
    } catch (error) {
      KvizAnalytics.event(
        'solo_queue_error',
        parameters: <String, Object?>{
          'mode': widget.modeKey,
          'reason': error.toString(),
        },
      );
      if (!mounted) return;
      setState(() {
        _status = 'error';
        _joining = false;
        _error = mapIntegrityError(error, widget.useCyrillic);
      });
    }
  }

  Future<void> _pollStatus() async {
    final ticketId = _ticketId;
    final mobileSessionToken = _mobileSessionToken;
    if (!_isWaiting || ticketId == null || mobileSessionToken == null) {
      return;
    }
    try {
      final payload = await _withMobileSessionRetry(
        (freshMobileToken) => _api.getSoloQueueStatus(
          accessToken: widget.authSession.accessToken,
          mobileSessionToken: freshMobileToken,
          ticketId: ticketId,
        ),
      );
      await _handleQueuePayload(payload);
    } catch (error) {
      KvizAnalytics.event(
        'solo_queue_error',
        parameters: <String, Object?>{
          'mode': widget.modeKey,
          'reason': error.toString(),
        },
      );
      if (!mounted) return;
      setState(() {
        _status = 'error';
        _joining = false;
        _error = mapIntegrityError(error, widget.useCyrillic);
      });
    }
  }

  Future<void> _handleQueuePayload(Map<String, dynamic> payload) async {
    if (!mounted) return;
    final status = payload['status']?.toString() ?? 'waiting';
    final ticketId = payload['ticket_id']?.toString().trim();
    if (status == 'waiting' && (ticketId == null || ticketId.isEmpty)) {
      throw const IntegrityFlowException('Server did not return queue ticket.');
    }
    setState(() {
      _status = status;
      _ticketId = ticketId?.isNotEmpty == true ? ticketId : _ticketId;
      _searchDeadlineAt = _parseServerDate(payload['search_deadline_at']);
      _opponentName = _opponentNameFromPayload(payload);
      _joining = false;
      _error = null;
      if (status == 'waiting') {
        _searchStartedAt ??= DateTime.now();
      }
    });
    if (status == 'matched') {
      KvizAnalytics.event(
        'queue_matched',
        parameters: <String, Object?>{
          'mode': widget.modeKey,
          'wait_seconds': _elapsedSeconds,
        },
      );
      await _openMatchedSession(payload);
      return;
    }
    if (status == 'waiting') {
      _startElapsedTimer();
      _schedulePoll(payload);
      return;
    }
    _elapsedTimer?.cancel();
    _pollTimer?.cancel();
    if (status == 'expired') {
      KvizAnalytics.event(
        'queue_timeout',
        parameters: <String, Object?>{
          'mode': widget.modeKey,
          'wait_seconds': _elapsedSeconds,
        },
      );
    }
  }

  Future<void> _openMatchedSession(Map<String, dynamic> payload) async {
    final sessionId = payload['session_id'] as String? ?? '';
    final mobileSessionToken = _mobileSessionToken;
    if (sessionId.isEmpty || mobileSessionToken == null) {
      throw const IntegrityFlowException(
        'Neispravan odgovor od servera pri pokretanju sesije.',
      );
    }
    // Check if session is already finished to avoid "stuck" bug
    try {
      final state = await _withMobileSessionRetry(
        (freshMobileToken) => _api.getQuizSessionState(
          accessToken: widget.authSession.accessToken,
          mobileSessionToken: freshMobileToken,
          sessionId: sessionId,
        ),
      );
      if (state['status'] == 'finished' || state['status'] == 'rule_broken') {
        if (!mounted) return;
        setState(() {
          _status = 'finished';
          _joining = false;
          _completed = true;
          _error = t(
            'Ova partija je već završena.',
            'Ова партија је већ завршена.',
          );
        });
        return;
      }
    } catch (_) {
      // If state check fails, proceed to open the session anyway as fallback
    }
    final onlineRounds = parseOnlineRoundsFromPayload(payload['rounds']);
    final serverMode = payload['mode']?.toString().trim();
    final matchedModeKey = serverMode != null && serverMode.isNotEmpty
        ? serverMode
        : widget.modeKey;
    _elapsedTimer?.cancel();
    _pollTimer?.cancel();
    _completed = true;
    widget.onAdQuotaChanged();
    if (!mounted) return;
    setState(() {
      _status = 'matched';
      _joining = false;
      _error = null;
    });
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => OnlineSessionPage(
          modeKey: matchedModeKey,
          sessionId: sessionId,
          mobileSessionToken: mobileSessionToken,
          accessToken: widget.authSession.accessToken,
          deviceId: widget.deviceId,
          appVersion: widget.apiConfig.appVersion,
          rounds: onlineRounds,
          modeTitle: widget.modeTitle,
          useCyrillic: widget.useCyrillic,
          api: _api,
          isDuel: true,
          onLeaderboardUpdated: widget.onLeaderboardUpdated,
          onSessionCompleted: (completion) async {
            KvizAnalytics.event(
              'match_finish',
              parameters: <String, Object?>{
                'mode': widget.modeKey,
                'score': completion.finalScore,
              },
            );
            widget.onSessionCompleted?.call();
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
              userKey: achievementUserKeyForSession(widget.authSession),
              serverConfirmedAchievements: completion.serverAchievements,
            );
          },
        ),
      ),
    );
  }

  void _startElapsedTimer() {
    _elapsedTimer?.cancel();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final startedAt = _searchStartedAt;
      if (!mounted || startedAt == null) return;
      setState(() {
        _elapsedSeconds = DateTime.now().difference(startedAt).inSeconds;
      });
    });
  }

  void _schedulePoll(Map<String, dynamic> payload) {
    var delaySeconds = (payload['poll_after_seconds'] as num?)?.toInt() ?? 2;
    if (delaySeconds < 1) {
      delaySeconds = 1;
    } else if (delaySeconds > 5) {
      delaySeconds = 5;
    }
    _pollTimer?.cancel();
    _pollTimer = Timer(Duration(seconds: delaySeconds), _pollStatus);
  }

  Future<void> _cancelQueue() async {
    if (_cancelling) {
      return;
    }
    final ticketId = _ticketId;
    final mobileSessionToken = _mobileSessionToken;
    if (ticketId == null || mobileSessionToken == null) {
      _completed = true;
      if (mounted) {
        Navigator.of(context).maybePop();
      }
      return;
    }
    setState(() => _cancelling = true);
    KvizAnalytics.uiAction(
      screen: 'solo_queue',
      area: 'matchmaking',
      target: 'cancel_queue',
      parameters: <String, Object?>{'mode': widget.modeKey},
    );
    KvizAnalytics.event(
      'queue_cancel',
      parameters: <String, Object?>{
        'mode': widget.modeKey,
        'wait_seconds': _elapsedSeconds,
      },
    );
    try {
      await _withMobileSessionRetry(
        (freshMobileToken) => _api.cancelSoloQueue(
          accessToken: widget.authSession.accessToken,
          mobileSessionToken: freshMobileToken,
          ticketId: ticketId,
        ),
      );
      _completed = true;
      if (!mounted) return;
      Navigator.of(context).maybePop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _cancelling = false;
        _error = mapIntegrityError(error, widget.useCyrillic);
      });
    }
  }

  Future<void> _cancelQueueForLifecycle() async {
    final ticketId = _ticketId;
    final mobileSessionToken = _mobileSessionToken;
    if (!_isWaiting ||
        _completed ||
        ticketId == null ||
        mobileSessionToken == null) {
      return;
    }
    _completed = true;
    _elapsedTimer?.cancel();
    _pollTimer?.cancel();
    KvizAnalytics.event(
      'queue_cancel',
      parameters: <String, Object?>{
        'mode': widget.modeKey,
        'reason': 'lifecycle',
        'wait_seconds': _elapsedSeconds,
      },
    );
    try {
      await _withMobileSessionRetry(
        (freshMobileToken) => _api.cancelSoloQueue(
          accessToken: widget.authSession.accessToken,
          mobileSessionToken: freshMobileToken,
          ticketId: ticketId,
        ),
      );
    } catch (_) {
      return;
    }
    if (!mounted) return;
    setState(() {
      _status = 'cancelled';
      _joining = false;
      _cancelling = false;
      _error = t(
        'Pretraga je otkazana jer je aplikacija napuštena.',
        'Претрага је отказана јер је апликација напуштена.',
      );
    });
  }

  DateTime? _parseServerDate(Object? raw) {
    final value = raw?.toString().trim();
    if (value == null || value.isEmpty) {
      return null;
    }
    return DateTime.tryParse(value)?.toLocal();
  }

  String? _opponentNameFromPayload(Map<String, dynamic> payload) {
    final opponent = payload['opponent'];
    if (opponent is! Map) {
      return null;
    }
    final name = opponent['name']?.toString().trim();
    if (name == null || name.isEmpty) {
      return null;
    }
    return name;
  }

  String _formatDuration(int seconds) {
    final safeSeconds = seconds < 0 ? 0 : seconds;
    final minutes = safeSeconds ~/ 60;
    final rest = safeSeconds % 60;
    return '$minutes:${rest.toString().padLeft(2, '0')}';
  }

  String get _statusTitle {
    switch (_status) {
      case 'waiting':
        return t('Tražimo protivnika...', 'Тражимо противника...');
      case 'matched':
        return t('Protivnik je pronađen', 'Противник је пронађен');
      case 'expired':
        return t('Nema protivnika trenutno', 'Нема противника тренутно');
      case 'cancelled':
        return t('Pretraga je otkazana', 'Претрага је отказана');
      case 'quota':
        return t(
          'Nema dostupnih partija danas',
          'Нема доступних партија данас',
        );
      case 'error':
        return t('Pretraga je zastala', 'Претрага је застала');
      case 'finished':
        return t('Partija je završena', 'Партија је завршена');
      default:
        return t('Pripremamo pretragu...', 'Припремамо претрагу...');
    }
  }

  String get _statusDetail {
    if (_status == 'waiting') {
      if (_isExpandedSearch) {
        return t(
          'Širimo pretragu da partija počne što pre.',
          'Ширимо претрагу да партија почне што пре.',
        );
      }
      return t(
        'Spajamo te sa igračem sličnog nivoa.',
        'Спајамо те са играчем сличног нивоа.',
      );
    }
    if (_status == 'matched') {
      final opponentName = _opponentName;
      if (opponentName != null) {
        return t('Igraš protiv: $opponentName', 'Играш против: $opponentName');
      }
      return t('Otvaramo partiju...', 'Отварамо партију...');
    }
    if (_status == 'expired') {
      return t(
        'Niko nije bio dostupan u roku. Pokušaj ponovo za trenutak.',
        'Нико није био доступан у року. Покушај поново за тренутак.',
      );
    }
    if (_status == 'quota') {
      return _error ?? '';
    }
    if (_status == 'cancelled') {
      return _error ??
          t(
            'Možeš ponovo da pokreneš pretragu kada se vratiš.',
            'Можеш поново да покренеш претрагу када се вратиш.',
          );
    }
    if (_status == 'error') {
      return _error ?? t('Pokušaj ponovo.', 'Покушај поново.');
    }
    if (_status == 'finished') {
      return _error ??
          t('Ova partija je već odigrana.', 'Ова партија је већ одиграна.');
    }
    return t(
      'Proveravamo nalog i dostupne partije.',
      'Проверавамо налог и доступне партије.',
    );
  }

  IconData get _statusIcon {
    switch (_status) {
      case 'matched':
        return Icons.check_circle_rounded;
      case 'expired':
      case 'quota':
      case 'error':
      case 'finished':
        return Icons.search_off_rounded;
      default:
        return Icons.manage_search_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final remaining = _remainingSeconds;
    final canRetry =
        !_joining &&
        !_cancelling &&
        (_status == 'expired' || _status == 'error' || _status == 'quota');
    return Scaffold(
      appBar: AppBar(
        title: Text(t('Traženje protivnika', 'Тражење противника')),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Icon(
                          _statusIcon,
                          size: 48,
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(height: 22),
                      Text(
                        _statusTitle,
                        textAlign: TextAlign.center,
                        style: textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _statusDetail,
                        textAlign: TextAlign.center,
                        style: textTheme.bodyLarge?.copyWith(
                          color: context.mutedText,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (_status == 'waiting') ...[
                        Text(
                          _formatDuration(_elapsedSeconds),
                          style: textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: scheme.primary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (remaining != null)
                          Text(
                            t(
                              'Preostalo ${_formatDuration(remaining)}',
                              'Преостало ${_formatDuration(remaining)}',
                            ),
                            style: textTheme.bodyMedium?.copyWith(
                              color: context.mutedText,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        const SizedBox(height: 18),
                        LinearProgressIndicator(
                          minHeight: 7,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ] else if (_joining) ...[
                        const SizedBox(
                          width: 34,
                          height: 34,
                          child: CircularProgressIndicator(strokeWidth: 3),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (canRetry) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _joinQueue,
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(t('Pokušaj ponovo', 'Покушај поново')),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _cancelling ? null : _cancelQueue,
                  icon: _cancelling
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.close_rounded),
                  label: Text(
                    _cancelling
                        ? t('Otkazivanje...', 'Отказивање...')
                        : t('Odustani', 'Одустани'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
