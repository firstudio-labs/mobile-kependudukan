import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:ladimas/core/constants/app_constants.dart';
import 'package:ladimas/core/error/exceptions.dart';
import 'auth_local_storage.dart';
import 'package:ladimas/core/services/cache_service.dart';
import 'package:ladimas/core/services/persistent_cache_service.dart';

class AdminPemerintahDesaApiService {
  final http.Client client;
  final AuthLocalStorage authLocalStorage;
  final CacheService _cache = CacheService();
  final Duration _ttl = const Duration(minutes: 10);
  final PersistentCacheService _persistent = PersistentCacheService();

  AdminPemerintahDesaApiService(
      {required this.client, required this.authLocalStorage});

  // Method untuk clear cache admin pemerintah desa
  Future<void> clearCache() async {
    try {
      // Clear in-memory cache
      _cache.clear();

      // Clear persistent cache
      await _persistent.clear();

      print('✅ Admin pemerintah desa cache cleared');
    } catch (e) {
      print('❌ Error clearing admin pemerintah desa cache: $e');
    }
  }

  Future<String> _getAuthToken() async {
    final token = await authLocalStorage.getStoredToken();
    if (token == null || token.isEmpty) {
      throw AuthException(message: 'Anda belum login atau sesi telah berakhir');
    }
    if (token.contains('|')) {
      final parts = token.split('|');
      if (parts.length > 1) return parts[1].trim();
    }
    return token.trim();
  }

  Future<Map<String, dynamic>> show({bool refreshStats = false}) async {
    try {
      const cacheKey = 'admin_pemdes_show';
      if (!refreshStats) {
        final cached = _cache.get<Map<String, dynamic>>(cacheKey);
        if (cached != null) return cached;
        final persisted =
            await _persistent.getJson<Map<String, dynamic>>(cacheKey);
        if (persisted != null) {
          _cache.set<Map<String, dynamic>>(cacheKey, persisted, ttl: _ttl);
          return persisted;
        }
      }

      final token = await _getAuthToken();
      final url = refreshStats
          ? '${AppConstants.authApiUrl}/user/admin/pemerintah-desa?refresh_stats=1'
          : '${AppConstants.authApiUrl}/user/admin/pemerintah-desa';
      final resp = await client.get(
        Uri.parse(url),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
          'X-API-Key': AppConstants.apiKey,
        },
      ).timeout(NetworkConstants.defaultTimeout, onTimeout: () {
        throw TimeoutException('Koneksi timeout. Coba lagi.');
      });
      if (resp.statusCode == 200) {
        final decoded = json.decode(resp.body);
        final result =
            (decoded is Map<String, dynamic>) ? decoded : {'data': decoded};
        _cache.set<Map<String, dynamic>>(cacheKey, result, ttl: _ttl);
        await _persistent.setJson(cacheKey, result, ttl: _ttl);
        return result;
      }
      if (resp.statusCode == 401) throw AuthException(message: 'Unauthorized');
      throw ServerException(message: 'Gagal memuat pemdes: ${resp.statusCode}');
    } on AuthException {
      rethrow;
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(message: 'Error pemdes admin: ${e.toString()}');
    }
  }
}
