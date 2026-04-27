class KvizAdQuotaSnapshot {
  const KvizAdQuotaSnapshot({
    required this.dateKey,
    required this.freeGamesPerDay,
    required this.rewardedGrantsPerDay,
    required this.maxGamesPerDay,
    required this.gamesStartedToday,
    required this.rewardGrantsToday,
    required this.usedRewardedGames,
    required this.availableRewardedGames,
    required this.dailyGameCapacity,
    required this.remainingGamesToday,
    required this.remainingRewardGrantsToday,
    required this.canStartGame,
    required this.canGrantReward,
    required this.adsRemoved,
    required this.unlimitedGames,
    required this.hasNoAds,
    required this.hasPremier,
    required this.standardQuotaModes,
    required this.unlimitedModes,
  });

  factory KvizAdQuotaSnapshot.fromJson(Map<String, dynamic> json) {
    final entitlements = _asMap(json['subscription_entitlements']);
    return KvizAdQuotaSnapshot(
      dateKey: json['date_key']?.toString() ?? '',
      freeGamesPerDay: _asInt(json['free_games_per_day'], fallback: 5),
      rewardedGrantsPerDay: _asInt(
        json['rewarded_grants_per_day'],
        fallback: 5,
      ),
      maxGamesPerDay: _asInt(json['max_games_per_day'], fallback: 10),
      gamesStartedToday: _asInt(json['games_started_today']),
      rewardGrantsToday: _asInt(json['reward_grants_today']),
      usedRewardedGames: _asInt(json['used_rewarded_games']),
      availableRewardedGames: _asInt(json['available_rewarded_games']),
      dailyGameCapacity: _asInt(json['daily_game_capacity'], fallback: 5),
      remainingGamesToday: _asInt(json['remaining_games_today']),
      remainingRewardGrantsToday: _asInt(json['remaining_reward_grants_today']),
      canStartGame: _asBool(json['can_start_game']),
      canGrantReward: _asBool(json['can_grant_reward']),
      adsRemoved:
          _asBool(json['ads_removed']) || _asBool(entitlements?['ads_removed']),
      unlimitedGames:
          _asBool(json['unlimited_games']) ||
          _asBool(entitlements?['unlimited_games']),
      hasNoAds:
          _asBool(json['has_no_ads']) || _asBool(entitlements?['has_no_ads']),
      hasPremier:
          _asBool(json['has_premier']) || _asBool(entitlements?['has_premier']),
      standardQuotaModes: _asStringList(json['standard_quota_modes']),
      unlimitedModes: _asStringList(json['unlimited_modes']),
    );
  }

  final String dateKey;
  final int freeGamesPerDay;
  final int rewardedGrantsPerDay;
  final int maxGamesPerDay;
  final int gamesStartedToday;
  final int rewardGrantsToday;
  final int usedRewardedGames;
  final int availableRewardedGames;
  final int dailyGameCapacity;
  final int remainingGamesToday;
  final int remainingRewardGrantsToday;
  final bool canStartGame;
  final bool canGrantReward;
  final bool adsRemoved;
  final bool unlimitedGames;
  final bool hasNoAds;
  final bool hasPremier;
  final List<String> standardQuotaModes;
  final List<String> unlimitedModes;

  bool get shouldShowAds => !adsRemoved && !hasNoAds && !hasPremier;

  bool modeUsesStandardQuota(String modeKey) {
    final normalized = modeKey.trim();
    if (normalized.isEmpty) return false;
    if (standardQuotaModes.isNotEmpty) {
      return standardQuotaModes.contains(normalized);
    }
    return normalized != 'premier';
  }

  static int _asInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  static bool _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      return value.toLowerCase() == 'true' || value == '1';
    }
    return false;
  }

  static Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, dynamic data) => MapEntry('$key', data));
    }
    return null;
  }

  static List<String> _asStringList(dynamic value) {
    if (value is List) {
      return value
          .map((entry) => entry?.toString().trim() ?? '')
          .where((entry) => entry.isNotEmpty)
          .toList(growable: false);
    }
    return const <String>[];
  }
}
