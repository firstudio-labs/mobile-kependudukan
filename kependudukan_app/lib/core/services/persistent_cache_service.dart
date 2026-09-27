import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class PersistentCacheService {
  static final PersistentCacheService _instance =
      PersistentCacheService._internal();
  factory PersistentCacheService() => _instance;
  PersistentCacheService._internal();

  static const String _prefix = 'persist_cache:';

  String _buildKey(String key) => '$_prefix$key';

  Future<void> setJson(String key, Object value,
      {Duration ttl = const Duration(minutes: 30)}) async {
    final prefs = await SharedPreferences.getInstance();
    final record = {
      'v': value,
      'ts': DateTime.now().millisecondsSinceEpoch,
      'ttlMs': ttl.inMilliseconds,
    };
    await prefs.setString(_buildKey(key), jsonEncode(record));
  }

  Future<T?> getJson<T>(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_buildKey(key));
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final int ts = decoded['ts'] as int? ?? 0;
      final int ttlMs = decoded['ttlMs'] as int? ?? 0;
      final expired = DateTime.now().millisecondsSinceEpoch - ts > ttlMs;
      if (expired) {
        await prefs.remove(_buildKey(key));
        return null;
      }
      return decoded['v'] as T?;
    } catch (_) {
      await prefs.remove(_buildKey(key));
      return null;
    }
  }

  Future<void> invalidate(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_buildKey(key));
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    final cacheKeys = keys.where((key) => key.startsWith(_prefix));
    for (final key in cacheKeys) {
      await prefs.remove(key);
    }
  }
}
