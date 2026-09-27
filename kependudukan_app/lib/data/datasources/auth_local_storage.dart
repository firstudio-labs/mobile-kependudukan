import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:ladimas/data/models/penduduk_model.dart';
import 'package:ladimas/core/services/cache_service.dart';
import 'package:ladimas/core/services/persistent_cache_service.dart';
import 'package:ladimas/data/datasources/berita_desa_api_service.dart';
import 'package:ladimas/data/datasources/admin_berita_desa_api_service.dart';
import 'package:ladimas/data/datasources/admin_pengumuman_api_service.dart';
import 'package:ladimas/data/datasources/admin_pemerintah_desa_api_service.dart';
import 'package:ladimas/data/datasources/pengumuman_api_service.dart';
import 'package:ladimas/data/datasources/agenda_api_service.dart';
import 'package:ladimas/data/datasources/laporan_api_service.dart';
import 'package:ladimas/core/services/penduduk_home_data_manager.dart';
import 'package:http/http.dart' as http;

class AuthLocalStorage {
  final FlutterSecureStorage _secureStorage;
  static const String _userKey = 'user_credentials';
  static const String _tokenUpdatedKey = 'token_updated_timestamp';
  static const String _cachedVillageIdKey = 'cached_village_id';
  static const String _cachedVillageIdUpdatedKey =
      'cached_village_id_updated_at';
  static const String _cachedKKKeyPrefix = 'cached_kk_';
  static const String _cachedKKUpdatedKeyPrefix = 'cached_kk_updated_';
  static const String _cachedPemdesKey = 'cached_pemerintah_desa';
  static const Duration _pemdesCacheTtl =
      Duration(days: 365); // Cache 1 tahun (permanent)

