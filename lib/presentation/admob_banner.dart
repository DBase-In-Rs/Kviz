import 'dart:async';

import 'package:flutter/foundation.dart'
    show TargetPlatform, debugPrint, defaultTargetPlatform, kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../data/remote/analytics_service.dart';

class KvizAdMob {
  KvizAdMob._();

  static const androidAppId = 'ca-app-pub-5116758828202889~3118136439';
  static const androidBannerAdUnitId = 'ca-app-pub-5116758828202889/3080047379';
  static const androidInterstitialAdUnitId =
      'ca-app-pub-5116758828202889/4759355319';
  static const androidRewardedAdUnitId =
      'ca-app-pub-5116758828202889/5407661968';

  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static final Future<InitializationStatus?> initialization = _initialize();

  static Future<InitializationStatus?> _initialize() async {
    if (!isSupported) {
      return null;
    }

    try {
      await MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(
          maxAdContentRating: MaxAdContentRating.g,
          ageRestrictedTreatment: AgeRestrictedTreatment.child,
        ),
      );
      return await MobileAds.instance.initialize();
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Google Mobile Ads nije pokrenut: $error');
      }
      return null;
    }
  }
}

class KvizAdMobFullScreenAds {
  const KvizAdMobFullScreenAds();

  static const _androidInterstitialAdUnitId = String.fromEnvironment(
    'KVIZ_ADMOB_ANDROID_INTERSTITIAL_ID',
    defaultValue: KvizAdMob.androidInterstitialAdUnitId,
  );
  static const _androidRewardedAdUnitId = String.fromEnvironment(
    'KVIZ_ADMOB_ANDROID_REWARDED_ID',
    defaultValue: KvizAdMob.androidRewardedAdUnitId,
  );

  Future<bool> showInterstitial({required String placement}) async {
    if (!KvizAdMob.isSupported || _androidInterstitialAdUnitId.isEmpty) {
      KvizAnalytics.event(
        'ad_interstitial_unavailable',
        parameters: <String, Object?>{'placement': placement},
      );
      return false;
    }

    await KvizAdMob.initialization;

    final completer = Completer<bool>();
    InterstitialAd? loadedAd;

    void complete(bool value) {
      if (!completer.isCompleted) {
        completer.complete(value);
      }
    }

    try {
      await InterstitialAd.load(
        adUnitId: _androidInterstitialAdUnitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            loadedAd = ad;
            KvizAnalytics.event(
              'ad_interstitial_loaded',
              parameters: <String, Object?>{'placement': placement},
            );
            ad.fullScreenContentCallback =
                FullScreenContentCallback<InterstitialAd>(
                  onAdShowedFullScreenContent: (_) {
                    KvizAnalytics.event(
                      'ad_interstitial_show',
                      parameters: <String, Object?>{'placement': placement},
                    );
                  },
                  onAdDismissedFullScreenContent: (ad) {
                    ad.dispose();
                    KvizAnalytics.event(
                      'ad_interstitial_dismiss',
                      parameters: <String, Object?>{'placement': placement},
                    );
                    complete(true);
                  },
                  onAdFailedToShowFullScreenContent: (ad, error) {
                    ad.dispose();
                    KvizAnalytics.event(
                      'ad_interstitial_show_failed',
                      parameters: <String, Object?>{
                        'placement': placement,
                        'error_code': error.code,
                      },
                    );
                    complete(false);
                  },
                );
            unawaited(
              ad.show().catchError((Object error) {
                ad.dispose();
                complete(false);
              }),
            );
          },
          onAdFailedToLoad: (error) {
            KvizAnalytics.event(
              'ad_interstitial_load_failed',
              parameters: <String, Object?>{
                'placement': placement,
                'error_code': error.code,
              },
            );
            complete(false);
          },
        ),
      );
    } catch (error) {
      if (kDebugMode) {
        debugPrint('AdMob interstitial nije ucitan: $error');
      }
      complete(false);
    }

    return completer.future.timeout(
      const Duration(seconds: 45),
      onTimeout: () {
        loadedAd?.dispose();
        return false;
      },
    );
  }

  Future<bool> showRewarded({required String placement}) async {
    if (!KvizAdMob.isSupported || _androidRewardedAdUnitId.isEmpty) {
      KvizAnalytics.event(
        'ad_rewarded_unavailable',
        parameters: <String, Object?>{'placement': placement},
      );
      return false;
    }

    await KvizAdMob.initialization;

    final completer = Completer<bool>();
    RewardedAd? loadedAd;
    var earnedReward = false;

    void complete(bool value) {
      if (!completer.isCompleted) {
        completer.complete(value);
      }
    }

    try {
      await RewardedAd.load(
        adUnitId: _androidRewardedAdUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            loadedAd = ad;
            KvizAnalytics.event(
              'ad_rewarded_loaded',
              parameters: <String, Object?>{'placement': placement},
            );
            ad.fullScreenContentCallback =
                FullScreenContentCallback<RewardedAd>(
                  onAdShowedFullScreenContent: (_) {
                    KvizAnalytics.event(
                      'ad_rewarded_show',
                      parameters: <String, Object?>{'placement': placement},
                    );
                  },
                  onAdDismissedFullScreenContent: (ad) {
                    ad.dispose();
                    KvizAnalytics.event(
                      'ad_rewarded_dismiss',
                      parameters: <String, Object?>{
                        'placement': placement,
                        'earned_reward': earnedReward,
                      },
                    );
                    complete(earnedReward);
                  },
                  onAdFailedToShowFullScreenContent: (ad, error) {
                    ad.dispose();
                    KvizAnalytics.event(
                      'ad_rewarded_show_failed',
                      parameters: <String, Object?>{
                        'placement': placement,
                        'error_code': error.code,
                      },
                    );
                    complete(false);
                  },
                );
            unawaited(
              ad
                  .show(
                    onUserEarnedReward: (_, reward) {
                      earnedReward = true;
                      KvizAnalytics.event(
                        'ad_rewarded_earned',
                        parameters: <String, Object?>{
                          'placement': placement,
                          'reward_type': reward.type,
                          'reward_amount': reward.amount,
                        },
                      );
                    },
                  )
                  .catchError((Object error) {
                    ad.dispose();
                    complete(false);
                  }),
            );
          },
          onAdFailedToLoad: (error) {
            KvizAnalytics.event(
              'ad_rewarded_load_failed',
              parameters: <String, Object?>{
                'placement': placement,
                'error_code': error.code,
              },
            );
            complete(false);
          },
        ),
      );
    } catch (error) {
      if (kDebugMode) {
        debugPrint('AdMob rewarded nije ucitan: $error');
      }
      complete(false);
    }

    return completer.future.timeout(
      const Duration(seconds: 60),
      onTimeout: () {
        loadedAd?.dispose();
        return false;
      },
    );
  }
}

