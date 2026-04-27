// Data models for online quiz rounds.
// Extracted from presentation/online_session_page.dart.

class OnlineChoice {
  const OnlineChoice({required this.label, required this.text});

  factory OnlineChoice.fromJson(dynamic raw, int index) {
    final fallbackLabel = String.fromCharCode(65 + index);
    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw as Map<Object?, Object?>);
      return OnlineChoice(
        label: map['label']?.toString() ?? fallbackLabel,
        text: map['text']?.toString() ?? '',
      );
    }

    return OnlineChoice(label: fallbackLabel, text: raw?.toString() ?? '');
  }

  final String label;
  final String text;
}

class AssociationAnswerTarget {
  const AssociationAnswerTarget({required this.key, required this.label});

  factory AssociationAnswerTarget.fromJson(dynamic raw) {
    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw as Map<Object?, Object?>);
      return AssociationAnswerTarget(
        key: map['key']?.toString() ?? 'final',
        label: map['label']?.toString() ?? 'Konačno',
      );
    }

    final key = raw?.toString() ?? 'final';
    return AssociationAnswerTarget(key: key, label: key.toUpperCase());
  }

  final String key;
  final String label;
}

class OnlineRound {
  const OnlineRound({
    required this.roundKey,
    required this.roundOrder,
    required this.durationSeconds,
    required this.payload,
    this.initialTimeLeftSeconds,
  });

  factory OnlineRound.fromJson(Map<String, dynamic> json) {
    final raw = json['payload_public'];
    final payload = (raw is Map)
        ? Map<String, dynamic>.from(raw as Map<Object?, Object?>)
        : <String, dynamic>{};
    return OnlineRound(
      roundKey: json['round_key'] as String? ?? '',
      roundOrder: (json['round_order'] as num?)?.toInt() ?? 0,
      durationSeconds: (json['duration_seconds'] as num?)?.toInt() ?? 30,
      initialTimeLeftSeconds: (json['round_time_left'] as num?)?.toInt(),
      payload: payload,
    );
  }

  final String roundKey;
  final int roundOrder;
  final int durationSeconds;
  final int? initialTimeLeftSeconds;
  final Map<String, dynamic> payload;

  int get initialDisplayTimeLeft {
    final initial = initialTimeLeftSeconds;
    if (initial == null) return durationSeconds;

    return initial.clamp(0, durationSeconds).toInt();
  }

  String get type => payload['type'] as String? ?? 'question';
  bool get isQuestion => type == 'question';
  bool get isAssociation => type == 'asocijacije';
  bool get isMyNumber => type == 'moj_broj';
  bool get isTangram => type == 'tangram';
  int? get questionId => (payload['question_id'] as num?)?.toInt();
  String? get questionText => payload['question_text'] as String?;
  String? get prompt => payload['prompt'] as String?;
  String get questionSource =>
      payload['question_source'] as String? ?? 'quiz_questions';
  int get maxAnswers => (payload['max_answers'] as num?)?.toInt() ?? 1;
  int? get target => (payload['target'] as num?)?.toInt();
  String? get title => payload['title'] as String?;
  String? get difficulty => payload['difficulty'] as String?;
  String? get hint => payload['hint'] as String?;
  Map<String, dynamic>? get tangramShape {
    final rawShape = payload['shape'];
    if (rawShape is Map) {
      return Map<String, dynamic>.from(rawShape as Map<Object?, Object?>);
    }

    return null;
  }

  String? get questionHintAnswer {
    final hint = payload['answer_hint'];
    if (hint is Map) {
      final answer = hint['answer']?.toString().trim();
      if (answer != null && answer.isNotEmpty) return answer;
    }

    return null;
  }

  int get questionHintMaxRevealPercent {
    final hint = payload['answer_hint'];
    if (hint is Map) {
      return (hint['max_reveal_percent'] as num?)?.toInt() ?? 0;
    }
    return 0;
  }

  int get questionAnswerCharCount {
    final hint = payload['answer_hint'];
    if (hint is Map) {
      return (hint['char_count'] as num?)?.toInt() ?? 0;
    }
    return 0;
  }

  List<OnlineChoice> get choices {
    final rawChoices = payload['choices'];
    if (rawChoices is List) {
      return rawChoices
          .asMap()
          .entries
          .map((entry) => OnlineChoice.fromJson(entry.value, entry.key))
          .toList();
    }
    return const [];
  }

  List<int> get numbers {
    final raw = payload['numbers'];
    if (raw is List) return raw.map((e) => (e as num).toInt()).toList();
    return const [];
  }

  List<String> get cluesA {
    return _stringList(payload['grid']?['a']);
  }

  List<String> get cluesB {
    return _stringList(payload['grid']?['b']);
  }

  List<String> get cluesC {
    return _stringList(payload['grid']?['v']);
  }

  List<String> get cluesD {
    return _stringList(payload['grid']?['g']);
  }

  List<AssociationAnswerTarget> get answerTargets {
    final raw = payload['answer_targets'];
    if (raw is List) {
      return raw.map((e) => AssociationAnswerTarget.fromJson(e)).toList();
    }
    return const [];
  }

  List<AssociationAnswerTarget> get associationTargets {
    final raw = payload['answer_targets'];
    if (raw is List) {
      final targets = raw
          .map(AssociationAnswerTarget.fromJson)
          .where((target) => target.key.trim().isNotEmpty)
          .toList(growable: false);
      if (targets.isNotEmpty) return targets;
    }

    return const [
      AssociationAnswerTarget(key: 'a', label: 'A'),
      AssociationAnswerTarget(key: 'b', label: 'B'),
      AssociationAnswerTarget(key: 'v', label: 'V'),
      AssociationAnswerTarget(key: 'g', label: 'G'),
      AssociationAnswerTarget(key: 'final', label: 'Konačno'),
    ];
  }

  Map<String, List<String>>? get associationGrid {
    final grid = payload['grid'];
    if (grid is! Map) return null;
    return {
      'a': _asList(grid['a']),
      'b': _asList(grid['b']),
      'v': _asList(grid['v']),
      'g': _asList(grid['g']),
    };
  }

  static List<String> _asList(dynamic v) {
    if (v is List) return v.map((e) => e.toString()).toList();
    return const [];
  }

  List<String> _stringList(dynamic v) {
    if (v is List) return v.map((e) => e.toString()).toList();
    return const [];
  }
}

class OnlineSessionCompletion {
  const OnlineSessionCompletion({
    required this.mode,
    required this.finalScore,
    required this.bestStreak,
    required this.correctAnswers,
    required this.answeredCount,
    required this.myNumberPerfect,
    required this.perfectKviz,
    required this.associationsMaster,
    required this.speedDemonCount,
    required this.serverAchievements,
    required this.leaderboardMode,
  });

  final String mode;
  final int finalScore;
  final int bestStreak;
  final int correctAnswers;
  final int answeredCount;
  final bool myNumberPerfect;
  final bool perfectKviz;
  final bool associationsMaster;
  final int speedDemonCount;
  final List<String> serverAchievements;
  final String? leaderboardMode;

  String get googleLeaderboardMode {
    final modeFromServer = leaderboardMode?.trim();
    if (modeFromServer != null && modeFromServer.isNotEmpty) {
      return modeFromServer;
    }

    return mode;
  }
}
