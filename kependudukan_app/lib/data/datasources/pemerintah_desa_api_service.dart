import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:ladimas/core/constants/app_constants.dart';
import 'package:ladimas/core/error/exceptions.dart';
import 'package:ladimas/data/models/pemerintah_desa_model.dart';
import 'package:ladimas/data/datasources/auth_local_storage.dart';
import 'package:ladimas/core/services/cache_service.dart';
import 'package:ladimas/core/services/persistent_cache_service.dart';

class PemerintahDesaApiService {
  final http.Client client;
  final AuthLocalStorage authLocalStorage;
  final CacheService _cache = CacheService();
  final Duration _ttl = const Duration(
      days: 365); // Cache 1 tahun (praktis permanent, hanya refresh manual)
  final PersistentCacheService _persistent = PersistentCacheService();
  String? lastRawBody;
  int? lastStatusCode;
  String? lastUrl;

  PemerintahDesaApiService({
    required this.client,
    required this.authLocalStorage,
  });

  /// Clear cache untuk force refresh
  Future<void> clearCache() async {
    const cacheKey = 'pemdes_public_show';
    _cache.invalidate(cacheKey);
    await _persistent.invalidate(cacheKey);
    print('✅ [PemdesAPI] Cache cleared');
  }

  Future<PemerintahDesaModel> getPemerintahDesa(
      {bool forceRefresh = false}) async {
    const cacheKey = 'pemdes_public_show';

    // Jika force refresh, clear cache dulu
    if (forceRefresh) {
      await clearCache();
      print('🔄 [PemdesAPI] Force refresh - cache cleared');
    }

    // Cek in-memory cache
    final cached = _cache.get<PemerintahDesaModel>(cacheKey);
    if (cached != null) {
      print('✅ [PemdesAPI] Loaded from in-memory cache');
      return cached;
    }

    // Cek persistent cache
    final persisted = await _persistent.getJson<Map<String, dynamic>>(cacheKey);
    if (persisted != null) {
      final restored = PemerintahDesaModel.fromJson(persisted);
      _cache.set<PemerintahDesaModel>(cacheKey, restored, ttl: _ttl);
      print('✅ [PemdesAPI] Loaded from persistent cache');
      return restored;
    }

    final token = await authLocalStorage.getStoredToken();
    if (token == null || token.isEmpty) {
      throw AuthException(message: 'Anda belum login atau sesi telah berakhir');
    }
    // Ambil token format tanpa prefix id| jika ada
    String bearer = token;
    if (bearer.contains('|')) {
      final parts = bearer.split('|');
      if (parts.length > 1) bearer = parts[1].trim();
    }

    // Gunakan authApiUrl seperti service Pengumuman
    final base = AppConstants.authApiUrl;
    // Prioritaskan endpoint admin yang Anda sediakan
    final candidatePaths = <String>[
      '/user/admin/pemerintah-desa',
      '/user/pemerintah-desa'
    ];

    // 1) Probe endpoint token-info untuk memastikan prefix benar
    try {
      final probeUrl = '$base/user/token-info';
      print('[PemdesAPI] PROBE token-info: ' + probeUrl);
      final probe = await client.get(
        Uri.parse(probeUrl),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $bearer',
          'X-API-Key': AppConstants.apiKey,
        },
      );
      print('[PemdesAPI] PROBE status: ' + probe.statusCode.toString());
      if (probe.statusCode == 404) {
        print('[PemdesAPI] PROBE 404 → kemungkinan prefix baseUrl tidak cocok');
      }
    } catch (e) {
      print('[PemdesAPI] PROBE error: ' + e.toString());
    }

    http.Response? resp;
    for (final path in candidatePaths) {
      final url = '$base$path';
      lastUrl = url;
      print('[PemdesAPI] GET: ' + url);
      final r = await client.get(
        Uri.parse(url),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $bearer',
          'X-API-Key': AppConstants.apiKey,
        },
      );

      lastStatusCode = r.statusCode;
      final bodyPreview = r.body.length > 1200
          ? r.body.substring(0, 1200) + '... (truncated)'
          : r.body;
      print('[PemdesAPI] status: ' + r.statusCode.toString());
      print('[PemdesAPI] body: ' + bodyPreview);
      lastRawBody = r.body;

      if (r.statusCode == 200) {
        resp = r;
        break;
      }
    }

    if (resp == null) {
      throw Exception('Gagal memuat pemerintah desa: ${lastStatusCode}');
    }

    final Map<String, dynamic> data =
        json.decode(resp.body) as Map<String, dynamic>;
    final model = PemerintahDesaModel.fromJson(data);
    _cache.set<PemerintahDesaModel>(cacheKey, model, ttl: _ttl);
    await _persistent.setJson(cacheKey, data, ttl: _ttl);
    return model;
  }
}
