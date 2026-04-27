import 'entities.dart';

class SessionMockData {
  const SessionMockData({
    required this.questions,
    required this.associations,
    required this.myNumberPuzzles,
    required this.tangramPuzzles,
  });

  factory SessionMockData.empty() => const SessionMockData(
    questions: [],
    associations: [],
    myNumberPuzzles: [],
    tangramPuzzles: [],
  );

  final List<QuizQuestion> questions;
  final List<AssociationPuzzle> associations;
  final List<MyNumberPuzzle> myNumberPuzzles;
  final List<TangramPuzzle> tangramPuzzles;

  bool get isEmpty {
    return questions.isEmpty &&
        associations.isEmpty &&
        myNumberPuzzles.isEmpty &&
        tangramPuzzles.isEmpty;
  }
}

class LandingStats {
  const LandingStats({
    required this.timers,
    required this.playerStats,
    required this.quota,
  });

  factory LandingStats.empty() => const LandingStats(
    timers: {
      'ko_zna_zna': 99,
      'asocijacije': 90,
      'moj_broj': 120,
      'tangram': 120,
    },
    playerStats: PlayerStats.empty(),
    quota: QuotaStats.empty(),
  );

  final Map<String, int> timers;
  final PlayerStats playerStats;
  final QuotaStats quota;
}

class QuotaStats {
  const QuotaStats({required this.streak});

  const QuotaStats.empty() : streak = 0;

  final int streak;
}

class PresenceStats {
  const PresenceStats({
    required this.onlineCount,
    required this.onlineWindowSeconds,
    required this.waitingTotal,
    required this.waitingByMode,
    required this.activeMatchCount,
  });

  const PresenceStats.empty()
    : onlineCount = 0,
      onlineWindowSeconds = 60,
      waitingTotal = 0,
      waitingByMode = const <String, int>{},
      activeMatchCount = 0;

  factory PresenceStats.fromJson(Map<String, dynamic> json) {
    final waitingByMode = <String, int>{};
    final waitingRaw = json['waiting_by_mode'];
    if (waitingRaw is Map) {
      for (final entry in waitingRaw.entries) {
        waitingByMode[entry.key.toString()] = _asInt(entry.value);
      }
    }

    return PresenceStats(
      onlineCount: _asInt(json['online_count']),
      onlineWindowSeconds: _asInt(json['online_window_seconds'], fallback: 60),
      waitingTotal: _asInt(json['waiting_total']),
      waitingByMode: waitingByMode,
      activeMatchCount: _asInt(json['active_match_count']),
    );
  }

  final int onlineCount;
  final int onlineWindowSeconds;
  final int waitingTotal;
  final Map<String, int> waitingByMode;
  final int activeMatchCount;

  int waitingForMode(String mode) => waitingByMode[mode] ?? 0;

  static int _asInt(Object? value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }
}

class PlayerStats {
  const PlayerStats({
    required this.totalScore,
    required this.gamesPlayed,
    required this.wins,
    required this.losses,
    required this.draws,
    required this.rank,
    required this.bestRank,
    required this.dailyCompletedTasks,
  });

  const PlayerStats.empty()
    : totalScore = 0,
      gamesPlayed = 0,
      wins = 0,
      losses = 0,
      draws = 0,
      rank = 0,
      bestRank = null,
      dailyCompletedTasks = 0;

  static const int dailyTaskGoal = 3;

  final int totalScore;
  final int gamesPlayed;
  final int wins;
  final int losses;
  final int draws;
  final int rank;
  final int? bestRank;
  final int dailyCompletedTasks;

  int get level => (totalScore ~/ 100) + 1;
  double get levelProgress => (totalScore % 100) / 100.0;
}
