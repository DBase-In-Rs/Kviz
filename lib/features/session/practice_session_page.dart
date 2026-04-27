import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/remote/analytics_service.dart';
import '../../domain/models.dart';
import '../../domain/entities.dart';
import '../../domain/my_number_expression.dart';
import '../../presentation/kviz_theme.dart';
import '../../shared/utils.dart';
import '../../shared/widgets/notice_card.dart';
import '../../shared/widgets/stat_badge.dart';
import 'widgets/association_column.dart';
import 'widgets/difficulty_badge.dart';
import 'widgets/tangram_board_painter.dart';

class PracticeSessionPage extends StatefulWidget {
  const PracticeSessionPage({
    super.key,
    required this.modeKey,
    required this.modeTitle,
    required this.rounds,
    required this.timersByGame,
    required this.data,
    required this.useCyrillic,
  });
  final String modeKey;
  final String modeTitle;
  final List<RoundInfo> rounds;
  final Map<String, int> timersByGame;
  final SessionMockData data;
  final bool useCyrillic;
  @override
  State<PracticeSessionPage> createState() => _PracticeSessionPageState();
}

class _PracticeSessionPageState extends State<PracticeSessionPage>
    with WidgetsBindingObserver {
  Timer? _ticker;
  int _roundIndex = 0;
  int _timeLeft = 0;
  int _score = 0;
  bool _finished = false;
  bool _ruleBroken = false;
  String? _ruleMessage;
  final List<String> _events = <String>[];
  int _streak = 0;
  int _totalAnswered = 0;
  int _totalCorrect = 0;
  bool _waitingForNext = false;
  bool _roundEndTracked = false;
  bool _sessionEndTracked = false;
  final Stopwatch _sessionStopwatch = Stopwatch();
  DateTime? _roundStartedAt;
  DateTime? _answerStartedAt;
  int _totalResponseMs = 0;
  int _timedAnswerCount = 0;
  int _quizIndex = 0;
  bool _quizAnswered = false;
  bool _quizCorrect = false;
  final TextEditingController _quizController = TextEditingController();
  int _associationIndex = 0;
  final TextEditingController _associationController = TextEditingController();
  bool _associationSubmitted = false;
  bool _associationCorrect = false;
  int _myNumberIndex = 0;
  final TextEditingController _myNumberController = TextEditingController();
  bool _myNumberSubmitted = false;
  bool _myNumberCorrect = false;
  int? _myNumberResult;
  String? _myNumberError;
  int _tangramIndex = 0;
  bool _tangramSubmitted = false;
  RoundInfo get _currentRound => widget.rounds[_roundIndex];
  String get _currentRoundKey => _currentRound.gameKey;
  String t(String latin, String cyr) => tr(widget.useCyrillic, latin, cyr);
  String s(Object? value) => srScript(widget.useCyrillic, value);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    KvizAnalytics.screenView(
      'practice_session',
      parameters: <String, Object?>{'mode': widget.modeKey},
    );
    KvizAnalytics.gameSessionStart(
      mode: widget.modeKey,
      sessionType: 'practice',
      roundCount: widget.rounds.length,
    );
    _sessionStopwatch.start();
    if (widget.rounds.isEmpty) {
      _finished = true;
      _finishPracticeSession('empty');
    } else {
      _startRound();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (!_sessionEndTracked) {
      _trackRoundEnd('abandoned');
      _finishPracticeSession('abandoned');
    }
    _ticker?.cancel();
    _quizController.dispose();
    _associationController.dispose();
    _myNumberController.dispose();
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
    if (_finished || _ruleBroken) {
      return;
    }
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _applyRuleViolation(
        t(
          'Partija je završena zbog napuštanja aplikacije tokom igre.',
          'Партија је завршена због напуштања апликације током игре.',
        ),
      );
    }
  }

  void _applyRuleViolation(String message) {
    _ticker?.cancel();
    KvizAnalytics.ruleBroken(
      mode: widget.modeKey,
      sessionType: 'practice',
      reason: 'background',
    );
    _trackRoundEnd('rule_broken');
    setState(() {
      _ruleBroken = true;
      _finished = true;
      _ruleMessage = message;
      _events.add(message);
    });
    _finishPracticeSession('rule_broken');
  }

  void _startRound() {
    if (_finished || _ruleBroken || widget.rounds.isEmpty) {
      return;
    }
    final duration = widget.timersByGame[_currentRoundKey] ?? 60;
    _resetRoundState();
    _roundEndTracked = false;
    _roundStartedAt = DateTime.now();
    _answerStartedAt = _roundStartedAt;
    KvizAnalytics.roundStart(
      mode: widget.modeKey,
      sessionType: 'practice',
      game: _currentRoundKey,
      roundOrder: _roundIndex + 1,
      durationSeconds: duration,
      questionId: _currentPracticeQuestionId(),
      questionSource: 'local_mock',
      difficulty: _currentPracticeDifficulty(),
    );
    _startTicker(duration);
    if (!_hasDataForCurrentRound()) {
      _trackRoundEnd('skipped');
      _events.add(
        t(
          'Runda "${s(_currentRound.title)}" je preskočena jer nema probnih podataka.',
          'Рунда "${s(_currentRound.title)}" је прескочена јер нема пробних података.',
        ),
      );
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted || _finished) {
          return;
        }
        _nextRound();
      });
    }
  }

  void _startTicker(int duration) {
    _ticker?.cancel();
    setState(() {
      _timeLeft = duration;
    });
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _finished) {
        timer.cancel();
        return;
      }
      if (_timeLeft <= 1) {
        timer.cancel();
        setState(() {
          _timeLeft = 0;
          _events.add(
            t(
              'Isteklo je vreme za rundu "${s(_currentRound.title)}".',
              'Истекло је време за рунду "${s(_currentRound.title)}".',
            ),
          );
        });
        _trackRoundEnd('timeout');
        _nextRound();
      } else {
        setState(() {
          _timeLeft -= 1;
        });
      }
    });
  }

  void _resetRoundState() {
    setState(() {
      _quizIndex = 0;
      _quizAnswered = false;
      _quizCorrect = false;
      _quizController.clear();
      _associationIndex = 0;
      _associationSubmitted = false;
      _associationCorrect = false;
      _associationController.clear();
      _myNumberIndex = 0;
      _myNumberSubmitted = false;
      _myNumberCorrect = false;
      _myNumberResult = null;
      _myNumberError = null;
      _myNumberController.clear();
      _tangramIndex = 0;
      _tangramSubmitted = false;
    });
  }

  bool _hasDataForCurrentRound() {
    switch (_currentRoundKey) {
      case 'ko_zna_zna':
        return widget.data.questions.isNotEmpty;
      case 'asocijacije':
        return widget.data.associations.isNotEmpty;
      case 'moj_broj':
        return widget.data.myNumberPuzzles.isNotEmpty;
      case 'tangram':
        return widget.data.tangramPuzzles.isNotEmpty;
      default:
        return false;
    }
  }

  void _nextRound() {
    if (_finished) {
      return;
    }
    _ticker?.cancel();
    if (_roundIndex >= widget.rounds.length - 1) {
      setState(() {
        _finished = true;
      });
      _finishPracticeSession('completed');
      return;
    }
    setState(() {
      _roundIndex += 1;
    });
    _startRound();
  }

  String _normalize(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'\s+'), '');
  }

  String _correctQuizAnswer(QuizQuestion question) {
    return switch (question.correctOption) {
      1 => question.optionA,
      2 => question.optionB,
      3 => question.optionC,
      4 => question.optionD,
      _ => '',
    };
  }

  void _submitQuizAnswer() {
    if (_finished ||
        _ruleBroken ||
        _quizAnswered ||
        widget.data.questions.isEmpty) {
      return;
    }
    final question = widget.data.questions[_quizIndex];
    final entered = _normalize(_quizController.text.trim());
    final expected = _normalize(_correctQuizAnswer(question));
    final isCorrect = entered.isNotEmpty && entered == expected;
    _trackAnswerResult(
      game: 'ko_zna_zna',
      correct: isCorrect,
      inputType: 'text',
      questionId: question.id,
      questionSource: 'local_mock',
      difficulty: question.difficulty,
      answerLength: _quizController.text.trim().length,
      points: isCorrect ? 10 : 0,
      score: _score + (isCorrect ? 10 : 0),
    );
    setState(() {
      _quizAnswered = true;
      _quizCorrect = isCorrect;
      _totalAnswered += 1;
      if (isCorrect) {
        _score += 10;
        _totalCorrect += 1;
        _streak += 1;
      } else {
        _streak = 0;
      }
      _waitingForNext = true;
    });
  }

  void _advanceQuizQuestion() {
    if (!_waitingForNext) return;
    setState(() {
      _waitingForNext = false;
    });
    if (_quizIndex < widget.data.questions.length - 1) {
      setState(() {
        _quizIndex += 1;
        _quizAnswered = false;
        _quizCorrect = false;
        _quizController.clear();
      });
      _answerStartedAt = DateTime.now();
    } else {
      _trackRoundEnd('completed');
      _events.add(
        t('Runda "Ko zna zna" je završena.', 'Рунда "Ко зна зна" је завршена.'),
      );
      _nextRound();
    }
  }

  void _submitAssociation() {
    if (_finished ||
        _ruleBroken ||
        _associationSubmitted ||
        widget.data.associations.isEmpty) {
      return;
    }
    final puzzle = widget.data.associations[_associationIndex];
    final entered = _normalize(_associationController.text.trim());
    final expected = _normalize(puzzle.solutionFinal);
    final isCorrect = entered.isNotEmpty && entered == expected;
    _trackAnswerResult(
      game: 'asocijacije',
      correct: isCorrect,
      inputType: 'text',
      questionId: puzzle.id,
      questionSource: 'local_mock',
      answerLength: _associationController.text.trim().length,
      points: isCorrect ? 12 : 0,
      score: _score + (isCorrect ? 12 : 0),
    );
    setState(() {
      _associationSubmitted = true;
      _associationCorrect = isCorrect;
      _totalAnswered += 1;
      if (isCorrect) {
        _score += 12;
        _totalCorrect += 1;
        _streak += 1;
      } else {
        _streak = 0;
      }
    });
    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted || _finished) {
        return;
      }
      if (_associationIndex < widget.data.associations.length - 1) {
        setState(() {
          _associationIndex += 1;
          _associationSubmitted = false;
          _associationCorrect = false;
          _associationController.clear();
        });
        _answerStartedAt = DateTime.now();
      } else {
        _trackRoundEnd('completed');
        _events.add(
          t(
            'Runda "Asocijacije" je završena.',
            'Рунда "Асоцијације" је завршена.',
          ),
        );
        _nextRound();
      }
    });
  }

  void _submitMyNumber() {
    if (_finished ||
        _ruleBroken ||
        _myNumberSubmitted ||
        widget.data.myNumberPuzzles.isEmpty) {
      return;
    }
    final puzzle = widget.data.myNumberPuzzles[_myNumberIndex];
    final expression = _myNumberController.text.trim();
    MyNumberExpressionResult result;
    try {
      result = MyNumberExpressionEvaluator.evaluate(expression, puzzle.numbers);
    } on MyNumberExpressionException {
      KvizAnalytics.validationError(
        mode: widget.modeKey,
        sessionType: 'practice',
        game: 'moj_broj',
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
    final isCorrect = result.value == puzzle.target;
    _trackAnswerResult(
      game: 'moj_broj',
      correct: isCorrect,
      inputType: 'expression',
      questionId: puzzle.id,
      questionSource: 'local_mock',
      difficulty: puzzle.difficulty,
      answerLength: expression.length,
      tokenCount: expression
          .split(RegExp(r'\s+'))
          .where((v) => v.isNotEmpty)
          .length,
      distance: result.distanceTo(puzzle.target),
      points: isCorrect ? 12 : 0,
      score: _score + (isCorrect ? 12 : 0),
    );
    setState(() {
      _myNumberSubmitted = true;
      _myNumberCorrect = isCorrect;
      _myNumberResult = result.value;
      _myNumberError = null;
      _totalAnswered += 1;
      if (isCorrect) {
        _score += 12;
        _totalCorrect += 1;
        _streak += 1;
      } else {
        _streak = 0;
      }
    });
    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted || _finished) {
        return;
      }
      if (_myNumberIndex < widget.data.myNumberPuzzles.length - 1) {
        setState(() {
          _myNumberIndex += 1;
          _myNumberSubmitted = false;
          _myNumberCorrect = false;
          _myNumberResult = null;
          _myNumberError = null;
          _myNumberController.clear();
        });
        _answerStartedAt = DateTime.now();
      } else {
        _trackRoundEnd('completed');
        _events.add(
          t('Runda "Moj Broj" je završena.', 'Рунда "Мој Број" је завршена.'),
        );
        _nextRound();
      }
    });
  }

  void _submitTangramDone() {
    if (_finished ||
        _ruleBroken ||
        _tangramSubmitted ||
        widget.data.tangramPuzzles.isEmpty) {
      return;
    }
    final puzzle = widget.data.tangramPuzzles[_tangramIndex];
    _trackAnswerResult(
      game: 'tangram',
      correct: true,
      inputType: 'complete_button',
      questionId: puzzle.id,
      questionSource: 'local_mock',
      difficulty: puzzle.difficulty,
      points: 10,
      score: _score + 10,
    );
    setState(() {
      _tangramSubmitted = true;
      _score += 10;
      _totalAnswered += 1;
      _totalCorrect += 1;
      _streak += 1;
    });
    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted || _finished) {
        return;
      }
      if (_tangramIndex < widget.data.tangramPuzzles.length - 1) {
        setState(() {
          _tangramIndex += 1;
          _tangramSubmitted = false;
        });
        _answerStartedAt = DateTime.now();
      } else {
        _trackRoundEnd('completed');
        _events.add(
          t('Runda "Tangram" je završena.', 'Рунда "Танграм" је завршена.'),
        );
        _nextRound();
      }
    });
  }

  int? _currentPracticeQuestionId() {
    switch (_currentRoundKey) {
      case 'ko_zna_zna':
        return widget.data.questions.isEmpty
            ? null
            : widget.data.questions[_quizIndex].id;
      case 'asocijacije':
        return widget.data.associations.isEmpty
            ? null
            : widget.data.associations[_associationIndex].id;
      case 'moj_broj':
        return widget.data.myNumberPuzzles.isEmpty
            ? null
            : widget.data.myNumberPuzzles[_myNumberIndex].id;
      case 'tangram':
        return widget.data.tangramPuzzles.isEmpty
            ? null
            : widget.data.tangramPuzzles[_tangramIndex].id;
    }
    return null;
  }

  String? _currentPracticeDifficulty() {
    switch (_currentRoundKey) {
      case 'ko_zna_zna':
        return widget.data.questions.isEmpty
            ? null
            : widget.data.questions[_quizIndex].difficulty;
      case 'moj_broj':
        return widget.data.myNumberPuzzles.isEmpty
            ? null
            : widget.data.myNumberPuzzles[_myNumberIndex].difficulty;
      case 'tangram':
        return widget.data.tangramPuzzles.isEmpty
            ? null
            : widget.data.tangramPuzzles[_tangramIndex].difficulty;
    }
    return null;
  }

  void _trackAnswerResult({
    required String game,
    required bool correct,
    required String inputType,
    int? questionId,
    String? questionSource,
    String? difficulty,
    int? answerLength,
    int? tokenCount,
    int? distance,
    int? points,
    int? score,
  }) {
    final responseMs = _elapsedSince(_answerStartedAt);
    _totalResponseMs += responseMs;
    _timedAnswerCount += 1;
    KvizAnalytics.answerResult(
      mode: widget.modeKey,
      sessionType: 'practice',
      game: game,
      roundOrder: _roundIndex + 1,
      correct: correct,
      responseTimeMs: responseMs,
      inputType: inputType,
      points: points,
      score: score,
      questionId: questionId,
      questionSource: questionSource,
      difficulty: difficulty,
      answerLength: answerLength,
      tokenCount: tokenCount,
      distance: distance,
    );
  }

  void _trackRoundEnd(String status) {
    if (_roundEndTracked || widget.rounds.isEmpty) {
      return;
    }
    _roundEndTracked = true;
    KvizAnalytics.roundEnd(
      mode: widget.modeKey,
      sessionType: 'practice',
      game: _currentRoundKey,
      roundOrder: _roundIndex + 1,
      status: status,
      elapsedMs: _elapsedSince(_roundStartedAt),
      score: _score,
      answeredCount: _totalAnswered,
      correctCount: _totalCorrect,
    );
  }

  void _finishPracticeSession(String status) {
    if (_sessionEndTracked) {
      return;
    }
    _sessionEndTracked = true;
    _sessionStopwatch.stop();
    KvizAnalytics.gameSessionEnd(
      mode: widget.modeKey,
      sessionType: 'practice',
      status: status,
      finalScore: _score,
      answeredCount: _totalAnswered,
      correctCount: _totalCorrect,
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

  @override
  Widget build(BuildContext context) {
    final totalRounds = widget.rounds.length;
    final progress = totalRounds == 0 ? 0.0 : (_roundIndex + 1) / totalRounds;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${s(widget.modeTitle)} - ${t('probna partija', 'пробна партија')}',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        children: [
          if (_finished) _buildFinishedCard(context),
          if (!_finished) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${t('Runda', 'Рунда')} ${_roundIndex + 1}/$totalRounds: ${s(_currentRound.title)}',
                    style: TextStyle(
                      color: context.strongText,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${t('Preostalo vreme', 'Преостало време')}: ${_timeLeft}s',
                    style: TextStyle(
                      color: context.mutedText,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(8),
                    backgroundColor: context.innerBg,
                    color: context.accentText,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${t('Skor', 'Скор')}: $_score',
                    style: TextStyle(
                      color: context.strongText,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _buildRoundContent(),
          ],
        ],
      ),
    );
  }

  Widget _buildFinishedCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _ruleBroken ? scheme.error : scheme.outlineVariant,
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _ruleBroken
                ? t('Partija prekinuta', 'Партија прекинута')
                : t('Partija završena', 'Партија завршена'),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: _ruleBroken ? scheme.error : scheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          if (_ruleMessage != null)
            Text(
              s(_ruleMessage!),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          if (_ruleMessage != null) const SizedBox(height: 8),
          Text(
            '${t('Ukupan skor', 'Укупан скор')}: $_score',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          if (_events.isNotEmpty) ...[
            Text(
              t('Zapisi', 'Записи'),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            ..._events.map(
              (event) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '- ${s(event)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_rounded),
            label: Text(t('Nazad na izbor moda', 'Назад на избор мода')),
          ),
        ],
      ),
    );
  }

  Widget _buildRoundContent() {
    if (_ruleBroken) {
      return NoticeCard(
        text: t(
          'Partija je prekinuta zbog kršenja pravila.',
          'Партија је прекинута због кршења правила.',
        ),
      );
    }
    switch (_currentRoundKey) {
      case 'ko_zna_zna':
        return _buildQuizRound();
      case 'asocijacije':
        return _buildAssociationRound();
      case 'moj_broj':
        return _buildMyNumberRound();
      case 'tangram':
        return _buildTangramRound();
      default:
        return NoticeCard(
          text: t(
            'Ova runda još nije pripremljena.',
            'Ова рунда још није припремљена.',
          ),
        );
    }
  }

  Widget _buildQuizRound() {
    if (widget.data.questions.isEmpty) {
      return NoticeCard(
        text: t(
          'Nema učitanih pitanja za ovu rundu.',
          'Нема учитаних питања за ову рунду.',
        ),
      );
    }
    final question = widget.data.questions[_quizIndex];
    final correctAnswer = _correctQuizAnswer(question);
    final accuracy = _totalAnswered == 0
        ? 100
        : (_totalCorrect * 100 ~/ _totalAnswered);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: context.innerBg,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            t('Opšta kultura', 'Општа култура'),
            style: TextStyle(
              color: context.accentText,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          s(question.question),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: context.strongText,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _quizController,
          enabled: !_quizAnswered,
          textCapitalization: TextCapitalization.sentences,
          style: TextStyle(
            color: context.strongText,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
          decoration: InputDecoration(
            hintText: t('Upiši odgovor...', 'Упиши одговор...'),
            hintStyle: TextStyle(color: context.mutedText),
            filled: true,
            fillColor: context.cardBg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: context.borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: context.borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: context.accentText, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
          onSubmitted: (_) => _submitQuizAnswer(),
        ),
        const SizedBox(height: 10),
        if (!_quizAnswered)
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _submitQuizAnswer,
              child: Text(
                t('Potvrdi odgovor', 'Потврди одговор'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        if (_quizAnswered) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _quizCorrect
                  ? context.successBg
                  : Theme.of(context).colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.emoji_events_rounded,
                  color: _quizCorrect
                      ? const Color(0xFFFFD54F)
                      : const Color(0xFFEF5350),
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _quizCorrect
                        ? t('Tačno! +10 poena', 'Тачно! +10 поена')
                        : t(
                            'Netačno. Tačan odgovor je: ${s(correctAnswer)}',
                            'Нетачно. Тачан одговор је: ${s(correctAnswer)}',
                          ),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: _quizCorrect
                          ? context.successColor
                          : Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _advanceQuizQuestion,
            child: Text(
              t('Sledeće pitanje', 'Следеће питање'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ),
        ],
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: context.innerBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.borderColor),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              StatBadge(
                icon: Icons.stars_rounded,
                value: '$_score',
                label: t('Poeni', 'Поени'),
              ),
              StatBadge(
                icon: Icons.local_fire_department_rounded,
                value: '$_streak',
                label: t('Niz', 'Низ'),
              ),
              StatBadge(
                icon: Icons.percent_rounded,
                value: '$accuracy%',
                label: t('Uspešnost', 'Успешност'),
              ),
              StatBadge(
                icon: Icons.timer_rounded,
                value: '${_timeLeft}s',
                label: t('Vreme', 'Време'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAssociationRound() {
    if (widget.data.associations.isEmpty) {
      return NoticeCard(
        text: t(
          'Nema učitanih asocijacija za ovu rundu.',
          'Нема учитаних асоцијација за ову рунду.',
        ),
      );
    }
    final scheme = Theme.of(context).colorScheme;
    final puzzle = widget.data.associations[_associationIndex];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant, width: 1.1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${t('Asocijacija', 'Асоцијација')} ${_associationIndex + 1}/${widget.data.associations.length}',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              AssociationColumn(
                title: 'A',
                clues: puzzle.cluesA,
                useCyrillic: widget.useCyrillic,
              ),
              AssociationColumn(
                title: 'B',
                clues: puzzle.cluesB,
                useCyrillic: widget.useCyrillic,
              ),
              AssociationColumn(
                title: 'C',
                clues: puzzle.cluesC,
                useCyrillic: widget.useCyrillic,
              ),
              AssociationColumn(
                title: 'D',
                clues: puzzle.cluesD,
                useCyrillic: widget.useCyrillic,
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _associationController,
            enabled: !_associationSubmitted,
            decoration: InputDecoration(
              labelText: t('Unesite konačno rešenje', 'Унесите коначно решење'),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: _associationSubmitted ? null : _submitAssociation,
            child: Text(t('Potvrdi rešenje', 'Потврди решење')),
          ),
          if (_associationSubmitted) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _associationCorrect
                    ? context.successBg
                    : Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _associationCorrect
                            ? Icons.check_circle_rounded
                            : Icons.cancel_rounded,
                        color: _associationCorrect
                            ? context.successColor
                            : Theme.of(context).colorScheme.error,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _associationCorrect
                            ? t('Tačno rešenje!', 'Тачно решење!')
                            : t('Netačno rešenje.', 'Нетачно решење.'),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: _associationCorrect
                              ? context.successColor
                              : Theme.of(context).colorScheme.onErrorContainer,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildSolutionRow(
                    t('Kolona A', 'Колона А'),
                    puzzle.solutionA,
                    scheme,
                  ),
                  _buildSolutionRow(
                    t('Kolona B', 'Колона Б'),
                    puzzle.solutionB,
                    scheme,
                  ),
                  _buildSolutionRow(
                    t('Kolona C', 'Колона Ц'),
                    puzzle.solutionC,
                    scheme,
                  ),
                  _buildSolutionRow(
                    t('Kolona D', 'Колона Д'),
                    puzzle.solutionD,
                    scheme,
                  ),
                  const Divider(height: 20),
                  _buildSolutionRow(
                    t('Konačno rešenje', 'Коначно решење'),
                    puzzle.solutionFinal,
                    scheme,
                    isFinal: true,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMyNumberRound() {
    if (widget.data.myNumberPuzzles.isEmpty) {
      return NoticeCard(
        text: t(
          'Nema učitanih zadataka za Moj Broj.',
          'Нема учитаних задатака за Мој Број.',
        ),
      );
    }
    final scheme = Theme.of(context).colorScheme;
    final puzzle = widget.data.myNumberPuzzles[_myNumberIndex];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant, width: 1.1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${t('Moj Broj', 'Мој Број')} ${_myNumberIndex + 1}/${widget.data.myNumberPuzzles.length}',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            '${t('Brojevi', 'Бројеви')}: ${puzzle.numbers.join(', ')}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            '${t('Traženi broj', 'Тражени број')}: ${puzzle.target}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _myNumberController,
            enabled: !_myNumberSubmitted,
            keyboardType: TextInputType.text,
            decoration: InputDecoration(
              labelText: t('Unesite postupak', 'Унесите поступак'),
              hintText: '100 + 50',
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) {
              if (_myNumberError != null) {
                setState(() => _myNumberError = null);
              }
            },
          ),
          if (_myNumberError != null) ...[
            const SizedBox(height: 8),
            Text(
              _myNumberError!,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: _myNumberSubmitted ? null : _submitMyNumber,
            child: Text(t('Potvrdi postupak', 'Потврди поступак')),
          ),
          if (_myNumberSubmitted) ...[
            const SizedBox(height: 8),
            Text(
              _myNumberCorrect
                  ? t('Tačan postupak.', 'Тачан поступак.')
                  : t(
                      'Rezultat je ${_myNumberResult ?? '-'}. Traženi broj je ${puzzle.target}.',
                      'Резултат је ${_myNumberResult ?? '-'}. Тражени број је ${puzzle.target}.',
                    ),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: _myNumberCorrect
                    ? context.successColor
                    : Theme.of(context).colorScheme.error,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSolutionRow(
    String label,
    String value,
    ColorScheme scheme, {
    bool isFinal = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: context.mutedText,
              ),
            ),
          ),
          Expanded(
            child: Text(
              s(value),
              style: TextStyle(
                fontSize: isFinal ? 16 : 14,
                fontWeight: isFinal ? FontWeight.w900 : FontWeight.w700,
                color: isFinal ? context.accentText : context.strongText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTangramRound() {
    if (widget.data.tangramPuzzles.isEmpty) {
      return NoticeCard(
        text: t(
          'Nema učitanih Tangram figura.',
          'Нема учитаних Танграм фигура.',
        ),
      );
    }
    final scheme = Theme.of(context).colorScheme;
    final puzzle = widget.data.tangramPuzzles[_tangramIndex];
    final accuracy = _totalAnswered == 0
        ? 100
        : (_totalCorrect * 100 ~/ _totalAnswered);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: context.innerBg,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            t('Tangram', 'Танграм'),
            style: TextStyle(
              color: context.accentText,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scheme.outlineVariant, width: 1.1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '${t('Tangram', 'Танграм')} ${_tangramIndex + 1}/${widget.data.tangramPuzzles.length}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  DifficultyBadge(
                    label: s(puzzle.difficulty),
                    difficulty: puzzle.difficulty,
                    scheme: scheme,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                s(puzzle.title),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF333333),
                ),
              ),
              const SizedBox(height: 14),
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest.withValues(
                        alpha: 0.6,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: scheme.outlineVariant.withValues(alpha: 0.5),
                      ),
                    ),
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: TangramBoardPainter(
                          fillColor: scheme.primary.withValues(alpha: 0.3),
                          lineColor: scheme.primary.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.timer_rounded,
                    size: 16,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${puzzle.timeLimitSeconds}s',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    Icons.grid_view_rounded,
                    size: 16,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '7 ${t('delova', 'делова')}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.lightbulb_rounded,
                      size: 18,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        s(puzzle.hint),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (!_tangramSubmitted)
                SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _submitTangramDone,
                    icon: const Icon(Icons.check_rounded),
                    label: Text(
                      t('Završio sam slaganje', 'Завршио сам слагање'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              if (_tangramSubmitted) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: context.successBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.emoji_events_rounded,
                        color: const Color(0xFFFFD54F),
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        t('Figura složena!', 'Фигура сложена!'),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: context.successColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: context.innerBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.borderColor),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              StatBadge(
                icon: Icons.stars_rounded,
                value: '$_score',
                label: t('Poeni', 'Поени'),
              ),
              StatBadge(
                icon: Icons.local_fire_department_rounded,
                value: '$_streak',
                label: t('Niz', 'Низ'),
              ),
              StatBadge(
                icon: Icons.percent_rounded,
                value: '$accuracy%',
                label: t('Uspešnost', 'Успешност'),
              ),
              StatBadge(
                icon: Icons.timer_rounded,
                value: '${_timeLeft}s',
                label: t('Vreme', 'Време'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
