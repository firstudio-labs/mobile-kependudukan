import 'dart:collection';

class CacheEntry<T> {
  final T value;
  final DateTime insertedAt;
  final Duration ttl;

  CacheEntry(
      {required this.value, required this.insertedAt, required this.ttl});

  bool get isExpired => DateTime.now().isAfter(insertedAt.add(ttl));
}

/// Cache sederhana in-memory dengan TTL per-entry.
class CacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  final Map<String, CacheEntry<dynamic>> _store = HashMap();

  T? get<T>(String key) {
    final entry = _store[key];
    if (entry == null) return null;
    if (entry.isExpired) {
      _store.remove(key);
      return null;
    }
    return entry.value as T;
  }

  void set<T>(String key, T value,
      {Duration ttl = const Duration(minutes: 15)}) {
    _store[key] =
        CacheEntry<T>(value: value, insertedAt: DateTime.now(), ttl: ttl);
  }

  void invalidate(String key) {
    _store.remove(key);
  }

  void clear() {
    _store.clear();
  }
}
