import 'dart:async';

import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../data/billing/kviz_iap_service.dart';
import '../../../data/remote/analytics_service.dart';
import '../../../data/remote/quiz_subscription_status.dart';
import '../../../shared/utils.dart';
import '../../kviz_theme.dart';
import 'settings_panel.dart';

class IapSubscriptionSettingsCard extends StatefulWidget {
  const IapSubscriptionSettingsCard({
    super.key,
    required this.useCyrillic,
    required this.onLoadSubscriptions,
    required this.onVerifyPurchase,
    required this.onCreatePiCheckout,
    required this.onSubscriptionChanged,
  });

  final bool useCyrillic;
  final Future<KvizSubscriptionSnapshot> Function() onLoadSubscriptions;
  final Future<KvizSubscriptionSnapshot> Function(
    String productId,
    String purchaseToken,
  )
  onVerifyPurchase;
  final Future<String> Function(String productId) onCreatePiCheckout;
  final VoidCallback onSubscriptionChanged;

  @override
  State<IapSubscriptionSettingsCard> createState() =>
      _IapSubscriptionSettingsCardState();
}

class _IapSubscriptionSettingsCardState
    extends State<IapSubscriptionSettingsCard> {
  final KvizIapService _iapService = KvizIapService();
  StreamSubscription<KvizPurchaseUpdate>? _purchaseSubscription;
  bool _loading = true;
  bool _storeAvailable = false;
  bool _restoring = false;
  String? _pendingProductId;
  String? _openingPiProductId;
  String? _activeEntitlement;
  String? _message;
  Map<String, ProductDetails> _products = const <String, ProductDetails>{};

  String t(String latin, String cyr) => tr(widget.useCyrillic, latin, cyr);

  @override
  void initState() {
    super.initState();
    _iapService.start();
    _purchaseSubscription = _iapService.updates.listen(_handlePurchaseUpdate);
    unawaited(_loadProducts());
    unawaited(_loadServerStatus());
  }

  @override
  void dispose() {
    unawaited(_purchaseSubscription?.cancel());
    unawaited(_iapService.dispose());
    super.dispose();
  }

  Future<void> _loadServerStatus() async {
    try {
      final status = await widget.onLoadSubscriptions();
      if (!mounted) return;
      _applySubscriptionStatus(status, showMessage: false);
    } catch (_) {
      // Subscription status is helpful, but settings must remain usable offline.
    }
  }

  Future<void> _loadProducts() async {
    final productIds = kvizIapProductIds
        .where((id) => id.trim().isNotEmpty)
        .toSet();
    if (productIds.isEmpty) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _storeAvailable = false;
        _message = t(
          'Pretplate čekaju Play Console ID-jeve.',
          'Претплате чекају Play Console ID-јеве.',
        );
      });
      return;
    }

    try {
      final available = await _iapService.isAvailable();
      if (!mounted) return;
      if (!available) {
        setState(() {
          _loading = false;
          _storeAvailable = false;
          _message = t(
            'Play kupovina nije dostupna na ovom uređaju.',
            'Play куповина није доступна на овом уређају.',
          );
        });
        return;
      }

      final response = await _iapService.queryProducts(productIds);
      if (!mounted) return;
      final queryMessage = _productQueryMessage(response, productIds);
      setState(() {
        _loading = false;
        _storeAvailable = true;
        _products = {
          for (final product in response.productDetails) product.id: product,
        };
        _message = queryMessage;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _storeAvailable = false;
        _message = t(
          'Pretplate trenutno nisu dostupne. Greška: $error',
          'Претплате тренутно нису доступне. Грешка: $error',
        );
      });
    }
  }

  String? _productQueryMessage(
    ProductDetailsResponse response,
    Set<String> requestedIds,
  ) {
    if (response.productDetails.isEmpty) {
      final notFound = response.notFoundIDs.isEmpty
          ? requestedIds.join(', ')
          : response.notFoundIDs.join(', ');
      final error = response.error;
      final errorText = error == null
          ? ''
          : ' ${t('Greška:', 'Грешка:')} ${error.code} ${error.message}';

      return t(
        'Play nije vratio pretplate. Traženo: ${requestedIds.join(', ')}. Nije pronađeno: $notFound.$errorText',
        'Play није вратио претплате. Тражено: ${requestedIds.join(', ')}. Није пронађено: $notFound.$errorText',
      );
    }

    if (response.notFoundIDs.isNotEmpty) {
      return t(
        'Neke pretplate nisu pronađene: ${response.notFoundIDs.join(', ')}.',
        'Неке претплате нису пронађене: ${response.notFoundIDs.join(', ')}.',
      );
    }

    return null;
  }

  void _handlePurchaseUpdate(KvizPurchaseUpdate update) {
    if (!mounted) return;

    if (update.status == PurchaseStatus.pending) {
      setState(() {
        _pendingProductId = update.productId;
        _message = t('Kupovina je u obradi.', 'Куповина је у обради.');
      });
      return;
    }

    if (update.status == PurchaseStatus.purchased ||
        update.status == PurchaseStatus.restored) {
      final token = update.purchaseToken?.trim();
      if (token == null || token.isEmpty) {
        setState(() {
          _pendingProductId = null;
          _restoring = false;
          _message = t(
            'Play kupovina nema token za proveru. Pokušaj restore kasnije.',
            'Play куповина нема токен за проверу. Покушај restore касније.',
          );
        });
        return;
      }

      setState(() {
        _pendingProductId = update.productId;
        _message = t(
          'Proveravamo kupovinu na serveru...',
          'Проверавамо куповину на серверу...',
        );
      });
      unawaited(_verifyPurchase(update.productId, token));
      return;
    }

    setState(() {
      _pendingProductId = null;
      _restoring = false;
      if (update.status == PurchaseStatus.error) {
        _message = update.errorMessage?.trim().isNotEmpty == true
            ? update.errorMessage
            : t(
                'Kupovina nije završena. Pokušaj ponovo kasnije.',
                'Куповина није завршена. Покушај поново касније.',
              );
      } else {
        _message = t('Kupovina nije završena.', 'Куповина није завршена.');
      }
    });
  }

  Future<void> _verifyPurchase(String productId, String purchaseToken) async {
    try {
      final status = await widget.onVerifyPurchase(productId, purchaseToken);
      if (!mounted) return;
      widget.onSubscriptionChanged();
      _applySubscriptionStatus(status, showMessage: true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _message = t(
          'Kupovina nije potvrđena na serveru. Beneficije nisu aktivirane.',
          'Куповина није потврђена на серверу. Бенефиције нису активиране.',
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _pendingProductId = null;
          _restoring = false;
        });
      }
    }
  }

  void _applySubscriptionStatus(
    KvizSubscriptionSnapshot status, {
    required bool showMessage,
  }) {
    final entitlement = status.hasPremier
        ? 'premier'
        : status.hasNoAds
        ? 'no_ads'
        : null;

    setState(() {
      _activeEntitlement = entitlement;
      if (showMessage) {
        _message = entitlement == null
            ? t(
                'Pretplata nije aktivna posle provere.',
                'Претплата није активна после провере.',
              )
            : t(
                'Aktivna pretplata: ${_activeEntitlementLabel(entitlement)}.',
                'Активна претплата: ${_activeEntitlementLabel(entitlement)}.',
              );
      }
    });
  }

  String _activeEntitlementLabel(String entitlement) {
    if (entitlement == 'premier') {
      return t('Premier liga', 'Премијер лига');
    }
    return t('Kviz Klub', 'Квиз Клуб');
  }

  Future<void> _buy(_SubscriptionPlan plan, ProductDetails product) async {
    if (_pendingProductId != null) {
      return;
    }

    KvizAnalytics.uiAction(
      screen: 'settings',
      area: 'iap',
      target: 'buy_${plan.analyticsKey}',
    );
    setState(() {
      _pendingProductId = product.id;
      _message = null;
    });

    try {
      final started = await _iapService.buySubscription(product);
      if (!mounted) return;
      if (!started) {
        setState(() {
          _pendingProductId = null;
          _message = t('Kupovina nije pokrenuta.', 'Куповина није покренута.');
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _pendingProductId = null;
        _message = t(
          'Kupovina trenutno nije dostupna.',
          'Куповина тренутно није доступна.',
        );
      });
    }
  }

  Future<void> _openPiCheckout(_SubscriptionPlan plan) async {
    if (_pendingProductId != null ||
        _restoring ||
        _openingPiProductId != null) {
      return;
    }

    KvizAnalytics.uiAction(
      screen: 'settings',
      area: 'iap',
      target: 'pi_checkout_${plan.analyticsKey}',
    );
    setState(() {
      _openingPiProductId = plan.productId;
      _message = t(
        'Otvaramo Pi checkout. Najbolje radi u Pi Browser-u.',
        'Отварамо Pi checkout. Најбоље ради у Pi Browser-у.',
      );
    });

    try {
      final checkoutUrl = (await widget.onCreatePiCheckout(
        plan.productId,
      )).trim();
      final uri = Uri.tryParse(checkoutUrl);
      if (uri == null || !uri.hasScheme) {
        throw const FormatException('Invalid Pi checkout URL.');
      }

      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!mounted) return;
      setState(() {
        _message = launched
            ? t(
                'Pi checkout je otvoren. Posle plaćanja vrati se ovde i osveži status.',
                'Pi checkout је отворен. После плаћања врати се овде и освежи статус.',
              )
            : t(
                'Ne mogu da otvorim Pi checkout. Instaliraj/otvori Pi Browser i pokušaj ponovo.',
                'Не могу да отворим Pi checkout. Инсталирај/отвори Pi Browser и покушај поново.',
              );
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _message = t(
          'Pi plaćanje trenutno nije dostupno. Pokušaj ponovo kasnije.',
          'Pi плаћање тренутно није доступно. Покушај поново касније.',
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _openingPiProductId = null;
        });
      }
    }
  }

  Future<void> _restorePurchases() async {
    if (!_storeAvailable ||
        _pendingProductId != null ||
        _restoring ||
        _openingPiProductId != null) {
      return;
    }

    KvizAnalytics.uiAction(screen: 'settings', area: 'iap', target: 'restore');
    setState(() {
      _restoring = true;
      _message = null;
    });

    try {
      await _iapService.restorePurchases();
      if (!mounted) return;
      setState(() {
        _restoring = false;
        _message ??= t(
          'Proverili smo postojeće kupovine.',
          'Проверили смо постојеће куповине.',
        );
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _restoring = false;
        _message = t(
          'Obnova kupovine trenutno nije dostupna.',
          'Обнова куповине тренутно није доступна.',
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsPanel(
      icon: Icons.workspace_premium_rounded,
      title: t('Podrži Kviz', 'Подржи Квиз'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            t(
              'Kviz ostaje besplatan. Pretplate su podrška za servere, pitanja i mirnije igranje.',
              'Квиз остаје бесплатан. Претплате су подршка за сервере, питања и мирније играње.',
            ),
            style: TextStyle(
              color: context.mutedText,
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          if (_activeEntitlement != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF00897B).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF00897B).withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.verified_rounded,
                    color: Color(0xFF00897B),
                    size: 19,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      t(
                        'Aktivno: ${_activeEntitlementLabel(_activeEntitlement!)}',
                        'Активно: ${_activeEntitlementLabel(_activeEntitlement!)}',
                      ),
                      style: TextStyle(
                        color: context.strongText,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          for (final plan in _plans) ...[
            _SubscriptionPlanCard(
              plan: plan,
              product: _products[plan.productId],
              useCyrillic: widget.useCyrillic,
              loading: _loading,
              storeAvailable: _storeAvailable,
              pending: _pendingProductId == plan.productId,
              openingPi: _openingPiProductId == plan.productId,
              busy:
                  _pendingProductId != null ||
                  _restoring ||
                  _openingPiProductId != null,
              onBuy: _buy,
              onPiCheckout: _openPiCheckout,
            ),
            if (plan != _plans.last) const SizedBox(height: 10),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed:
                _storeAvailable &&
                    _pendingProductId == null &&
                    !_restoring &&
                    _openingPiProductId == null
                ? _restorePurchases
                : null,
            icon: _restoring
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.restore_rounded),
            label: Text(
              _restoring
                  ? t('Provera...', 'Провера...')
                  : t('Vrati kupovinu', 'Врати куповину'),
            ),
          ),
          if (_message != null) ...[
            const SizedBox(height: 10),
            Text(
              _message!,
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

class _SubscriptionPlanCard extends StatelessWidget {
  const _SubscriptionPlanCard({
    required this.plan,
    required this.product,
    required this.useCyrillic,
    required this.loading,
    required this.storeAvailable,
    required this.pending,
    required this.openingPi,
    required this.busy,
    required this.onBuy,
    required this.onPiCheckout,
  });

  final _SubscriptionPlan plan;
  final ProductDetails? product;
  final bool useCyrillic;
  final bool loading;
  final bool storeAvailable;
  final bool pending;
  final bool openingPi;
  final bool busy;
  final Future<void> Function(_SubscriptionPlan plan, ProductDetails product)
  onBuy;
  final Future<void> Function(_SubscriptionPlan plan) onPiCheckout;

  String t(String latin, String cyr) => tr(useCyrillic, latin, cyr);

  @override
  Widget build(BuildContext context) {
    final details = product;
    final price = details?.price ?? plan.fallbackPrice;
    final title = useCyrillic ? plan.cyrTitle : plan.latinTitle;
    final subtitle = useCyrillic ? plan.cyrSubtitle : plan.latinSubtitle;
    final benefits = useCyrillic ? plan.cyrBenefits : plan.latinBenefits;
    final canBuy = storeAvailable && !loading && details != null && !busy;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.innerBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: plan.color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: plan.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(plan.icon, color: plan.color, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: context.strongText,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: context.mutedText,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                price,
                style: TextStyle(
                  color: plan.color,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final benefit in benefits)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle_rounded, color: plan.color, size: 16),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      benefit,
                      style: TextStyle(
                        color: context.strongText,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SizedBox(
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: canBuy ? () => onBuy(plan, details) : null,
                  icon: pending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(plan.buttonIcon),
                  label: Text(
                    pending
                        ? t('Obrada...', 'Обрада...')
                        : details == null
                        ? t('Čeka Play Console', 'Чека Play Console')
                        : plan.buttonLabel(useCyrillic),
                  ),
                ),
              ),
              SizedBox(
                height: 46,
                child: OutlinedButton.icon(
                  onPressed: busy ? null : () => onPiCheckout(plan),
                  icon: openingPi
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: plan.color,
                          ),
                        )
                      : const Icon(Icons.public_rounded),
                  label: Text(
                    openingPi
                        ? t('Otvaranje Pi...', 'Отварање Pi...')
                        : t('Plati Pi', 'Плати Pi'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SubscriptionPlan {
  const _SubscriptionPlan({
    required this.analyticsKey,
    required this.productId,
    required this.icon,
    required this.buttonIcon,
    required this.color,
    required this.latinTitle,
    required this.cyrTitle,
    required this.latinSubtitle,
    required this.cyrSubtitle,
    required this.latinBenefits,
    required this.cyrBenefits,
    required this.latinButton,
    required this.cyrButton,
    required this.fallbackPrice,
  });

  final String analyticsKey;
  final String productId;
  final IconData icon;
  final IconData buttonIcon;
  final Color color;
  final String latinTitle;
  final String cyrTitle;
  final String latinSubtitle;
  final String cyrSubtitle;
  final List<String> latinBenefits;
  final List<String> cyrBenefits;
  final String latinButton;
  final String cyrButton;
  final String fallbackPrice;

  String buttonLabel(bool useCyrillic) => useCyrillic ? cyrButton : latinButton;
}

const _plans = <_SubscriptionPlan>[
  _SubscriptionPlan(
    analyticsKey: 'no_ads',
    productId: kvizNoAdsMonthlyProductId,
    icon: Icons.favorite_rounded,
    buttonIcon: Icons.favorite_rounded,
    color: Color(0xFF00897B),
    latinTitle: 'Kviz Klub',
    cyrTitle: 'Квиз Клуб',
    latinSubtitle: '10 dnevnih partija bez gledanja reklama',
    cyrSubtitle: '10 дневних партија без гледања реклама',
    latinBenefits: <String>[
      'Osnovnih 10 partija bez rewarded reklama',
      'Podrška za servere i nova pitanja',
      'Manje prekida, isti fer kviz za sve',
    ],
    cyrBenefits: <String>[
      'Основних 10 партија без rewarded реклама',
      'Подршка за сервере и нова питања',
      'Мање прекида, исти фер квиз за све',
    ],
    latinButton: 'Podrži Kviz Klub',
    cyrButton: 'Подржи Квиз Клуб',
    fallbackPrice: '1 EUR',
  ),
  _SubscriptionPlan(
    analyticsKey: 'premier',
    productId: kvizPremierMonthlyProductId,
    icon: Icons.emoji_events_rounded,
    buttonIcon: Icons.workspace_premium_rounded,
    color: Color(0xFFE0A800),
    latinTitle: 'Premier liga',
    cyrTitle: 'Премијер лига',
    latinSubtitle: 'Premier kviz, posebna rang lista i bez reklama',
    cyrSubtitle: 'Премијер квиз, посебна ранг листа и без реклама',
    latinBenefits: <String>[
      'Premier kviz sa posebnom rang listom',
      'Standardna rang lista ostaje fer limit 10 partija',
      'Uključuje beneficije Kviz Kluba',
    ],
    cyrBenefits: <String>[
      'Премијер квиз са посебном ранг листом',
      'Стандардна ранг листа остаје фер лимит 10 партија',
      'Укључује бенефиције Квиз Клуба',
    ],
    latinButton: 'Uđi u Premier',
    cyrButton: 'Уђи у Премијер',
    fallbackPrice: '5 EUR',
  ),
];