  AuthLocalStorage({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  Future<void> saveUserCredentials({
    required String nik,
    required String password,
    String? noHp,
    String? name,
    String? accessToken,
    String? tokenType,
    String? role,
    String? userType,
    String? alamat,
    String? tagLokasi,
  }) async {
    final userData = {
      'nik': nik,
      'password': password,
      'no_hp': noHp ?? '',
      'name': name ?? '',
      'access_token': accessToken,
      'token_type': tokenType ?? 'Bearer',
      'role': role ?? '',
      'user_type': userType ?? '',
      'alamat': alamat ?? '',
      'tag_lokasi': tagLokasi ?? '',
    };

    await _secureStorage.write(key: _userKey, value: json.encode(userData));

    // Store a timestamp when the token was updated
    await _secureStorage.write(
        key: _tokenUpdatedKey,
        value: DateTime.now().millisecondsSinceEpoch.toString());
  }

  Future<Map<String, dynamic>?> getUserCredentials() async {
    final userDataString = await _secureStorage.read(key: _userKey);
    if (userDataString != null) {
      return json.decode(userDataString) as Map<String, dynamic>;
    }
    return null;
  }

  Future<void> cacheVillageId(int villageId) async {
    await _secureStorage.write(
        key: _cachedVillageIdKey, value: villageId.toString());
    await _secureStorage.write(
      key: _cachedVillageIdUpdatedKey,
      value: DateTime.now().millisecondsSinceEpoch.toString(),
    );
  }

  Future<int?> getCachedVillageId(
      {Duration maxAge = const Duration(hours: 12)}) async {
    final cachedValue = await _secureStorage.read(key: _cachedVillageIdKey);
    if (cachedValue == null) return null;

    final timestampString =
        await _secureStorage.read(key: _cachedVillageIdUpdatedKey);
    if (timestampString != null) {
      final timestamp =
          DateTime.fromMillisecondsSinceEpoch(int.parse(timestampString));
      if (DateTime.now().difference(timestamp) > maxAge) {
        return null;
      }
    }
    return int.tryParse(cachedValue);
  }

  Future<void> clearCachedVillageId() async {
    await _secureStorage.delete(key: _cachedVillageIdKey);
    await _secureStorage.delete(key: _cachedVillageIdUpdatedKey);
  }

  Future<void> clearUserCredentials() async {
    await _secureStorage.delete(key: _userKey);
    await _secureStorage.delete(key: _tokenUpdatedKey);
    await clearCachedVillageId();
    await clearAllCachedKK();
  }

  // Method untuk clear semua cache data saat logout
  Future<void> clearAllCache() async {
    try {
      // Clear user credentials
      await clearUserCredentials();

      // Clear semua data yang mungkin di-cache
      await _secureStorage.deleteAll();

      // Clear in-memory cache
      CacheService().clear();

      // Clear persistent cache
      await PersistentCacheService().clear();

      // Clear cache dari semua API service
      await _clearApiServiceCaches();

      // Clear data dari PendudukHomeDataManager
      PendudukHomeDataManager().clearAllData();

      print('✅ All cache cleared successfully');
    } catch (e) {
      print('❌ Error clearing cache: $e');
    }
  }

  // Method untuk clear cache dari semua API service
  Future<void> _clearApiServiceCaches() async {
    try {
      final authLocalStorage = AuthLocalStorage();
      final httpClient = http.Client();

      // Clear cache dari BeritaDesaApiService
      final beritaDesaService = BeritaDesaApiService(
        client: httpClient,
        authLocalStorage: authLocalStorage,
      );
      await beritaDesaService.clearCache();

      // Clear cache dari AdminBeritaDesaApiService
      final adminBeritaDesaService = AdminBeritaDesaApiService(
        client: httpClient,
        authLocalStorage: authLocalStorage,
      );
      await adminBeritaDesaService.clearCache();

      // Clear cache dari AdminPengumumanApiService
      final adminPengumumanService = AdminPengumumanApiService(
        client: httpClient,
        authLocalStorage: authLocalStorage,
      );
      await adminPengumumanService.clearCache();

      // Clear cache dari AdminPemerintahDesaApiService
      final adminPemerintahDesaService = AdminPemerintahDesaApiService(
        client: httpClient,
        authLocalStorage: authLocalStorage,
      );
      await adminPemerintahDesaService.clearCache();

      // Clear cache dari PengumumanApiService (untuk PendudukHomePage)
      final pengumumanService = PengumumanApiService(
        client: httpClient,
        authLocalStorage: authLocalStorage,
      );
      await pengumumanService.clearCache();

      // Clear cache dari AgendaApiService (untuk PendudukHomePage)
      final agendaService = AgendaApiService(
        client: httpClient,
        authLocalStorage: authLocalStorage,
      );
      await agendaService.clearCache();

      // Clear cache dari VillageReportApiService (untuk PendudukHomePage)
      final villageReportService = VillageReportApiService(
        client: httpClient,
        authLocalStorage: authLocalStorage,
      );
      await villageReportService.clearCache();

      print('✅ All API service caches cleared');
    } catch (e) {
      print('❌ Error clearing API service caches: $e');
    }
  }

  Future<bool> hasUserCredentials() async {
    final userDataString = await _secureStorage.read(key: _userKey);
    return userDataString != null;
  }

  Future<PendudukModel?> getStoredPenduduk() async {
    final userData = await getUserCredentials();
    if (userData != null) {
      return PendudukModel(
        nik: userData['nik'],
        noHp: userData['no_hp'] ?? '',
        name: userData['name'] ?? '',
        accessToken: userData['access_token'],
        tokenType: userData['token_type'],
      );
    }
    return null;
  }

  Future<String?> getStoredUserType() async {
    final userData = await getUserCredentials();
    return userData != null ? (userData['user_type'] as String?) : null;
  }

  Future<String?> getStoredRole() async {
    final userData = await getUserCredentials();
    return userData != null ? (userData['role'] as String?) : null;
  }

  Future<String?> getStoredToken() async {
    final userCreds = await getUserCredentials();
    if (userCreds != null && userCreds['access_token'] != null) {
      return userCreds['access_token'];
    }
    return null;
  }

  Future<DateTime?> getTokenUpdatedTimestamp() async {
    final timestampStr = await _secureStorage.read(key: _tokenUpdatedKey);
    if (timestampStr != null) {
      return DateTime.fromMillisecondsSinceEpoch(int.parse(timestampStr));
    }
    return null;
  }

  /// Cache KK berdasarkan NIK untuk mempercepat loading menu keluarga
  Future<void> cacheKKByNik(String nik, String kk) async {
    if (nik.isEmpty || kk.isEmpty) return;
    await _secureStorage.write(key: '$_cachedKKKeyPrefix$nik', value: kk);
    await _secureStorage.write(
      key: '$_cachedKKUpdatedKeyPrefix$nik',
      value: DateTime.now().millisecondsSinceEpoch.toString(),
    );
  }

  /// Mendapatkan KK dari cache berdasarkan NIK
  Future<String?> getCachedKKByNik(String nik,
      {Duration maxAge = const Duration(days: 30)}) async {
    if (nik.isEmpty) return null;

    final cachedValue =
        await _secureStorage.read(key: '$_cachedKKKeyPrefix$nik');
    if (cachedValue == null || cachedValue.isEmpty) return null;

    final timestampString =
        await _secureStorage.read(key: '$_cachedKKUpdatedKeyPrefix$nik');
    if (timestampString != null) {
      final timestamp =
          DateTime.fromMillisecondsSinceEpoch(int.parse(timestampString));
      if (DateTime.now().difference(timestamp) > maxAge) {
        // Cache expired, clear it
        await clearCachedKKByNik(nik);
        return null;
      }
    }
    return cachedValue;
  }

  /// Clear cache KK untuk NIK tertentu
  Future<void> clearCachedKKByNik(String nik) async {
    if (nik.isEmpty) return;
    await _secureStorage.delete(key: '$_cachedKKKeyPrefix$nik');
    await _secureStorage.delete(key: '$_cachedKKUpdatedKeyPrefix$nik');
  }

  /// Clear semua cache KK
  Future<void> clearAllCachedKK() async {
    try {
      final allKeys = await _secureStorage.readAll();
      final kkKeys = allKeys.keys.where((key) =>
          key.startsWith(_cachedKKKeyPrefix) ||
          key.startsWith(_cachedKKUpdatedKeyPrefix));
      for (final key in kkKeys) {
        await _secureStorage.delete(key: key);
      }
    } catch (e) {
      print('Error clearing KK cache: $e');
    }
  }

  // ==================== PEMERINTAH DESA CACHE ====================

  /// Cache data pemerintah desa dengan TTL 24 jam
  Future<void> cachePemerintahDesa(Map<String, dynamic> data) async {
    try {
      final record = {
        'data': data,
        'ts': DateTime.now().millisecondsSinceEpoch,
        'ttlMs': _pemdesCacheTtl.inMilliseconds,
      };
      await _secureStorage.write(
          key: _cachedPemdesKey, value: json.encode(record));
      print('✅ [Cache] Pemerintah Desa cached successfully');
    } catch (e) {
      print('❌ [Cache] Error caching Pemerintah Desa: $e');
    }
  }

  /// Ambil cached pemerintah desa jika masih valid (belum expired)
  Future<Map<String, dynamic>?> getCachedPemerintahDesa() async {
    try {
      final raw = await _secureStorage.read(key: _cachedPemdesKey);
      if (raw == null) {
        print('⚠️  [Cache] No cached Pemerintah Desa found');
        return null;
      }

      final decoded = json.decode(raw) as Map<String, dynamic>;
      final int ts = decoded['ts'] as int? ?? 0;
      final int ttlMs = decoded['ttlMs'] as int? ?? 0;
      final age = DateTime.now().millisecondsSinceEpoch - ts;
      final expired = age > ttlMs;

      if (expired) {
        print(
            '⚠️  [Cache] Pemerintah Desa cache expired (age: ${age ~/ 1000}s)');
        await _secureStorage.delete(key: _cachedPemdesKey);
        return null;
      }

      print(
          '✅ [Cache] Pemerintah Desa loaded from cache (age: ${age ~/ 1000}s)');
      return decoded['data'] as Map<String, dynamic>?;
    } catch (e) {
      print('❌ [Cache] Error reading cached Pemerintah Desa: $e');
      await _secureStorage.delete(key: _cachedPemdesKey);
      return null;
    }
  }

  /// Clear cache pemerintah desa
  Future<void> clearCachedPemerintahDesa() async {
    try {
      await _secureStorage.delete(key: _cachedPemdesKey);
      print('✅ [Cache] Pemerintah Desa cache cleared');
    } catch (e) {
      print('❌ [Cache] Error clearing Pemerintah Desa cache: $e');
    }
  }
}
