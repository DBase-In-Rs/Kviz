import 'dart:async';

/// Lightweight in-memory cache for quiz API data.
/// Cache entries auto-expire after [ttl]. Used for stats, leaderboard, season data.
class KvizCache {
  KvizCache({this.defaultTtl = const Duration(seconds: 30)});

  final Duration defaultTtl;
  final Map<String, _CacheEntry> _store = <String, _CacheEntry>{};

  /// Returns cached value if fresh, otherwise null.
  T? get<T>(String key) {
    final entry = _store[key];
    if (entry == null) return null;
    if (entry.isExpired) {
      _store.remove(key);
      return null;
    }
    return entry.value as T?;
  }

  /// Stores a value with optional custom [ttl].
  void set(String key, Object? value, {Duration? ttl}) {
    _store[key] = _CacheEntry(
      value: value,
      expiresAt: DateTime.now().add(ttl ?? defaultTtl),
    );
  }

  /// Returns cached value if fresh; otherwise runs [loader], caches result, returns it.
  Future<T> fetch<T>(
    String key,
    Future<T> Function() loader, {
    Duration? ttl,
  }) async {
    final cached = get<T>(key);
    if (cached != null) return cached;

    final value = await loader();
    set(key, value, ttl: ttl);
    return value;
  }

  /// Removes a single entry.
  void invalidate(String key) {
    _store.remove(key);
  }

  /// Removes all entries matching [prefix].
  void invalidateByPrefix(String prefix) {
    _store.removeWhere((key, _) => key.startsWith(prefix));
  }

  /// Clears the entire cache.
  void clear() {
    _store.clear();
  }

  /// Number of cached entries (including expired ones not yet cleaned).
  int get length => _store.length;
}

class _CacheEntry {
  const _CacheEntry({required this.value, required this.expiresAt});

  final Object? value;
  final DateTime expiresAt;

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}
