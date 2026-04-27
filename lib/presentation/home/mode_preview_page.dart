import 'dart:async';
import '../../shared/online_round_parser.dart';

import 'package:flutter/material.dart';

import '../../data/local/app_repositories.dart';
import '../../data/remote/analytics_service.dart';
import '../../data/remote/api_client.dart';
import '../../data/remote/api_config.dart';
import '../../data/remote/auth_models.dart';
import '../../data/remote/integrity_flow_service.dart';
import '../../data/remote/laravel_api_service.dart';
import '../../data/remote/play_games_service.dart';
import '../../data/remote/session_launcher.dart';
import '../../domain/models.dart';
import '../../domain/entities.dart';
import '../../presentation/kviz_theme.dart';
import '../../presentation/online_session_page.dart';
import '../../shared/utils.dart';
import '../../shared/widgets/notice_card.dart';
import '../../shared/widgets/section_title.dart';
import '../../features/session/widgets/question_card.dart';
import '../../features/session/widgets/association_card.dart';
import '../../features/session/widgets/my_number_card.dart';
import '../../features/session/widgets/tangram_card.dart';
import '../../features/session/widgets/round_tile.dart';
import '../../features/queue/solo_queue_page.dart';
import '../admob_banner.dart';

class ModePreviewPage extends StatefulWidget {
  const ModePreviewPage({
    super.key,
    required this.modeKey,
    required this.onlineModeKey,
    required this.modeTitle,
    required this.modeDescription,
    required this.rounds,
    required this.timersByGame,
    required this.repositories,
    required this.useCyrillic,
    required this.authSession,
    required this.deviceId,
    required this.apiConfig,
    required this.accessTokenRefresher,
    required this.onAdQuotaChanged,
    required this.adsRemoved,
    this.onLeaderboardUpdated,
    this.onSessionCompleted,
    this.isDuel = false,
  });
  final String modeKey;
  final String? onlineModeKey;
  final String modeTitle;
  final String modeDescription;
  final List<RoundInfo> rounds;
  final Map<String, int> timersByGame;
  final AppRepositories repositories;
  final bool useCyrillic;
  final AuthSession authSession;
  final String deviceId;
  final ApiConfig apiConfig;
  final AccessTokenRefresher accessTokenRefresher;
  final VoidCallback onAdQuotaChanged;
  final bool adsRemoved;
  final ValueChanged<String>? onLeaderboardUpdated;
  final VoidCallback? onSessionCompleted;
  final bool isDuel;
  @override
  State<ModePreviewPage> createState() => _ModePreviewPageState();
}

class _ModePreviewPageState extends State<ModePreviewPage> {
  late final Future<SessionMockData> _mockDataFuture;
  bool _launchingSession = false;
  bool _showingActiveSessionAd = false;
  bool _canShowActiveSessionAd = false;
  String? _launchError;
  String t(String latin, String cyr) => tr(widget.useCyrillic, latin, cyr);
  String s(Object? value) => srScript(widget.useCyrillic, value);
  @override
  void initState() {
    super.initState();
    KvizAnalytics.screenView(
      'mode_preview',
      parameters: <String, Object?>{
        'mode': widget.modeKey,
        'online_mode': widget.onlineModeKey,
      },
    );
    _mockDataFuture = _loadMockData();
  }

