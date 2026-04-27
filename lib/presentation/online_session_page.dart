import 'dart:async';
import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../data/remote/api_exception.dart';
import '../data/remote/analytics_service.dart';
import '../data/remote/integrity_flow_service.dart';
import '../data/remote/laravel_api_service.dart';
import '../data/remote/play_integrity_service.dart';
import '../domain/my_number_expression.dart';
import '../domain/online_round_models.dart';
import '../shared/utils.dart';
import 'kviz_theme.dart';

part 'online_session/tangram_board.dart';
part 'online_session/content_report_draft.dart';
part 'online_session/session_footer_widgets.dart';
part 'online_session/content_report_flow.dart';
part 'online_session/common_question_widgets.dart';
part 'online_session/my_number_widgets.dart';
part 'online_session/tangram_widgets.dart';
part 'online_session/association_widgets.dart';
part 'online_session/answer_widgets.dart';
part 'online_session/result_widgets.dart';

// ---------------------------------------------------------------------------
// Page
// ---------------------------------------------------------------------------

class OnlineSessionPage extends StatefulWidget {
  const OnlineSessionPage({
    super.key,
    required this.modeKey,
    required this.sessionId,
    required this.mobileSessionToken,
    required this.accessToken,
    required this.deviceId,
    required this.appVersion,
    required this.rounds,
    required this.modeTitle,
    required this.useCyrillic,
    required this.api,
    this.onLeaderboardUpdated,
    this.onSessionCompleted,
    this.mobileSessionTokenProvider,
    this.isDuel = false,
  });

  final String modeKey;
  final String sessionId;
  final String mobileSessionToken;
  final String accessToken;
  final String deviceId;
  final String appVersion;
  final bool isDuel;
  final List<OnlineRound> rounds;
  final String modeTitle;
  final bool useCyrillic;
  final LaravelApiService api;
  final ValueChanged<String>? onLeaderboardUpdated;
  final Future<void> Function(OnlineSessionCompletion completion)?
  onSessionCompleted;
  final Future<String> Function(LaravelApiService api)?
  mobileSessionTokenProvider;

  @override
  State<OnlineSessionPage> createState() {
    return _OnlineSessionPageState();
  }
}

enum _InputState { idle, submitting, answered, waiting, blocked, finished }

