import 'package:flutter_test/flutter_test.dart';
import 'package:kviz/data/remote/ad_reward_quota.dart';

void main() {
  group('KvizAdQuotaSnapshot', () {
    test('parses server quota payload', () {
      final quota = KvizAdQuotaSnapshot.fromJson({
        'date_key': '2026-05-08',
        'free_games_per_day': 5,
        'rewarded_grants_per_day': 5,
        'max_games_per_day': 10,
        'games_started_today': 5,
        'reward_grants_today': 1,
        'used_rewarded_games': 0,
        'available_rewarded_games': 1,
        'daily_game_capacity': 6,
        'remaining_games_today': 1,
        'remaining_reward_grants_today': 4,
        'can_start_game': true,
        'can_grant_reward': true,
        'ads_removed': false,
        'unlimited_games': false,
        'has_no_ads': false,
        'has_premier': false,
        'standard_quota_modes': ['solo', 'kviz'],
        'unlimited_modes': [],
      });

      expect(quota.dateKey, '2026-05-08');
      expect(quota.freeGamesPerDay, 5);
      expect(quota.rewardedGrantsPerDay, 5);
      expect(quota.maxGamesPerDay, 10);
      expect(quota.gamesStartedToday, 5);
      expect(quota.rewardGrantsToday, 1);
      expect(quota.dailyGameCapacity, 6);
      expect(quota.remainingGamesToday, 1);
      expect(quota.canStartGame, isTrue);
      expect(quota.canGrantReward, isTrue);
      expect(quota.adsRemoved, isFalse);
      expect(quota.unlimitedGames, isFalse);
      expect(quota.shouldShowAds, isTrue);
      expect(quota.standardQuotaModes, ['solo', 'kviz']);
      expect(quota.unlimitedModes, isEmpty);
      expect(quota.modeUsesStandardQuota('solo'), isTrue);
    });

    test('keeps safe defaults for partial payloads', () {
      final quota = KvizAdQuotaSnapshot.fromJson({
        'games_started_today': '5',
        'can_start_game': 'false',
      });

      expect(quota.freeGamesPerDay, 5);
      expect(quota.rewardedGrantsPerDay, 5);
      expect(quota.maxGamesPerDay, 10);
      expect(quota.gamesStartedToday, 5);
      expect(quota.canStartGame, isFalse);
      expect(quota.adsRemoved, isFalse);
      expect(quota.hasPremier, isFalse);
      expect(quota.shouldShowAds, isTrue);
    });

    test('keeps old-backend quota mode fallback for non-premier modes', () {
      final quota = KvizAdQuotaSnapshot.fromJson({'has_premier': true});

      expect(quota.modeUsesStandardQuota('kviz'), isTrue);
      expect(quota.modeUsesStandardQuota('solo'), isTrue);
      expect(quota.modeUsesStandardQuota('premier'), isFalse);
    });

    test('parses subscription quota fields', () {
      final quota = KvizAdQuotaSnapshot.fromJson({
        'free_games_per_day': 10,
        'rewarded_grants_per_day': 0,
        'max_games_per_day': 10,
        'daily_game_capacity': 10,
        'remaining_games_today': 10,
        'can_start_game': true,
        'can_grant_reward': false,
        'ads_removed': true,
        'unlimited_games': true,
        'has_no_ads': true,
        'has_premier': true,
        'standard_quota_modes': ['kviz', 'kviz_plus'],
        'unlimited_modes': ['solo', 'premier', 'pitanja'],
      });

      expect(quota.freeGamesPerDay, 10);
      expect(quota.rewardedGrantsPerDay, 0);
      expect(quota.adsRemoved, isTrue);
      expect(quota.unlimitedGames, isTrue);
      expect(quota.hasNoAds, isTrue);
      expect(quota.hasPremier, isTrue);
      expect(quota.shouldShowAds, isFalse);
      expect(quota.standardQuotaModes, ['kviz', 'kviz_plus']);
      expect(quota.unlimitedModes, ['solo', 'premier', 'pitanja']);
      expect(quota.modeUsesStandardQuota('kviz'), isTrue);
      expect(quota.modeUsesStandardQuota('solo'), isFalse);
      expect(quota.modeUsesStandardQuota('premier'), isFalse);
    });

    test('hides ads when any no-ads entitlement is active', () {
      expect(
        KvizAdQuotaSnapshot.fromJson({'ads_removed': true}).shouldShowAds,
        isFalse,
      );
      expect(
        KvizAdQuotaSnapshot.fromJson({'has_no_ads': true}).shouldShowAds,
        isFalse,
      );
      expect(
        KvizAdQuotaSnapshot.fromJson({'has_premier': true}).shouldShowAds,
        isFalse,
      );
    });

    test('hides ads from nested subscription entitlements', () {
      final quota = KvizAdQuotaSnapshot.fromJson({
        'subscription_entitlements': {'ads_removed': true, 'has_no_ads': true},
      });

      expect(quota.adsRemoved, isTrue);
      expect(quota.hasNoAds, isTrue);
      expect(quota.shouldShowAds, isFalse);
    });
  });
}