  Future<void> _launchOnlineSession() async {
    if (_launchingSession) return;
    KvizAnalytics.uiAction(
      screen: 'mode_preview',
      area: 'session',
      target: 'start_online',
      parameters: <String, Object?>{
        'mode': widget.modeKey,
        'online_mode': widget.onlineModeKey,
      },
    );
    setState(() {
      _launchingSession = true;
      _launchError = null;
      _canShowActiveSessionAd = false;
    });
    try {
      final onlineModeKey = widget.onlineModeKey ?? widget.modeKey;
      final launcher = SessionLauncher(
        apiConfig: widget.apiConfig,
        accessTokenRefresher: widget.accessTokenRefresher,
      );
      final result = await launcher.launch(
        accessToken: widget.authSession.accessToken,
        deviceId: widget.deviceId,
        appVersion: widget.apiConfig.appVersion,
        modeKey: onlineModeKey,
        useCyrillic: widget.useCyrillic,
      );

      if (!mounted) return;

      switch (result) {
        case SessionLaunchSuccess(
          :final sessionId,
          :final mobileSessionToken,
          :final modeKey,
          :final roundsJson,
        ):
          final onlineRounds = parseOnlineRoundsFromPayload(roundsJson);
          widget.onAdQuotaChanged();
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => OnlineSessionPage(
                modeKey: modeKey,
                sessionId: sessionId,
                mobileSessionToken: mobileSessionToken,
                accessToken: widget.authSession.accessToken,
                deviceId: widget.deviceId,
                appVersion: widget.apiConfig.appVersion,
                rounds: onlineRounds,
                modeTitle: widget.modeTitle,
                useCyrillic: widget.useCyrillic,
                api: _buildApiForSession(),
                onLeaderboardUpdated: widget.onLeaderboardUpdated,
                onSessionCompleted: (completion) async {
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
                  KvizAnalytics.achievementUnlocked(
                    achievementKey: PlayGamesService.firstGameAchievement,
                    source: 'session_complete',
                  );
                  KvizAnalytics.achievementUnlocked(
                    achievementKey: PlayGamesService.firstGameAchievement,
                    source: 'session_complete',
                  );
                },
              ),
            ),
          );

        case SessionLaunchQuotaExhausted(:final message):
          setState(() => _launchError = message);

        case SessionLaunchError(
          :final message,
          :final hasActiveSession,
          :final quotaSnapshot,
        ):
          setState(() {
            _launchError = message;
            _canShowActiveSessionAd =
                hasActiveSession &&
                !widget.adsRemoved &&
                (quotaSnapshot?.shouldShowAds ?? true);
          });
      }
    } catch (error) {
      KvizAnalytics.event(
        'game_session_error',
        parameters: <String, Object?>{
          'mode': widget.onlineModeKey ?? widget.modeKey,
          'session_type': 'online',
          'reason': error.toString(),
        },
      );
      if (!mounted) return;
      setState(() {
        _launchError = mapIntegrityError(error, widget.useCyrillic);
      });
    } finally {
      if (mounted) setState(() => _launchingSession = false);
    }
  }

  LaravelApiService _buildApiForSession() {
    return LaravelApiService(
      apiClient: ApiClient(
        baseUrl: widget.apiConfig.baseUrl,
        accessTokenRefresher: widget.accessTokenRefresher,
      ),
    );
  }

  Future<void> _watchActiveSessionInterstitial() async {
    if (_showingActiveSessionAd || widget.adsRemoved) {
      return;
    }
    KvizAnalytics.uiAction(
      screen: 'mode_preview',
      area: 'session',
      target: 'watch_active_session_interstitial',
      parameters: <String, Object?>{
        'mode': widget.modeKey,
        'online_mode': widget.onlineModeKey,
      },
    );
    setState(() => _showingActiveSessionAd = true);
    try {
      final shown = await const KvizAdMobFullScreenAds().showInterstitial(
        placement: 'active_session_block',
      );
      if (!mounted) return;
      setState(() {
        _launchError = shown
            ? t(
                'Reklama je završena. Nova partija se otključava kada trenutna istekne ili se završi.',
                'Реклама је завршена. Нова партија се откључава када тренутна истекне или се заврши.',
              )
            : t(
                'Reklama trenutno nije dostupna. Nova partija je moguća kada trenutna istekne ili se završi.',
                'Реклама тренутно није доступна. Нова партија је могућа када тренутна истекне или се заврши.',
              );
      });
    } finally {
      if (mounted) {
        setState(() => _showingActiveSessionAd = false);
      }
    }
  }

  bool _hasRound(String gameKey) {
    return widget.rounds.any((round) => round.gameKey == gameKey);
  }

  Future<SessionMockData> _loadMockData() async {
    try {
      final includeQuiz = _hasRound('ko_zna_zna');
      final includeAssociation = _hasRound('asocijacije');
      final includeMyNumber = _hasRound('moj_broj');
      final includeTangram = _hasRound('tangram');
      final questions = includeQuiz
          ? await widget.repositories.quizRepository.fetchQuestions(limit: 3)
          : const <QuizQuestion>[];
      final associations = includeAssociation
          ? await widget.repositories.associationRepository.fetchAssociations(
              limit: 2,
            )
          : const <AssociationPuzzle>[];
      final myNumberPuzzles = includeMyNumber
          ? await widget.repositories.myNumberRepository.fetchPuzzles(limit: 2)
          : const <MyNumberPuzzle>[];
      final tangramPuzzles = includeTangram
          ? await widget.repositories.tangramRepository.fetchPuzzles(limit: 2)
          : const <TangramPuzzle>[];
      return SessionMockData(
        questions: questions,
        associations: associations,
        myNumberPuzzles: myNumberPuzzles,
        tangramPuzzles: tangramPuzzles,
      );
    } catch (_) {
      return SessionMockData.empty();
    }
  }

  void _openSoloQueue() {
    KvizAnalytics.uiAction(
      screen: 'mode_preview',
      area: 'session',
      target: 'open_solo_queue',
      parameters: <String, Object?>{
        'mode': widget.modeKey,
        'online_mode': widget.onlineModeKey,
      },
    );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SoloQueuePage(
          modeKey: widget.onlineModeKey ?? widget.modeKey,
          modeTitle: widget.modeTitle,
          useCyrillic: widget.useCyrillic,
          authSession: widget.authSession,
          deviceId: widget.deviceId,
          apiConfig: widget.apiConfig,
          accessTokenRefresher: widget.accessTokenRefresher,
          onAdQuotaChanged: widget.onAdQuotaChanged,
          onLeaderboardUpdated: widget.onLeaderboardUpdated,
          onSessionCompleted: widget.onSessionCompleted,
        ),
      ),
    );
  }

  Widget _buildActionButton(bool isLoading) {
    if (widget.onlineModeKey == null) return const SizedBox.shrink();
    if (widget.isDuel) {
      return ElevatedButton.icon(
        onPressed: isLoading ? null : _openSoloQueue,
        icon: const Icon(Icons.groups_rounded, size: 18),
        label: Text(t('Traži protivnika', 'Тражи противника')),
        style: ElevatedButton.styleFrom(
          backgroundColor: context.actionBlue,
          foregroundColor: Colors.white,
        ),
      );
    }
    return ElevatedButton.icon(
      onPressed: (_launchingSession || isLoading) ? null : _launchOnlineSession,
      icon: _launchingSession
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.play_arrow_rounded),
      label: Text(
        _launchingSession
            ? t('Pokretanje...', 'Покретање...')
            : t('Igraj odmah', 'Играј одмах'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(s(widget.modeTitle))),
      body: FutureBuilder<SessionMockData>(
        future: _mockDataFuture,
        builder: (context, snapshot) {
          final data = snapshot.data ?? SessionMockData.empty();
          final isLoading = snapshot.connectionState != ConnectionState.done;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              Text(s(widget.modeDescription), style: textTheme.bodyLarge),
              const SizedBox(height: 14),
              _buildActionButton(isLoading),
              const SizedBox(height: 18),
              Text(
                t('Runde u ovoj partiji', 'Рунде у овој партији'),
                style: textTheme.headlineSmall,
              ),
              const SizedBox(height: 10),
              ...widget.rounds.asMap().entries.map(
                (entry) => RoundTile(
                  index: entry.key + 1,
                  round: entry.value,
                  durationSeconds: widget.timersByGame[entry.value.gameKey],
                  useCyrillic: widget.useCyrillic,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                t('Primeri iz baze', 'Примери из базе'),
                style: textTheme.headlineSmall,
              ),
              const SizedBox(height: 10),
              if (isLoading) const LinearProgressIndicator(minHeight: 6),
              if (isLoading) const SizedBox(height: 10),
              if (!isLoading && data.isEmpty)
                NoticeCard(
                  text: t(
                    'Trenutno nema učitanih podataka za ovaj mod.',
                    'Тренутно нема учитаних података за овај мод.',
                  ),
                ),
              if (data.questions.isNotEmpty) ...[
                SectionTitle(title: t('Pitanja', 'Питања')),
                ...data.questions.map(
                  (question) => QuestionCard(
                    question: question,
                    useCyrillic: widget.useCyrillic,
                  ),
                ),
                const SizedBox(height: 4),
              ],
              if (data.associations.isNotEmpty) ...[
                SectionTitle(title: t('Asocijacije', 'Асоцијације')),
                ...data.associations.map(
                  (association) => AssociationCard(
                    association: association,
                    useCyrillic: widget.useCyrillic,
                  ),
                ),
                const SizedBox(height: 4),
              ],
              if (data.myNumberPuzzles.isNotEmpty) ...[
                SectionTitle(title: t('Moj Broj', 'Мој Број')),
                ...data.myNumberPuzzles.map(
                  (puzzle) => MyNumberCard(
                    puzzle: puzzle,
                    useCyrillic: widget.useCyrillic,
                  ),
                ),
                const SizedBox(height: 4),
              ],
              if (data.tangramPuzzles.isNotEmpty) ...[
                SectionTitle(title: t('Tangram', 'Танграм')),
                ...data.tangramPuzzles.map(
                  (puzzle) => TangramCard(
                    puzzle: puzzle,
                    useCyrillic: widget.useCyrillic,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              if (_launchError != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  child: Text(
                    _launchError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              if (_canShowActiveSessionAd) ...[
                OutlinedButton.icon(
                  onPressed: _showingActiveSessionAd
                      ? null
                      : _watchActiveSessionInterstitial,
                  icon: _showingActiveSessionAd
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.ondemand_video_rounded, size: 18),
                  label: Text(
                    _showingActiveSessionAd
                        ? t('Učitavanje reklame...', 'Учитавање рекламе...')
                        : t(
                            'Gledaj reklamu dok traje partija',
                            'Гледај рекламу док траје партија',
                          ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              _buildActionButton(isLoading),
              const SizedBox(height: 8),
              Text(
                t(
                  'Pravilo: ako napustite aplikaciju tokom partije, partija se prekida.',
                  'Правило: ако напустите апликацију током партије, партија се прекида.',
                ),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: context.mutedText,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
