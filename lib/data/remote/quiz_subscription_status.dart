class KvizSubscriptionSnapshot {
  const KvizSubscriptionSnapshot({
    required this.hasNoAds,
    required this.hasPremier,
    required this.adsRemoved,
    required this.unlimitedGames,
    required this.subscriptions,
  });

  factory KvizSubscriptionSnapshot.fromJson(Map<String, dynamic> json) {
    final entitlements = _asMap(json['entitlements']) ?? json;
    final rawSubscriptions = entitlements['subscriptions'];

    return KvizSubscriptionSnapshot(
      hasNoAds: _asBool(entitlements['has_no_ads']),
      hasPremier: _asBool(entitlements['has_premier']),
      adsRemoved: _asBool(entitlements['ads_removed']),
      unlimitedGames: _asBool(entitlements['unlimited_games']),
      subscriptions: rawSubscriptions is List
          ? rawSubscriptions
                .whereType<Map>()
                .map(
                  (item) => KvizSubscriptionDetails.fromJson(
                    item.map((key, dynamic value) => MapEntry('$key', value)),
                  ),
                )
                .toList(growable: false)
          : const <KvizSubscriptionDetails>[],
    );
  }

  final bool hasNoAds;
  final bool hasPremier;
  final bool adsRemoved;
  final bool unlimitedGames;
  final List<KvizSubscriptionDetails> subscriptions;

  String get strongestLabel {
    if (hasPremier) return 'Premier liga';
    if (hasNoAds) return 'Kviz Klub';
    return '';
  }
}

class KvizSubscriptionDetails {
  const KvizSubscriptionDetails({
    required this.productId,
    required this.entitlement,
    required this.status,
    required this.active,
    this.expiresAt,
  });

  factory KvizSubscriptionDetails.fromJson(Map<String, dynamic> json) {
    return KvizSubscriptionDetails(
      productId: json['product_id']?.toString() ?? '',
      entitlement: json['entitlement']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      active: _asBool(json['active']),
      expiresAt: json['expires_at']?.toString(),
    );
  }

  final String productId;
  final String entitlement;
  final String status;
  final bool active;
  final String? expiresAt;
}

Map<String, dynamic>? _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, dynamic data) => MapEntry('$key', data));
  }
  return null;
}

bool _asBool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    return value.toLowerCase() == 'true' || value == '1';
  }
  return false;
}
