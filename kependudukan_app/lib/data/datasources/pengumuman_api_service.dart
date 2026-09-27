import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:ladimas/core/constants/app_constants.dart';
import 'package:ladimas/core/error/exceptions.dart';
import 'auth_local_storage.dart';
import '../models/pengumuman_model.dart';
import 'package:ladimas/core/services/cache_service.dart';
import 'package:ladimas/core/services/persistent_cache_service.dart';

class PengumumanApiService {
  final http.Client client;
  final AuthLocalStorage authLocalStorage;
  final CacheService _cache = CacheService();
  final Duration _ttl = const Duration(minutes: 1); // Kurangi dari 5 menit ke 1 menit
  final PersistentCacheService _persistent = PersistentCacheService();

  PengumumanApiService({
    required this.client,
    required this.authLocalStorage,
  });

  // Method untuk clear cache pengumuman
  Future<void> clearCache() async {
    try {
      // Clear in-memory cache
      _cache.clear();

      // Clear persistent cache
      await _persistent.clear();

      print('✅ Pengumuman cache cleared');
    } catch (e) {
      print('❌ Error clearing pengumuman cache: $e');
    }
  }

  Future<String> _getAuthToken() async {
    final token = await authLocalStorage.getStoredToken();
    if (token == null || token.isEmpty) {
      throw AuthException(message: 'Anda belum login atau sesi telah berakhir');
    }
    if (token.contains('|')) {
      final parts = token.split('|');
      if (parts.length > 1) {
        return parts[1].trim();
      }
    }
    return token.trim();
  }

  Future<List<PengumumanModel>> getPengumumanList(
      {int? perPage, String? search}) async {
    try {
      final key = 'pengumuman_list_${perPage ?? 0}_${search ?? ''}';
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
      final StringBuffer url = StringBuffer(
          '${AppConstants.authApiUrl}/user/pengumuman?format=json');
      if (perPage != null) {
        url.write('&per_page=$perPage');
      }
      if (search != null && search.isNotEmpty) {
        url.write('&search=${Uri.encodeQueryComponent(search)}');
      }

      final response = await client.get(
        Uri.parse(url.toString()),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
          'X-API-Key': AppConstants.apiKey,
        },
      ).timeout(
        NetworkConstants.defaultTimeout,
        onTimeout: () {
          throw TimeoutException('Koneksi timeout. Silakan coba lagi.');
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);
        if (jsonResponse['status'] == 'success') {
          final dynamic payload = jsonResponse['data'];
          final List<dynamic> items = payload is List
              ? payload
              : (payload is Map<String, dynamic> && payload['items'] is List)
                  ? payload['items']
                  : <dynamic>[];
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
        } else {
          throw ServerException(
              message: jsonResponse['message'] ?? 'Gagal memuat pengumuman');
        }
      } else if (response.statusCode == 401) {
        throw AuthException(message: 'Tidak diizinkan: Token tidak valid');
      } else if (response.statusCode == 404) {
        return [];
      } else if (response.statusCode >= 500) {
        throw ServerException(
            message: 'Server sedang bermasalah. Silakan coba lagi nanti');
      } else {
        throw ServerException(
            message: 'Gagal memuat pengumuman: ${response.statusCode}');
      }
    } on TimeoutException {
      rethrow;
    } on AuthException {
      rethrow;
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(
          message: 'Gagal memuat pengumuman: ${e.toString()}');
    }
  }

  Future<PengumumanModel> getPengumumanDetail({required int id}) async {
    try {
      final token = await _getAuthToken();
      final String url =
          '${AppConstants.authApiUrl}/user/pengumuman/$id?format=json';
      final response = await client.get(
        Uri.parse(url),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
          'X-API-Key': AppConstants.apiKey,
        },
      ).timeout(
        NetworkConstants.defaultTimeout,
        onTimeout: () {
          throw TimeoutException('Koneksi timeout. Silakan coba lagi.');
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);
        if (jsonResponse['status'] == 'success') {
          final dynamic payload = jsonResponse['data'];
          if (payload is Map<String, dynamic>) {
            return PengumumanModel.fromJson(payload);
          }
          throw ServerException(message: 'Format data tidak valid');
        } else {
          throw ServerException(
              message:
                  jsonResponse['message'] ?? 'Gagal memuat detail pengumuman');
        }
      } else if (response.statusCode == 401) {
        throw AuthException(message: 'Tidak diizinkan: Token tidak valid');
      } else if (response.statusCode == 404) {
        throw ServerException(message: 'Detail pengumuman tidak ditemukan');
      } else if (response.statusCode >= 500) {
        throw ServerException(
            message: 'Server sedang bermasalah. Silakan coba lagi nanti');
      } else {
        throw ServerException(
            message: 'Gagal memuat detail pengumuman: ${response.statusCode}');
      }
    } on TimeoutException {
      rethrow;
    } on AuthException {
      rethrow;
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(
          message: 'Gagal memuat detail pengumuman: ${e.toString()}');
    }
  }
}