class KvizAdMobBanner extends StatefulWidget {
  const KvizAdMobBanner({super.key});

  @override
  State<KvizAdMobBanner> createState() => _KvizAdMobBannerState();
}

class _KvizAdMobBannerState extends State<KvizAdMobBanner> {
  static const _androidBannerAdUnitId = String.fromEnvironment(
    'KVIZ_ADMOB_ANDROID_BANNER_ID',
    defaultValue: KvizAdMob.androidBannerAdUnitId,
  );

  BannerAd? _bannerAd;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadBanner());
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  Future<void> _loadBanner() async {
    if (!KvizAdMob.isSupported || _androidBannerAdUnitId.isEmpty) {
      return;
    }

    await KvizAdMob.initialization;
    if (!mounted) {
      return;
    }

    final bannerAd = BannerAd(
      adUnitId: _androidBannerAdUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          KvizAnalytics.adBannerLoaded(adUnitId: _androidBannerAdUnitId);
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() {
            _bannerAd = ad as BannerAd;
            _isLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          KvizAnalytics.adBannerFailed(
            adUnitId: _androidBannerAdUnitId,
            code: error.code,
          );
          if (kDebugMode) {
            debugPrint('AdMob banner nije ucitan: $error');
          }
        },
      ),
    );

    await bannerAd.load();
  }

  @override
  Widget build(BuildContext context) {
    final bannerAd = _bannerAd;
    if (!_isLoaded || bannerAd == null) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        bottom: false,
        child: SizedBox(
          height: bannerAd.size.height.toDouble(),
          child: Center(
            child: SizedBox(
              width: bannerAd.size.width.toDouble(),
              height: bannerAd.size.height.toDouble(),
              child: AdWidget(ad: bannerAd),
            ),
          ),
        ),
      ),
    );
  }
}
