import 'package:flutter/material.dart';
import '../../../shared/utils.dart';
import '../../../domain/models.dart';
import 'stat_summary_tile.dart';

class StatsGrid extends StatelessWidget {
  const StatsGrid({super.key, required this.stats, required this.useCyrillic});

  final LandingStats stats;
  final bool useCyrillic;

  String t(String latin, String cyr) => tr(useCyrillic, latin, cyr);

  @override
  Widget build(BuildContext context) {
    final playerStats = stats.playerStats;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        StatSummaryTile(
          icon: Icons.emoji_events_rounded,
          value: '${playerStats.totalScore}',
          label: t('Poeni', 'Поени'),
        ),
        StatSummaryTile(
          icon: Icons.sports_esports_rounded,
          value: '${playerStats.gamesPlayed}',
          label: t('Partije', 'Партије'),
        ),
        StatSummaryTile(
          icon: Icons.today_rounded,
          value:
              '${playerStats.dailyCompletedTasks}/${PlayerStats.dailyTaskGoal}',
          label: t('Danas', 'Данас'),
        ),
        StatSummaryTile(
          icon: Icons.leaderboard_rounded,
          value: playerStats.bestRank == null
              ? '-'
              : '#${playerStats.bestRank}',
          label: t('Najbolji rank', 'Најбољи ранг'),
        ),
      ],
    );
  }
}