class _OnlineSessionPageState extends State<OnlineSessionPage>
    with WidgetsBindingObserver {
  // ── session state ────────────────────────────────────────────────────────
  int _roundIdx = 0;
  int _timeLeft = 0;
  int _score = 0;
  int _streak = 0;
  int _bestStreak = 0;
  int _answeredCount = 0;
  int _correctCount = 0;
  bool _myNumberPerfect = false;
  bool _associationsMaster = false;
  late String _mobileSessionToken;
  int _fastAnswerCount = 0;
  List<String> _serverAchievementKeys = const [];
  String _sessionStatus = 'active';
  Map<String, dynamic>? _opponentProgress;
  int? _ratingDelta; // Added for rating change display
  String? _tieBreakerNote;
  List<String> _unlockedAchievementLabels = const <String>[];
  late List<OnlineRound> _rounds;

  _InputState _inputState = _InputState.idle;
  bool _lastCorrect = false;
  int _lastPoints = 0;
  String? _lastCorrectAnswer;
  String? _lastMyNumberExpression;
  int? _lastMyNumberValue;
  String? _blockMessage;
  String? _finishNote;
  final Map<String, _ContentReportDraft> _contentReportDrafts =
      <String, _ContentReportDraft>{};
  bool _contentReportsSubmitting = false;
  String? _contentReportSubmitError;

  // ── current answer ───────────────────────────────────────────────────────
  final TextEditingController _answerCtrl = TextEditingController();
  final ScrollController _pageScrollController = ScrollController();
  final _rng = Random();
  String _clientEventId = '';
  String? _selectedChoiceText;
  String _associationTarget = 'a';
  String? _lastAssociationTargetLabel;
  final Set<String> _answeredAssociationTargets = <String>{};
  final Map<String, bool> _associationTargetCorrect = <String, bool>{};
  final Map<String, String> _associationTargetSolutions = <String, String>{};
  final Map<String, String> _associationTargetOwners = <String, String>{};
  bool _associationRoundResolved = false;
  String? _associationNotice;
  final List<String> _myNumberTokens = <String>[];
  String? _myNumberError;
  final Map<String, _TangramPieceState> _tangramPieces =
      <String, _TangramPieceState>{};
  String? _selectedTangramPieceId;
  bool _tangramBoardDragActive = false;
  double? _tangramDragScrollOffset;
  bool _restoringTangramScroll = false;

  // ── current round poll / timer ───────────────────────────────────────────
  Timer? _ticker;
  Timer? _pollTimer;
  bool _lifecycleSent = false;
  bool _finishRequested = false;
  bool _roundEndTracked = false;
  bool _sessionEndTracked = false;
  final Stopwatch _sessionStopwatch = Stopwatch();
  DateTime? _roundStartedAt;
  DateTime? _answerStartedAt;
  int _totalResponseMs = 0;
  int _timedAnswerCount = 0;

  // ── helpers ──────────────────────────────────────────────────────────────
  String t(String lat, String cyr) => tr(widget.useCyrillic, lat, cyr);
  String s(Object? value) => srScript(widget.useCyrillic, value);
  String associationLabel(Object? value) =>
      srAssociationTargetLabel(widget.useCyrillic, value);

  OnlineRound? get _currentRound =>
      _roundIdx < _rounds.length ? _rounds[_roundIdx] : null;

  String _newEventId() =>
      '${DateTime.now().millisecondsSinceEpoch}_${_rng.nextInt(1000000)}';

  Map<String, dynamic>? _mapFrom(Object? raw) {
    if (raw is Map) {
      return Map<String, dynamic>.from(raw as Map<Object?, Object?>);
    }

    return null;
  }

  String? _trimmedString(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  List<String> _trimmedStringList(Object? value) {
    if (value is! List) return const <String>[];

    final answers = <String>[];
    final seen = <String>{};
    for (final item in value) {
      final answer = _trimmedString(item);
      if (answer == null) continue;

      final key = answer.toLowerCase();
      if (seen.add(key)) {
        answers.add(answer);
      }
    }

    return answers;
  }

  String? _answerSummary(Object? primary, Object? acceptedAnswers) {
    final answers = _trimmedStringList(acceptedAnswers);
    if (answers.isNotEmpty) {
      return answers.join(' / ');
    }

    return _trimmedString(primary);
  }

  void _applyAssociationProgress(
    Map<String, dynamic>? progress, {
    bool revealSolutions = false,
  }) {
    if (progress == null) return;

    final previousOwners = Map<String, String>.from(_associationTargetOwners);
    final opponentLabels = <String>[];
    final rawTargets = progress['targets'];

    if (rawTargets is List) {
      for (final rawTarget in rawTargets) {
        final target = _mapFrom(rawTarget);
        if (target == null) continue;

        final key = _trimmedString(target['key']);
        if (key == null) continue;

        final status = _trimmedString(target['status']) ?? 'open';
        final owner = _trimmedString(target['owner']);
        final correctAnswer = _answerSummary(
          target['correct_answer'],
          target['correct_answers'],
        );

        if (status == 'solved') {
          _answeredAssociationTargets.add(key);
          _associationTargetCorrect[key] = true;
          if (owner != null) {
            _associationTargetOwners[key] = owner;
          }
          if (correctAnswer != null) {
            _associationTargetSolutions[key] = correctAnswer;
          }
          if (owner == 'opponent' && previousOwners[key] != 'opponent') {
            opponentLabels.add(_trimmedString(target['label']) ?? key);
          }
        }
      }
    }

    final solutions = _mapFrom(progress['solutions']);
    if (revealSolutions || solutions != null) {
      final acceptedAnswers = _mapFrom(solutions?['accepted_answers']);
      solutions?.forEach((key, value) {
        final targetKey = key.trim();
        if (targetKey == 'accepted_answers') return;

        final answer = _answerSummary(value, acceptedAnswers?[targetKey]);
        if (targetKey.isEmpty || answer == null) return;

        _answeredAssociationTargets.add(targetKey);
        _associationTargetCorrect[targetKey] = true;
        _associationTargetOwners.putIfAbsent(targetKey, () => 'reveal');
        _associationTargetSolutions[targetKey] = answer;
      });
    }

    if (progress['round_finished'] == true || revealSolutions) {
      _associationRoundResolved = true;
    }

    final round = _currentRound;
    if (round != null && round.isAssociation) {
      _associationTarget = _activeAssociationTarget(round);
    }

    if (opponentLabels.isNotEmpty) {
      final label = associationLabel(opponentLabels.first);
      _associationNotice = t(
        'Protivnik je pogodio polje $label',
        'Противник је погодио поље $label',
      );
    }
  }

  // ── lifecycle ────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pageScrollController.addListener(_handlePageScrollOffsetChanged);
    _mobileSessionToken = widget.mobileSessionToken;
    _rounds = List<OnlineRound>.of(widget.rounds);
    KvizAnalytics.screenView(
      'online_session',
      parameters: <String, Object?>{'mode': widget.modeKey},
    );
    KvizAnalytics.gameSessionStart(
      mode: widget.modeKey,
      sessionType: 'online',
      roundCount: _rounds.length,
    );
    _sessionStopwatch.start();
    _startRound();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (!_sessionEndTracked) {
      _trackRoundEnd('abandoned');
      _trackSessionEnd(status: 'abandoned', finalScore: _score);
    }
    _ticker?.cancel();
    _pollTimer?.cancel();
    _answerCtrl.dispose();
    _pageScrollController.removeListener(_handlePageScrollOffsetChanged);
    _pageScrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_inputState == _InputState.blocked ||
        _inputState == _InputState.finished) {
      return;
    }
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _sendLifecycleEvent('background');
    }
  }

  // ── round management ────────────────────────────────────────────────────

  Future<String> _acquireMobileSessionToken() {
    final provider = widget.mobileSessionTokenProvider;
    if (provider != null) {
      return provider(widget.api);
    }

    return IntegrityFlowService(
      api: widget.api,
      playIntegrity: const PlayIntegrityService(),
    ).acquireMobileSessionToken(
      accessToken: widget.accessToken,
      deviceId: widget.deviceId,
      appVersion: widget.appVersion,
    );
  }

  Future<T> _withMobileSessionRetry<T>(
    Future<T> Function(String mobileSessionToken) request,
  ) async {
    try {
      return await request(_mobileSessionToken);
    } on ApiException catch (error) {
      if (error.statusCode != 401) {
        rethrow;
      }

      final nextToken = (await _acquireMobileSessionToken()).trim();
      if (nextToken.isEmpty || nextToken == _mobileSessionToken) {
        rethrow;
      }

      _mobileSessionToken = nextToken;
      return request(_mobileSessionToken);
    }
  }

  void _startRound() {
    _ticker?.cancel();
    _pollTimer?.cancel();
    final round = _currentRound;
    if (round == null) {
      _callFinish();
      return;
    }
    _clientEventId = _newEventId();
    _roundEndTracked = false;
    _roundStartedAt = DateTime.now();
    _answerStartedAt = _roundStartedAt;
    KvizAnalytics.roundStart(
      mode: widget.modeKey,
      sessionType: 'online',
      game: _analyticsGameForRound(round),
      roundOrder: _analyticsRoundOrder(round),
      durationSeconds: round.durationSeconds,
      questionId: round.questionId,
      questionSource: round.questionSource,
      difficulty: round.difficulty,
    );
    setState(() {
      _inputState = _InputState.idle;
      _timeLeft = round.initialDisplayTimeLeft;
      _selectedChoiceText = null;
      _associationTarget = 'a';
      _lastAssociationTargetLabel = null;
      _answeredAssociationTargets.clear();
      _associationTargetCorrect.clear();
      _associationTargetSolutions.clear();
      _associationTargetOwners.clear();
      _associationRoundResolved = false;
      _associationNotice = null;
      _myNumberTokens.clear();
      _myNumberError = null;
      _lastMyNumberExpression = null;
      _lastMyNumberValue = null;
      if (round.isTangram) {
        _resetTangramPieces();
      } else {
        _tangramPieces.clear();
        _selectedTangramPieceId = null;
      }
      _lastCorrectAnswer = null;
      _answerCtrl.clear();
    });
    _ticker = Timer.periodic(const Duration(seconds: 1), _onTick);
    _pollForNextRound(); // Fetch initial state including opponent progress
  }

  void _onTick(Timer timer) {
    if (_inputState == _InputState.blocked ||
        _inputState == _InputState.finished) {
      timer.cancel();
      return;
    }
    if (_timeLeft <= 1) {
      timer.cancel();
      setState(() => _timeLeft = 0);
      if (_inputState == _InputState.waiting) {
        _pollForNextRound();
      } else if (_inputState == _InputState.answered) {
        // User answered; result display window is still active — let
        // _scheduleAdvanceOrPoll() handle the transition, not the timer.
      } else {
        // Time ran out without answer – show result briefly, then poll.
        _trackRoundEnd('timeout');
        Future.delayed(const Duration(milliseconds: 3000), () {
          if (!mounted) return;
          _pollForNextRound();
        });
      }
    } else {
      setState(() => _timeLeft -= 1);
    }
  }

  void _pollForNextRound({
    bool immediate = false,
    Duration interval = const Duration(seconds: 3),
  }) {
    _pollTimer?.cancel();
    if (immediate) {
      unawaited(_fetchRoundState());
    }
    _pollTimer = Timer.periodic(interval, (_) => unawaited(_fetchRoundState()));
  }

  Future<void> _fetchRoundState() async {
    if (!mounted) {
      _pollTimer?.cancel();
      return;
    }
    try {
      final state = await _withMobileSessionRetry(
        (mobileSessionToken) => widget.api.getQuizSessionState(
          accessToken: widget.accessToken,
          mobileSessionToken: mobileSessionToken,
          sessionId: widget.sessionId,
        ),
      );
      if (!mounted) return;
      _handleStateResponse(state);
    } catch (_) {
      // Ignore transient errors; keep polling.
    }
  }

  void _handleStateResponse(Map<String, dynamic> state) {
    final status = state['status'] as String? ?? 'active';
    final opponentProgress = _mapFrom(state['opponent_progress']);
    final associationProgress = _mapFrom(state['association_progress']);
    final associationReveal = _mapFrom(state['association_reveal']);
    final serverScore = (state['score'] as num?)?.toInt();

    if (mounted) {
      setState(() {
        _opponentProgress = opponentProgress;
        if (serverScore != null) {
          _score = serverScore;
        }
        _applyAssociationProgress(associationProgress);
        _applyAssociationProgress(associationReveal, revealSolutions: true);
      });
    }
    if (status == 'rule_broken' || status == 'forfeited') {
      _pollTimer?.cancel();
      _applyBlocked(
        t(
          'Partija prekinuta od strane servera.',
          'Партија прекинута од стране сервера.',
        ),
      );
      return;
    }
    if (status == 'finished') {
      _pollTimer?.cancel();
      if (associationReveal != null) {
        Future.delayed(const Duration(milliseconds: 2200), () {
          if (!mounted) return;
          _callFinish();
        });
        return;
      }
      _callFinish();
      return;
    }

    final serverRoundKey = state['round_key'] as String?;
    final roundTimeLeft = (state['round_time_left'] as num?)?.toInt() ?? 0;
    final currentRoundKey = _currentRound?.roundKey;

    if (serverRoundKey != null &&
        serverRoundKey == currentRoundKey &&
        _inputState != _InputState.answered &&
        _inputState != _InputState.blocked &&
        _inputState != _InputState.finished &&
        (roundTimeLeft - _timeLeft).abs() > 1) {
      setState(() => _timeLeft = max(0, roundTimeLeft));
    }

    // If server is on a different (new) round → advance.
    final shouldAdvanceToServerRound =
        serverRoundKey != null &&
        serverRoundKey != currentRoundKey &&
        (_inputState == _InputState.waiting ||
            _timeLeft == 0 ||
            _associationRoundResolved);
    if (serverRoundKey != null &&
        serverRoundKey != currentRoundKey &&
        shouldAdvanceToServerRound) {
      _pollTimer?.cancel();
      final serverRound = _roundFromState(state);
      final nextIdx = _upsertServerRound(serverRoundKey, serverRound);
      if (nextIdx >= 0) {
        _trackRoundEnd('completed');
        final delay = associationReveal != null
            ? const Duration(milliseconds: 2200)
            : Duration.zero;
        Future.delayed(delay, () {
          if (!mounted) return;
          setState(() => _roundIdx = nextIdx);
          _startRound();
        });
      } else if (roundTimeLeft == 0) {
        _trackRoundEnd('completed');
        _callFinish();
      }
    } else if (serverRoundKey == null && roundTimeLeft == 0) {
      // Active sessions can briefly have no current round while the backend
      // advances an expired round. Keep polling; only explicit `finished`
      // status may end the game.
      return;
    }
  }

  OnlineRound? _roundFromState(Map<String, dynamic> state) {
    final roundKey = _trimmedString(state['round_key']);
    final payload = _mapFrom(state['payload_public']);
    if (roundKey == null || payload == null || payload.isEmpty) {
      return null;
    }

    final order =
        (state['current_round'] as num?)?.toInt() ?? _rounds.length + 1;
    final remaining = (state['round_time_left'] as num?)?.toInt() ?? 0;
    final duration =
        (state['duration_seconds'] as num?)?.toInt() ??
        _defaultDurationForPayload(payload, remaining);

    return OnlineRound.fromJson(<String, dynamic>{
      'round_key': roundKey,
      'round_order': order,
      'duration_seconds': duration,
      'round_time_left': remaining,
      'payload_public': payload,
    });
  }

  int _upsertServerRound(String roundKey, OnlineRound? serverRound) {
    final existingIdx = _rounds.indexWhere((r) => r.roundKey == roundKey);
    if (existingIdx >= 0) {
      if (serverRound != null) {
        _rounds[existingIdx] = serverRound;
      }
      return existingIdx;
    }

    if (serverRound == null) {
      return -1;
    }

    _rounds.add(serverRound);
    _rounds.sort((a, b) => a.roundOrder.compareTo(b.roundOrder));
    return _rounds.indexWhere((r) => r.roundKey == roundKey);
  }

  int _defaultDurationForPayload(Map<String, dynamic> payload, int remaining) {
    final type = payload['type']?.toString();
    final fallback = switch (type) {
      'asocijacije' => 100,
      'moj_broj' => 120,
      'tangram' => 120,
      'question' => 100,
      _ => 30,
    };

    return max(fallback, remaining);
  }

  // ── answer submission ────────────────────────────────────────────────────

  Future<void> _submitAnswer({Map<String, dynamic>? overridePayload}) async {
    final round = _currentRound;
    if (round == null ||
        _inputState != _InputState.idle ||
        _sessionStatus != 'active') {
      return;
    }
    final text = _answerCtrl.text.trim();
    if (overridePayload == null && text.isEmpty) return;

    final qId = round.questionId;
    if (qId == null) {
      KvizAnalytics.validationError(
        mode: widget.modeKey,
        sessionType: 'online',
        game: _analyticsGameForRound(round),
        reason: 'missing_question_id',
      );
      _advanceAfterWait();
      return;
    }

    final answerPayload = overridePayload ?? _buildAnswerPayload(round, text);
    if (answerPayload == null) {
      KvizAnalytics.validationError(
        mode: widget.modeKey,
        sessionType: 'online',
        game: _analyticsGameForRound(round),
        reason: 'invalid_payload',
      );
      return;
    }

    setState(() => _inputState = _InputState.submitting);

    try {
      final resp = await _withMobileSessionRetry(
        (mobileSessionToken) => widget.api.submitAnswer(
          accessToken: widget.accessToken,
          mobileSessionToken: mobileSessionToken,
          sessionId: widget.sessionId,
          roundKey: round.roundKey,
          questionSource: round.questionSource,
          questionId: qId,
          clientEventId: _clientEventId,
          answerPayload: answerPayload,
        ),
      );

      final isCorrect = resp['is_correct'] == true;
      final points = (resp['points_awarded'] as num?)?.toInt() ?? 0;
      final score = (resp['session_score'] as num?)?.toInt() ?? _score;
      final correctAnswer = _answerSummary(
        resp['correct_answer'],
        resp['correct_answers'],
      );
      final associationTarget = resp['association_target']?.toString().trim();
      final associationTargetLabel = resp['association_target_label']
          ?.toString()
          .trim();
      final associationProgress = _mapFrom(resp['association_progress']);
      final associationReveal = _mapFrom(resp['association_reveal']);
      final associationRoundFinished =
          resp['association_round_finished'] == true;
      final nextStep = resp['next_step'] as String? ?? 'wait';
      final isIdempotent = resp['idempotent'] == true;

      if (!isIdempotent) {
        final responseMs = _elapsedSince(_answerStartedAt);
        _totalResponseMs += responseMs;
        _timedAnswerCount += 1;
        if (responseMs < 3693) {
          _fastAnswerCount += 1;
        }
        KvizAnalytics.answerResult(
          mode: widget.modeKey,
          sessionType: 'online',
          game: _analyticsGameForRound(round),
          roundOrder: _analyticsRoundOrder(round),
          correct: isCorrect,
          responseTimeMs: responseMs,
          inputType: _inputTypeForRound(round),
          points: points,
          score: score,
          questionId: qId,
          questionSource: round.questionSource,
          difficulty: round.difficulty,
          answerLength: _answerLengthForPayload(answerPayload),
          tokenCount: _tokenCountForPayload(answerPayload),
          distance: _distanceForPayload(round, answerPayload),
        );
      }

      setState(() {
        _lastCorrect = isCorrect;
        _lastPoints = points;
        _lastCorrectAnswer =
            round.isAssociation && !isCorrect ||
                correctAnswer == null ||
                correctAnswer.isEmpty
            ? null
            : correctAnswer;
        _lastAssociationTargetLabel =
            associationTargetLabel == null || associationTargetLabel.isEmpty
            ? null
            : associationTargetLabel;
        _score = score;
        if (!isIdempotent) {
          _answeredCount += 1;
          if (round.isAssociation &&
              associationTarget != null &&
              associationTarget.isNotEmpty &&
              isCorrect) {
            _answeredAssociationTargets.add(associationTarget);
            _associationTargetCorrect[associationTarget] = true;
            _associationTargetOwners[associationTarget] = 'self';
            if (correctAnswer != null && correctAnswer.isNotEmpty) {
              _associationTargetSolutions[associationTarget] = correctAnswer;
            }
            _associationTarget = _nextAssociationTarget(round);
          }
          if (isCorrect) {
            _correctCount += 1;
            _streak += 1;
            if (_streak > _bestStreak) {
              _bestStreak = _streak;
            }
            if (round.isMyNumber) {
              _myNumberPerfect = true;
            }
          } else {
            _streak = 0;
          }
        }
        _applyAssociationProgress(associationProgress);
        _applyAssociationProgress(
          associationReveal,
          revealSolutions: associationRoundFinished,
        );
        if (associationRoundFinished) {
          _associationRoundResolved = true;
          if (_associationTargetCorrect.length >= 5) {
            _associationsMaster = true;
          }
        }
        _inputState = _InputState.answered;
      });

      if (nextStep == 'finish' || nextStep == 'wait') {
        _scheduleAdvanceOrPoll(nextStep, serverState: resp);
      } else {
        // continue → next question in same round (multiple max_answers)
        Future.delayed(const Duration(milliseconds: 1200), () {
          if (!mounted) return;
          setState(() {
            _clientEventId = _newEventId();
            _answerStartedAt = DateTime.now();
            _inputState = _InputState.idle;
            _selectedChoiceText = null;
            _lastAssociationTargetLabel = null;
            _myNumberTokens.clear();
            _myNumberError = null;
            _lastCorrectAnswer = null;
            _answerCtrl.clear();
          });
        });
      }
    } on ApiException catch (e) {
      if (e.statusCode == 409) {
        final msg = e.message.toLowerCase();
        if (msg.contains('session_blocked') || msg.contains('rule_broken')) {
          _applyBlocked(
            t(
              'Sesija je blokirana. Unos je onemogućen.',
              'Сесија је блокирана. Унос је онемогућен.',
            ),
          );
          return;
        }
        if (msg.contains('association_target_already_answered')) {
          setState(() {
            _inputState = _InputState.idle;
            _blockMessage = t(
              'To polje je već rešeno. Izaberi drugo polje.',
              'То поље је већ решено. Изабери друго поље.',
            );
          });
          return;
        }
        // expired or other 409 → just advance
        _advanceAfterWait();
      } else {
        setState(() {
          _inputState = _InputState.idle;
          final endpoint = e.path == null ? '' : ' (${e.path})';
          _blockMessage = e.statusCode >= 500
              ? t(
                  'Server trenutno ne odgovara$endpoint. Pokušaj ponovo za minut.',
                  'Сервер тренутно не одговара$endpoint. Покушај поново за минут.',
                )
              : t(
                  'Server ${e.statusCode}: ${e.message}',
                  'Сервер ${e.statusCode}: ${s(e.message)}',
                );
        });
      }
    } catch (e) {
      setState(() {
        _inputState = _InputState.idle;
        _blockMessage = e.toString();
      });
    }
  }

  Map<String, dynamic>? _buildAnswerPayload(OnlineRound round, String text) {
    if (round.isMyNumber) {
      final payload = _buildMyNumberAnswerPayload(round, text);
      if (payload == null) {
        setState(() {
          _blockMessage = t(
            'Sastavi ispravan postupak od ponuđenih brojeva.',
            'Састави исправан поступак од понуђених бројева.',
          );
        });
      }
      return payload;
    }

    if (round.isAssociation) {
      return <String, dynamic>{
        'target': _activeAssociationTarget(round),
        'answer': text,
      };
    }

    return <String, dynamic>{'answer': text};
  }

  Map<String, dynamic>? _buildMyNumberAnswerPayload(
    OnlineRound round,
    String expression,
  ) {
    final normalized = expression.trim();
    if (normalized.isEmpty) return null;

    if (round.numbers.isEmpty) {
      final fallbackValue = int.tryParse(normalized);
      if (fallbackValue == null) return null;
      return <String, dynamic>{'value': fallbackValue};
    }

    try {
      final result = MyNumberExpressionEvaluator.evaluate(
        normalized,
        round.numbers,
      );
      return <String, dynamic>{
        'value': result.value,
        'expression': normalized,
        'used_numbers': result.usedNumbers,
      };
    } on MyNumberExpressionException {
      return null;
    }
  }

  Future<void> _submitMyNumberExpression(OnlineRound round) async {
    if (_inputState != _InputState.idle || _sessionStatus != 'active') {
      return;
    }

    final expression = _myNumberExpression;
    final payload = _buildMyNumberAnswerPayload(round, expression);
    if (payload == null) {
      KvizAnalytics.validationError(
        mode: widget.modeKey,
        sessionType: 'online',
        game: _analyticsGameForRound(round),
        reason: 'invalid_expression',
      );
      setState(() {
        _myNumberError = t(
          'Postupak mora da koristi samo ponuđene brojeve, svaki najviše jednom.',
          'Поступак мора да користи само понуђене бројеве, сваки највише једном.',
        );
      });
      return;
    }

    setState(() {
      _myNumberError = null;
      _lastMyNumberExpression = payload['expression'] as String?;
      _lastMyNumberValue = payload['value'] as int?;
    });
    await _submitAnswer(overridePayload: payload);
  }

  String get _myNumberExpression => _myNumberTokens.join(' ');

  void _appendMyNumberToken(String token) {
    if (_inputState != _InputState.idle || _sessionStatus != 'active') {
      return;
    }
    setState(() {
      _myNumberTokens.add(token);
      _myNumberError = null;
    });
  }

  void _removeLastMyNumberToken() {
    if (_myNumberTokens.isEmpty ||
        _inputState != _InputState.idle ||
        _sessionStatus != 'active') {
      return;
    }
    setState(() {
      _myNumberTokens.removeLast();
      _myNumberError = null;
    });
  }

  void _clearMyNumberExpression() {
    if (_inputState != _InputState.idle || _sessionStatus != 'active') {
      return;
    }
    setState(() {
      _myNumberTokens.clear();
      _myNumberError = null;
    });
  }

  void _resetTangramPieces() {
    _tangramPieces
      ..clear()
      ..addEntries(
        _initialTangramPieces.map((piece) => MapEntry(piece.id, piece)),
      );
    _selectedTangramPieceId = null;
  }

  void _selectTangramPiece(
    OnlineRound round,
    Offset localPosition,
    Size boardSize,
  ) {
    final logical = _screenToTangramPoint(
      localPosition,
      boardSize,
      round.tangramShape,
    );

    for (final piece in _tangramPieces.values.toList().reversed) {
      if (_tangramPieceHitTest(piece, logical)) {
        setState(() {
          final selected = _tangramPieces.remove(piece.id);
          if (selected != null) {
            _tangramPieces[piece.id] = selected;
          }
          _selectedTangramPieceId = piece.id;
        });
        return;
      }
    }

    setState(() => _selectedTangramPieceId = null);
  }

  void _startTangramDrag(
    OnlineRound round,
    Offset localPosition,
    Size boardSize,
  ) {
    _rememberTangramDragScrollOffset();
    _setTangramBoardDragActive(true);
    _selectTangramPiece(round, localPosition, boardSize);
  }

  void _endTangramDrag() {
    _snapSelectedTangramPiece();
    _restoreTangramDragScrollOffset();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      _restoreTangramDragScrollOffset();
      _tangramDragScrollOffset = null;
      _setTangramBoardDragActive(false);
    });
  }

  void _rememberTangramDragScrollOffset() {
    if (!_pageScrollController.hasClients) {
      return;
    }

    _tangramDragScrollOffset = _pageScrollController.position.pixels;
  }

  void _restoreTangramDragScrollOffset() {
    final offset = _tangramDragScrollOffset;
    if (offset == null ||
        !_pageScrollController.hasClients ||
        _restoringTangramScroll) {
      return;
    }

    final position = _pageScrollController.position;
    final target = offset
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    if (position.pixels != target) {
      _restoringTangramScroll = true;
      try {
        _pageScrollController.jumpTo(target);
      } finally {
        _restoringTangramScroll = false;
      }
    }
  }

  void _handlePageScrollOffsetChanged() {
    if (!_tangramBoardDragActive) {
      return;
    }

    _restoreTangramDragScrollOffset();
  }

  void _setTangramBoardDragActive(bool active) {
    if (_tangramBoardDragActive == active) {
      return;
    }

    setState(() {
      _tangramBoardDragActive = active;
    });
  }

  void _moveSelectedTangramPiece(
    OnlineRound round,
    Offset screenDelta,
    Size boardSize,
  ) {
    _restoreTangramDragScrollOffset();
    final selectedId = _selectedTangramPieceId;
    final selected = selectedId == null ? null : _tangramPieces[selectedId];
    if (selected == null) {
      return;
    }

    final logicalDelta = _screenToTangramDelta(
      screenDelta,
      boardSize,
      round.tangramShape,
    );
    final nextPosition = selected.position + logicalDelta;
    setState(() {
      _tangramPieces[selectedId!] = selected.copyWith(
        position: _clampTangramPosition(nextPosition),
      );
    });
    _restoreTangramDragScrollOffset();
  }

  void _snapSelectedTangramPiece() {
    final selectedId = _selectedTangramPieceId;
    final selected = selectedId == null ? null : _tangramPieces[selectedId];
    if (selected == null) {
      return;
    }

    setState(() {
      _tangramPieces[selectedId!] = selected.copyWith(
        position: _snapTangramPosition(selected.position),
      );
    });
  }

  void _rotateSelectedTangramPiece(double degrees) {
    final selectedId = _selectedTangramPieceId;
    final selected = selectedId == null ? null : _tangramPieces[selectedId];
    if (selected == null) {
      return;
    }

    setState(() {
      _tangramPieces[selectedId!] = selected.copyWith(
        rotation: (selected.rotation + degrees) % 360,
      );
    });
  }

  void _flipSelectedTangramPiece() {
    final selectedId = _selectedTangramPieceId;
    final selected = selectedId == null ? null : _tangramPieces[selectedId];
    if (selected == null) {
      return;
    }

    setState(() {
      _tangramPieces[selectedId!] = selected.copyWith(
        flipped: !selected.flipped,
      );
    });
  }

  List<Map<String, dynamic>> _tangramAnswerPieces() {
    return _tangramPieces.values.map((piece) => piece.toPayload()).toList();
  }

  String _tangramPieceLabel(_TangramPieceState piece) {
    return switch (piece.kind) {
      'large_triangle' => t('Veliki trougao', 'Велики троугао'),
      'medium_triangle' => t('Srednji trougao', 'Средњи троугао'),
      'small_triangle' => t('Mali trougao', 'Мали троугао'),
      'square' => t('Kvadrat', 'Квадрат'),
      'parallelogram' => t('Paralelogram', 'Паралелограм'),
      _ => s(piece.kind),
    };
  }

  Future<void> _submitTangramSolution() async {
    if (_inputState != _InputState.idle || _sessionStatus != 'active') {
      return;
    }

    await _submitAnswer(
      overridePayload: <String, dynamic>{
        'pieces': _tangramAnswerPieces(),
        'completed': true,
      },
    );
  }

  Map<int, int> _usedMyNumberCounts() {
    final counts = <int, int>{};
    for (final token in _myNumberTokens) {
      final value = int.tryParse(token);
      if (value != null) {
        counts[value] = (counts[value] ?? 0) + 1;
      }
    }
    return counts;
  }

  Future<void> _submitChoice(OnlineChoice choice) async {
    if (_inputState != _InputState.idle || _sessionStatus != 'active') {
      return;
    }

    setState(() => _selectedChoiceText = choice.text);
    await _submitAnswer(
      overridePayload: <String, dynamic>{'answer': choice.text},
    );
  }

  String _opponentName() {
    final rawName = _opponentProgress?['name']?.toString().trim();
    if (rawName != null && rawName.isNotEmpty) {
      return rawName;
    }

    return t('Protivnik', 'Противник');
  }

  String _opponentRoundLabel() {
    final round = (_opponentProgress?['current_round'] as num?)?.toInt();
    if (round == null || round <= 0) {
      return t('${_opponentName()} igra', '${_opponentName()} игра');
    }

    return t(
      '${_opponentName()} je na $round. rundi',
      '${_opponentName()} је на $round. рунди',
    );
  }

  String _waitingMessage() {
    if (widget.isDuel) {
      return t(
        '${_opponentName()} još igra ovu rundu. Čekamo da završite zajedno.',
        '${_opponentName()} још игра ову рунду. Чекамо да завршите заједно.',
      );
    }

    return t('Čeka se sledeća runda...', 'Чека се следећа рунда...');
  }

  Duration _resultDisplayDelay({
    required String nextStep,
    required bool canAdvanceFromResponse,
    Map<String, dynamic>? serverState,
  }) {
    if (serverState?['waiting_for_opponent'] == true) {
      return const Duration(milliseconds: 5500);
    }

    if (widget.isDuel && !canAdvanceFromResponse && nextStep != 'finish') {
      return const Duration(milliseconds: 5500);
    }

    return const Duration(milliseconds: 1200);
  }

  void _scheduleAdvanceOrPoll(
    String nextStep, {
    Map<String, dynamic>? serverState,
  }) {
    final serverRoundKey = _trimmedString(serverState?['round_key']);
    final canAdvanceFromResponse =
        nextStep == 'wait' &&
        serverRoundKey != null &&
        serverRoundKey != _currentRound?.roundKey;
    final delay = _resultDisplayDelay(
      nextStep: nextStep,
      canAdvanceFromResponse: canAdvanceFromResponse,
      serverState: serverState,
    );

    Future.delayed(delay, () {
      if (!mounted ||
          _inputState == _InputState.blocked ||
          _inputState == _InputState.finished) {
        return;
      }

      if (nextStep == 'finish') {
        _callFinish();
        return;
      }

      setState(() => _inputState = _InputState.waiting);
      if (canAdvanceFromResponse && serverState != null) {
        _handleStateResponse(serverState);
      } else {
        _pollForNextRound(
          immediate: true,
          interval: const Duration(seconds: 1),
        );
      }
    });
  }

  void _advanceAfterWait() {
    setState(() => _inputState = _InputState.waiting);
    _pollForNextRound();
  }

  // ── lifecycle event ──────────────────────────────────────────────────────

  void _sendLifecycleEvent(String event) {
    if (_lifecycleSent && event == 'background') return;
    _lifecycleSent = true;
    _applyBlocked(
      t(
        'Partija je završena zbog napuštanja aplikacije.',
        'Партија је завршена због напуштања апликације.',
      ),
    );
    _withMobileSessionRetry(
      (mobileSessionToken) => widget.api.postLifecycleEvent(
        accessToken: widget.accessToken,
        mobileSessionToken: mobileSessionToken,
        sessionId: widget.sessionId,
        event: event,
        eventTimeClient: DateTime.now().toIso8601String(),
      ),
    ).ignore();
  }

  void _applyBlocked(String message) {
    _ticker?.cancel();
    _pollTimer?.cancel();
    KvizAnalytics.ruleBroken(
      mode: widget.modeKey,
      sessionType: 'online',
      reason: message,
    );
    _trackRoundEnd('rule_broken');
    _trackSessionEnd(status: 'rule_broken', finalScore: _score);
    setState(() {
      _inputState = _InputState.blocked;
      _sessionStatus = 'rule_broken';
      _blockMessage = message;
    });
  }

  // ── finish session ───────────────────────────────────────────────────────

  Future<void> _callFinish({int retryCount = 0}) async {
    if (_finishRequested && retryCount == 0 ||
        _inputState == _InputState.finished) {
      return;
    }

    _finishRequested = true;
    _ticker?.cancel();
    _pollTimer?.cancel();
    try {
      final resp = await _withMobileSessionRetry(
        (mobileSessionToken) => widget.api.finishQuizSession(
          accessToken: widget.accessToken,
          mobileSessionToken: mobileSessionToken,
          sessionId: widget.sessionId,
        ),
      );
      final finalScore =
          (resp['final_score'] as num?)?.toInt() ??
          (resp['score'] as num?)?.toInt() ??
          _score;
      final leaderboard = resp['leaderboard'];
      String? leaderboardMode;
      if (leaderboard is Map) {
        final mode = leaderboard['mode']?.toString().trim();
        if (mode != null && mode.isNotEmpty) {
          leaderboardMode = mode;
          widget.onLeaderboardUpdated?.call(mode);
        }
      }
      if (mounted) {
        _trackRoundEnd('completed');
        _trackSessionEnd(status: 'completed', finalScore: finalScore);
        final matchResult = _mapFrom(resp['match_result']);
        final achievementLabels = _achievementLabelsFrom(resp['achievements']);
        _serverAchievementKeys = _achievementKeysFrom(resp['achievements']);
        setState(() {
          _score = finalScore;
          _inputState = _InputState.finished;
          _finishNote = t('Partija završena!', 'Партија завршена!');
          _tieBreakerNote = _tieBreakerText(matchResult);
          _unlockedAchievementLabels = achievementLabels;
        });
      }
      final callback = widget.onSessionCompleted;
      if (callback != null) {
        callback(
          OnlineSessionCompletion(
            mode: widget.modeKey,
            finalScore: finalScore,
            bestStreak: _bestStreak,
            correctAnswers: _correctCount,
            answeredCount: _answeredCount,
            myNumberPerfect: _myNumberPerfect,
            perfectKviz: _correctCount > 0 && _correctCount == _answeredCount,
            associationsMaster: _associationsMaster,
            speedDemonCount: _fastAnswerCount,
            serverAchievements: _serverAchievementKeys,
            leaderboardMode: leaderboardMode,
          ),
        ).ignore();
      }
      if (mounted) {
        setState(() {
          _ratingDelta = (resp['rating_delta'] as num?)?.toInt();
        });
      }
    } catch (e) {
      if (retryCount < 2) {
        // Retry finish call a couple of times on failure
        await Future.delayed(const Duration(seconds: 2));
        return _callFinish(retryCount: retryCount + 1);
      }
      _trackRoundEnd('finish_error');
      _trackSessionEnd(status: 'finish_error', finalScore: _score);
      if (mounted) {
        setState(() {
          _inputState = _InputState.finished;
          _finishNote = t('Partija završena!', 'Партија завршена!');
        });
      }
    }
  }

  List<String> _achievementLabelsFrom(Object? raw) {
    final payload = _mapFrom(raw);
    if (payload == null) {
      return const <String>[];
    }

    final unlocked = (payload['unlocked_now'] as List? ?? const [])
        .map((item) => item.toString())
        .where((item) => item.trim().isNotEmpty)
        .toSet();
    if (unlocked.isEmpty) {
      return const <String>[];
    }

    final titles = <String, String>{};
    for (final rawItem in (payload['achievements'] as List? ?? const [])) {
      final item = _mapFrom(rawItem);
      if (item == null) {
        continue;
      }
      final key = item['key']?.toString();
      final title = item['title']?.toString();
      if (key != null && title != null && title.trim().isNotEmpty) {
        titles[key] = title.trim();
      }
    }

    return unlocked.map((key) => titles[key] ?? key).toList(growable: false);
  }

  List<String> _achievementKeysFrom(Object? raw) {
    final payload = _mapFrom(raw);
    if (payload == null) {
      return const [];
    }

    final keys = <String>[];
    for (final rawItem in (payload['achievements'] as List? ?? const [])) {
      final item = _mapFrom(rawItem);
      if (item == null) {
        continue;
      }

      final key = item['key']?.toString().trim();
      if (key != null && key.isNotEmpty) {
        keys.add(key);
      }
    }

    return keys;
  }

  String? _tieBreakerText(Map<String, dynamic>? result) {
    if (result == null) {
      return null;
    }

    if (result['draw'] == true) {
      return t(
        'Meč je nerešen. Rejting se ne menja.',
        'Меч је нерешен. Рејтинг се не мења.',
      );
    }

    if (result['tie_broken'] != true) {
      return null;
    }

    final you = _mapFrom(result['you']);
    final outcome = you?['outcome'];
    final won = outcome is num && outcome > 0.5;
    final reason = result['tie_breaker_reason']?.toString();
    final reasonText = switch (reason) {
      'faster_responses' => t('bržih odgovora', 'бржих одговора'),
      'more_first_try_correct' => t(
        'više tačnih iz prve',
        'више тачних из прве',
      ),
      'fewer_hints' => t('manje hintova', 'мање hintова'),
      'last_round_points' => t('bolje poslednje runde', 'боље последње рунде'),
      _ => t('tie-breakera', 'tie-breakera'),
    };

    return won
        ? t(
            'Izjednačen skor. Pobedio si zbog $reasonText.',
            'Изједначен скор. Победио си због $reasonText.',
          )
        : t(
            'Izjednačen skor. Protivnik je pobedio zbog $reasonText.',
            'Изједначен скор. Противник је победио због $reasonText.',
          );
  }

  String _analyticsGameForRound(OnlineRound round) {
    if (round.isAssociation) return 'asocijacije';
    if (round.isMyNumber) return 'moj_broj';
    if (round.isTangram) return 'tangram';
    return 'ko_zna_zna';
  }

  int _analyticsRoundOrder(OnlineRound round) {
    return round.roundOrder > 0 ? round.roundOrder : _roundIdx + 1;
  }

  String _inputTypeForRound(OnlineRound round) {
    if (round.isAssociation) return 'association_target';
    if (round.isTangram) return 'complete_button';
    if (round.isMyNumber) return 'expression';
    if (round.choices.isNotEmpty) return 'choice';
    return 'text';
  }

  int? _answerLengthForPayload(Map<String, dynamic> payload) {
    final answer = payload['answer']?.toString();
    if (answer != null) return answer.trim().length;

    final expression = payload['expression']?.toString();
    if (expression != null) return expression.trim().length;

    return null;
  }

  int? _tokenCountForPayload(Map<String, dynamic> payload) {
    final expression = payload['expression']?.toString().trim();
    if (expression == null || expression.isEmpty) return null;

    return expression.split(RegExp(r'\s+')).length;
  }

  int? _distanceForPayload(OnlineRound round, Map<String, dynamic> payload) {
    final target = round.target;
    final rawValue = payload['value'];
    final value = rawValue is num ? rawValue.toInt() : null;
    if (target == null || value == null) return null;

    return (target - value).abs();
  }

  String _nextAssociationTarget(OnlineRound round) {
    for (final target in round.associationTargets) {
      if (!_answeredAssociationTargets.contains(target.key)) {
        return target.key;
      }
    }

    return 'final';
  }

  String _activeAssociationTarget(OnlineRound round) {
    final exists = round.associationTargets.any(
      (target) => target.key == _associationTarget,
    );
    if (exists && !_answeredAssociationTargets.contains(_associationTarget)) {
      return _associationTarget;
    }

    return _nextAssociationTarget(round);
  }

  String _associationTargetLabel(OnlineRound round, String key) {
    if (key == 'final') return t('Konačno', 'Коначно');

    for (final target in round.associationTargets) {
      if (target.key == key) return associationLabel(target.label);
    }

    return associationLabel(key);
  }

  String? _questionHintText(OnlineRound round) {
    final answer = round.questionHintAnswer;
    if (answer == null || answer.isEmpty || round.durationSeconds <= 0) {
      return null;
    }

    final answerChars = answer.runes
        .map((rune) => String.fromCharCode(rune))
        .toList(growable: false);
    final visibleChars = answerChars
        .where((char) => char.trim().isNotEmpty)
        .length;
    if (visibleChars == 0) return null;

    final elapsed = (round.durationSeconds - _timeLeft).clamp(
      0,
      round.durationSeconds,
    );
    final elapsedRatio = elapsed / round.durationSeconds;
    final maxReveal = max(
      1,
      (visibleChars * (round.questionHintMaxRevealPercent / 100)).floor(),
    );
    final revealCount = min(maxReveal, (maxReveal * elapsedRatio).floor());

    if (revealCount <= 0) {
      return t(
        'Pomoć se otkriva kako vreme ističe.',
        'Помоћ се открива како време истиче.',
      );
    }

    var revealed = 0;
    final masked = StringBuffer();
    for (final char in answerChars) {
      if (char.trim().isEmpty) {
        masked.write(char);
      } else if (revealed < revealCount) {
        masked.write(char);
        revealed += 1;
      } else {
        masked.write('_');
      }
    }

    final percent = ((revealCount / visibleChars) * 100).round();
    return '${t('Pomoć', 'Помоћ')} $percent%: ${s(masked.toString())}';
  }

  void _trackRoundEnd(String status) {
    final round = _currentRound;
    if (_roundEndTracked || round == null) {
      return;
    }

    _roundEndTracked = true;
    KvizAnalytics.roundEnd(
      mode: widget.modeKey,
      sessionType: 'online',
      game: _analyticsGameForRound(round),
      roundOrder: _analyticsRoundOrder(round),
      status: status,
      elapsedMs: _elapsedSince(_roundStartedAt),
      score: _score,
      answeredCount: _answeredCount,
      correctCount: _correctCount,
    );
  }

  void _trackSessionEnd({required String status, required int finalScore}) {
    if (_sessionEndTracked) {
      return;
    }

    _sessionEndTracked = true;
    _sessionStopwatch.stop();
    KvizAnalytics.gameSessionEnd(
      mode: widget.modeKey,
      sessionType: 'online',
      status: status,
      finalScore: finalScore,
      answeredCount: _answeredCount,
      correctCount: _correctCount,
      durationMs: _sessionStopwatch.elapsedMilliseconds,
      averageResponseMs: _timedAnswerCount == 0
          ? 0
          : (_totalResponseMs / _timedAnswerCount).round(),
    );
  }

  int _elapsedSince(DateTime? start) {
    if (start == null) {
      return 0;
    }

    return DateTime.now().difference(start).inMilliseconds;
  }

  // ── build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop:
          _inputState == _InputState.finished ||
          _inputState == _InputState.blocked,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleManualPop();
      },
      child: Scaffold(
        backgroundColor: context.pageBg,
        appBar: AppBar(
          backgroundColor: context.pageBg,
          title: Text(
            s(widget.modeTitle),
            style: TextStyle(
              color: context.accentText,
              fontWeight: FontWeight.w800,
            ),
          ),
          iconTheme: IconThemeData(color: context.strongText),
          elevation: 0,
        ),
        body: SafeArea(
          child: ListView(
            controller: _pageScrollController,
            physics: _tangramBoardDragActive
                ? const NeverScrollableScrollPhysics()
                : null,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _buildSessionHeader(),
              const SizedBox(height: 14),
              if (_inputState == _InputState.blocked ||
                  _inputState == _InputState.finished)
                _buildEndCard()
              else
                _buildRoundContent(),
            ],
          ),
        ),
      ),
    );
  }

  void _handleManualPop() async {
    final shouldPop = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t('Napusti partiju?', 'Напусти партију?')),
        content: Text(
          t(
            'Ako napustite partiju sada, ona će se smatrati prekinutom.',
            'Ако напустите партиju сада, она ће се сматрати прекинутом.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t('Otkaži', 'Откажи')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              t('Napusti', 'Напусти'),
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (shouldPop == true && mounted) {
      _sendLifecycleEvent('abandoned');
      Navigator.of(context).pop();
    }
  }

  void _updateState(VoidCallback fn) {
    setState(fn);
  }
}
