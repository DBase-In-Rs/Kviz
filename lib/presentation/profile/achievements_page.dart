import 'package:flutter/material.dart';

import '../../data/remote/achievement_sync_service.dart';
import '../../data/remote/api_client.dart';
import '../../data/remote/api_config.dart';
import '../../data/remote/laravel_api_service.dart';
import '../../data/remote/play_games_service.dart';
import '../../domain/models.dart';
import '../../shared/utils.dart';
import '../kviz_theme.dart';
import 'widgets/achievement_tile.dart';

class AchievementsPage extends StatefulWidget {
  const AchievementsPage({
    super.key,
    required this.useCyrillic,
    required this.userKey,
    required this.stats,
    required this.apiConfig,
    required this.accessToken,
    required this.accessTokenRefresher,
  });

  final bool useCyrillic;
  final String? userKey;
  final PlayerStats stats;
  final ApiConfig apiConfig;
  final String accessToken;
  final AccessTokenRefresher accessTokenRefresher;

  @override
  State<AchievementsPage> createState() => _AchievementsPageState();
}

class _AchievementsPageState extends State<AchievementsPage> {
  late Future<List<_AchievementItem>> _future;

  String t(String latin, String cyr) => tr(widget.useCyrillic, latin, cyr);
  String s(Object? value) => srScript(widget.useCyrillic, value);

  @override
  void initState() {
    super.initState();
    _future = _loadAchievements();
  }

  Future<List<_AchievementItem>> _loadAchievements() async {
    final api = LaravelApiService(
      apiClient: ApiClient(
        baseUrl: widget.apiConfig.baseUrl,
        accessTokenRefresher: widget.accessTokenRefresher,
      ),
    );
    final service = AchievementSyncService(
      api: api,
      accessToken: widget.accessToken,
      userKey: widget.userKey,
    );

    try {
      final payload = await service.fetch();
      final raw = payload['achievements'];
      if (raw is List) {
        final parsed = raw
            .whereType<Map>()
            .map((item) => _AchievementItem.fromJson(item))
            .toList(growable: false);
        if (parsed.isNotEmpty) {
          return parsed;
        }
      }
    } catch (_) {
      // Fallback keeps the profile useful if the achievement API is offline.
    }

    return _fallbackAchievements();
  }

  List<_AchievementItem> _fallbackAchievements() {
    return <_AchievementItem>[
      _AchievementItem(
        key: PlayGamesService.firstGameAchievement,
        title: '1st',
        description: t(
          'Završi prvu online partiju.',
          'Заврши прву онлајн партију.',
        ),
        progress: widget.stats.gamesPlayed > 0 ? 1 : 0,
        target: 1,
        unlocked: widget.stats.gamesPlayed > 0,
      ),
      _AchievementItem(
        key: PlayGamesService.oneThousandPointsAchievement,
        title: t('1000 poena', '1000 поена'),
        description: t(
          'Sakupi ukupno 1000 poena.',
          'Сакупи укупно 1000 поена.',
        ),
        progress: widget.stats.totalScore,
        target: 1000,
        unlocked: widget.stats.totalScore >= 1000,
      ),
      _AchievementItem(
        key: PlayGamesService.top10LeaderboardAchievement,
        title: t('Top 10 rang lista', 'Топ 10 ранг листа'),
        description: t(
          'Uđi u prvih 10 na nekoj rang listi.',
          'Уђи у првих 10 на некој ранг листи.',
        ),
        progress: widget.stats.bestRank != null && widget.stats.bestRank! <= 10
            ? 1
            : 0,
        target: 1,
        unlocked: widget.stats.bestRank != null && widget.stats.bestRank! <= 10,
      ),
    ];
  }

  Future<void> _openGooglePlayAchievements(BuildContext context) async {
    final service = const PlayGamesService();
    await service.syncCompletedAchievements(userKey: widget.userKey);
    final opened = await service.showAchievements();
    if (!context.mounted || opened) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          t(
            'Google Play dostignuća trenutno nisu dostupna.',
            'Google Play достигнућа тренутно нису доступна.',
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.pageBg,
      appBar: AppBar(
        backgroundColor: context.pageBg,
        title: Text(t('Dostignuća', 'Достигнућа')),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                FutureBuilder<List<_AchievementItem>>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 18),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    final items = snapshot.data ?? _fallbackAchievements();
                    return Column(
                      children: [
                        for (final item in items) ...[
                          AchievementTile(
                            title: s(item.title),
                            subtitle: s(item.description),
                            completed: item.unlocked,
                            progress: item.progressRatio,
                            progressLabel: s(item.progressLabel),
                            rarityLabel: item.rarityLabel == null
                                ? null
                                : s(item.rarityLabel),
                          ),
                          const SizedBox(height: 10),
                        ],
                      ],
                    );
                  },
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: () => _openGooglePlayAchievements(context),
                  icon: const Icon(Icons.sports_esports_rounded),
                  label: Text(t('Google Play', 'Google Play')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AchievementItem {
  const _AchievementItem({
    required this.key,
    required this.title,
    required this.description,
    required this.progress,
    required this.target,
    required this.unlocked,
    this.rarityPercent,
  });

  factory _AchievementItem.fromJson(Map raw) {
    final map = raw.map(
      (key, dynamic value) => MapEntry(key.toString(), value),
    );
    return _AchievementItem(
      key: map['key']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      progress: _asInt(map['progress']),
      target: _asInt(map['target']).clamp(1, 1000000).toInt(),
      unlocked: map['unlocked'] == true,
      rarityPercent: _asDouble(map['rarity_percent']),
    );
  }

  final String key;
  final String title;
  final String description;
  final int progress;
  final int target;
  final bool unlocked;
  final double? rarityPercent;

  double get progressRatio => target <= 0 ? 0 : (progress / target).clamp(0, 1);

  String get progressLabel => target <= 1 ? '' : '$progress/$target';

  String? get rarityLabel {
    final value = rarityPercent;
    if (value == null || value <= 0 || value >= 1) {
      return null;
    }

    return 'Retko ${value.toStringAsFixed(2)}%';
  }
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

double? _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}
