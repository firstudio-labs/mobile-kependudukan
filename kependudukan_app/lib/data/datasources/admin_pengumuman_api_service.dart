import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:ladimas/core/constants/app_constants.dart';
import 'package:ladimas/core/error/exceptions.dart';
import 'auth_local_storage.dart';
import '../models/pengumuman_model.dart';
import 'package:ladimas/core/services/cache_service.dart';
import 'package:ladimas/core/services/persistent_cache_service.dart';

class AdminPengumumanApiService {
  final http.Client client;
  final AuthLocalStorage authLocalStorage;
  final CacheService _cache = CacheService();
  final Duration _ttl = const Duration(minutes: 5);
  final PersistentCacheService _persistent = PersistentCacheService();

  AdminPengumumanApiService(
      {required this.client, required this.authLocalStorage});

  // Method untuk clear cache admin pengumuman
  Future<void> clearCache() async {
    try {
      // Clear in-memory cache
      _cache.clear();

      // Clear persistent cache
      await _persistent.clear();

      print('✅ Admin pengumuman cache cleared');
    } catch (e) {
      print('❌ Error clearing admin pengumuman cache: $e');
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

  Future<List<PengumumanModel>> list({int perPage = 5, String? search}) async {
    try {
      final key = 'admin_pengumuman_list_${perPage}_${search ?? ''}';
      final cached = _cache.get<List<PengumumanModel>>(key);
      if (cached != null) return cached;
      final persisted = await _persistent.getJson<List<dynamic>>(key);
      if (persisted != null) {
        final restored = persisted
            .whereType<Map<String, dynamic>>()
            .map((e) => PengumumanModel.fromJson(e))
            .toList();
        _cache.set<List<PengumumanModel>>(key, restored, ttl: _ttl);
        return restored;
      }

      final token = await _getAuthToken();
      final buf = StringBuffer(
          '${AppConstants.authApiUrl}/user/admin/pengumuman?per_page=$perPage');
      if (search != null && search.isNotEmpty) {
        buf.write('&search=${Uri.encodeQueryComponent(search)}');
      }
      final resp = await client.get(
        Uri.parse(buf.toString()),
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
        final data = decoded['data'];
        final items = (data is Map<String, dynamic>)
            ? data['data']
            : (data is List ? data : []);
        if (items is List) {
          final result = items
              .whereType<Map<String, dynamic>>()
              .map((e) => PengumumanModel.fromJson(e))
              .toList();
          _cache.set<List<PengumumanModel>>(key, result, ttl: _ttl);
          await _persistent.setJson(
            key,
            result.map((e) => e.toJson()).toList(),
            ttl: _ttl,
          );
          return result;
        }
        return [];
      }
      if (resp.statusCode == 401) throw AuthException(message: 'Unauthorized');
      if (resp.statusCode == 404) return [];
      throw ServerException(
          message: 'Gagal memuat pengumuman: ${resp.statusCode}');
    } on AuthException {
      rethrow;
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(message: 'Error pengumuman admin: ${e.toString()}');
    }
  }
}
