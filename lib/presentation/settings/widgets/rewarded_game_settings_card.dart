import 'package:flutter/material.dart';
import '../../../shared/utils.dart';
import '../../kviz_theme.dart';
import '../../../data/remote/ad_reward_quota.dart'; // KvizAdQuotaSnapshot
import 'quota_chip.dart';
import 'settings_panel.dart';

class RewardedGameSettingsCard extends StatelessWidget {
  const RewardedGameSettingsCard({
    super.key,
    required this.useCyrillic,
    required this.quota,
    required this.isLoading,
    required this.hasError,
    required this.inProgress,
    required this.message,
    required this.onWatchAd,
  });

  final bool useCyrillic;
  final KvizAdQuotaSnapshot? quota;
  final bool isLoading;
  final bool hasError;
  final bool inProgress;
  final String? message;
  final VoidCallback onWatchAd;

  String t(String latin, String cyr) => tr(useCyrillic, latin, cyr);

  @override
  Widget build(BuildContext context) {
    final currentQuota = quota;
    final adsRemoved = currentQuota?.adsRemoved ?? false;
    final hasPremier = currentQuota?.hasPremier ?? false;
    final unlimitedGames =
        (currentQuota?.unlimitedGames ?? false) && !hasPremier;
    final buttonEnabled =
        !isLoading &&
        !hasError &&
        !inProgress &&
        !adsRemoved &&
        (currentQuota?.canGrantReward ?? false);
    final freeGames = currentQuota?.freeGamesPerDay ?? 5;
    final rewardedGrants = currentQuota?.rewardedGrantsPerDay ?? 5;
    final maxGames = currentQuota?.maxGamesPerDay ?? 10;
    final gamesText = unlimitedGames
        ? t('Bez limita', 'Без лимита')
        : currentQuota == null
        ? '-/$maxGames'
        : '${currentQuota.gamesStartedToday}/$maxGames';
    final rewardText = adsRemoved
        ? t('Bez reklama', 'Без реклама')
        : currentQuota == null
        ? '-/$rewardedGrants'
        : '${currentQuota.rewardGrantsToday}/$rewardedGrants';
    final remainingText = unlimitedGames
        ? t('Bez limita', 'Без лимита')
        : currentQuota == null
        ? '-'
        : '${currentQuota.remainingGamesToday}';
    final description = hasPremier
        ? t(
            'Premier liga je aktivna. Standardne partije imaju dnevni limit $maxGames, a Premier kviz ima svoju rang listu.',
            'Премијер лига је активна. Стандардне партије имају дневни лимит $maxGames, а Премијер квиз има своју ранг листу.',
          )
        : unlimitedGames
        ? t(
            'Premier liga je aktivna. Partije su bez dnevnog limita i bez reklama.',
            'Премијер лига је активна. Партије су без дневног лимита и без реклама.',
          )
        : adsRemoved
        ? t(
            'Kviz Klub je aktivan. Imaš $freeGames dnevnih partija bez gledanja reklama.',
            'Квиз Клуб је активан. Имаш $freeGames дневних партија без гледања реклама.',
          )
        : t(
            'Dnevno imaš $freeGames osnovnih partija. Nagrađene reklame dodaju još najviše $rewardedGrants, ukupno $maxGames.',
            'Дневно имаш $freeGames основних партија. Награђене рекламе додају још највише $rewardedGrants, укупно $maxGames.',
          );

    return SettingsPanel(
      icon: Icons.card_giftcard_rounded,
      title: t('Bonus partije', 'Бонус партије'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.innerBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description,
                  style: TextStyle(
                    color: context.strongText,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    QuotaChip(
                      icon: Icons.sports_esports_rounded,
                      label: t('Partije', 'Партије'),
                      value: gamesText,
                    ),
                    QuotaChip(
                      icon: Icons.ondemand_video_rounded,
                      label: t('Reklame', 'Рекламе'),
                      value: rewardText,
                    ),
                    QuotaChip(
                      icon: Icons.play_circle_rounded,
                      label: t('Preostalo', 'Преостало'),
                      value: remainingText,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: buttonEnabled ? onWatchAd : null,
              icon: inProgress
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.play_circle_fill_rounded),
              label: Text(
                inProgress
                    ? t('Učitavanje reklame...', 'Учитавање рекламе...')
                    : adsRemoved
                    ? t('Reklame nisu potrebne', 'Рекламе нису потребне')
                    : t(
                        'Gledaj reklamu za 1 partiju',
                        'Гледај рекламу за 1 партију',
                      ),
              ),
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 10),
            Text(
              message!,
              style: TextStyle(
                color: context.mutedText,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                height: 1.3,
              ),
            ),
          ] else if (hasError) ...[
            const SizedBox(height: 10),
            Text(
              t(
                'Server trenutno ne vraća kvotu za partije.',
                'Сервер тренутно не враћа квоту за партије.',
              ),
              style: TextStyle(
                color: context.mutedText,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                height: 1.3,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
