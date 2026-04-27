import 'package:flutter/material.dart';
import '../../../shared/utils.dart';
import '../../kviz_theme.dart';
import '../../../domain/models.dart';
import '../../../shared/widgets/player_avatar.dart';
import '../../../shared/widgets/stat_chip.dart';

class HeroCard extends StatelessWidget {
  const HeroCard({
    super.key,
    required this.isLoading,
    required this.stats,
    required this.useCyrillic,
    required this.signedInUserLabel,
    required this.avatarUrl,
  });

  final bool isLoading;
  final LandingStats stats;
  final bool useCyrillic;
  final String signedInUserLabel;
  final String? avatarUrl;

  String t(String latin, String cyr) => tr(useCyrillic, latin, cyr);

  @override
  Widget build(BuildContext context) {
    final playerStats = stats.playerStats;
    final totalPoints = isLoading ? 0 : playerStats.totalScore;
    final xpProgress = isLoading ? 0.0 : playerStats.levelProgress;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.borderColor),
      ),
      child: Row(
        children: [
          PlayerAvatar(
            label: signedInUserLabel,
            avatarUrl: avatarUrl,
            size: 58,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  signedInUserLabel.isNotEmpty
                      ? signedInUserLabel
                      : t('Igrač', 'Играч'),
                  style: TextStyle(
                    color: context.strongText,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  isLoading
                      ? t('Učitavanje...', 'Учитавање...')
                      : '${t('Nivo', 'Ниво')} ${playerStats.level}',
                  style: TextStyle(
                    color: context.accentText,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  // XP Progress Bar
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: xpProgress,
                    minHeight: 6,
                    backgroundColor: context.innerBg,
                    color: context.accentText,
                  ),
                ),
                const SizedBox(height: 10), // Spacing before stats
                Row(
                  // Streak and Rank
                  children: [
                    Flexible(
                      child: StatChip(
                        icon: Icons.local_fire_department_rounded,
                        value: stats.quota.streak.toString(),
                        label: t('dana', 'дана'),
                        color: Colors.orange,
                        isLoading: isLoading,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: StatChip(
                        icon: Icons.military_tech_rounded,
                        value: stats.playerStats.rank.toString(),
                        label: t('rank', 'ранк'),
                        color: Colors.amber,
                        isLoading: isLoading,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Column(
            // Total Points
            children: [
              const Icon(
                Icons.emoji_events_rounded,
                color: Color(0xFFFFD54F),
                size: 26,
              ),
              const SizedBox(height: 2),
              Text(
                isLoading ? '...' : '$totalPoints',
                style: TextStyle(
                  color: context.strongText,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
