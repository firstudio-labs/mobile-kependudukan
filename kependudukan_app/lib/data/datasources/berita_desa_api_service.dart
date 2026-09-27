import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../models/berita_desa_model.dart';
import '../../core/constants/app_constants.dart';
import 'auth_local_storage.dart';
import '../../core/error/exceptions.dart';
import 'package:ladimas/core/services/cache_service.dart';
import 'package:ladimas/core/services/persistent_cache_service.dart';

class BeritaDesaApiService {
  final http.Client client;
  final AuthLocalStorage authLocalStorage;
  final CacheService _cache = CacheService();
  final Duration _ttl = const Duration(minutes: 1); // Kurangi dari 5 menit ke 1 menit
  final PersistentCacheService _persistent = PersistentCacheService();

  BeritaDesaApiService({
    required this.client,
    required this.authLocalStorage,
  });

  // Method untuk clear cache berita desa
  Future<void> clearCache() async {
    try {
      // Clear in-memory cache
      _cache.clear();

      // Clear persistent cache
      await _persistent.clear();

      print('✅ Berita desa cache cleared');
    } catch (e) {
      print('❌ Error clearing berita desa cache: $e');
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

  Future<List<BeritaDesaModel>> getBeritaDesa({int? villageId}) async {
    try {
      final key = 'berita_desa_list_${villageId ?? 0}';
      final cached = _cache.get<List<BeritaDesaModel>>(key);
      if (cached != null) return cached;
      final persisted = await _persistent.getJson<List<dynamic>>(key);
      if (persisted != null) {
        final restored = persisted
            .whereType<Map<String, dynamic>>()
            .map((e) => BeritaDesaModel.fromJson(e))
            .toList();
        _cache.set<List<BeritaDesaModel>>(key, restored, ttl: _ttl);
        return restored;
      }

      final token = await _getAuthToken();
      // NOTE: endpoint Laravel biasanya paginated. Ambil per_page besar agar tidak "kepotong".
      final String baseUrl =
          '${AppConstants.authApiUrl}/user/berita-desa?format=json&per_page=200';
      final String url = villageId != null
          ? '$baseUrl&villages_id=$villageId&village_id=$villageId&desa_id=$villageId'
          : baseUrl;
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
        print('BeritaDesa API Response: $jsonResponse');

        if (jsonResponse['status'] == 'success') {
          // Backend bisa mengembalikan langsung array atau object dengan key data
          final dynamic payload = jsonResponse['data'];
          print('BeritaDesa Payload: $payload');

          final List<dynamic> beritaData = payload is List
              ? payload
              : (payload is Map<String, dynamic> && payload['items'] is List)
                  ? payload['items']
                  : <dynamic>[];

          print('BeritaDesa Data Count: ${beritaData.length}');

          final List<BeritaDesaModel> allItems = beritaData
              .whereType<Map<String, dynamic>>()
              .map((data) {
                try {
                  return BeritaDesaModel.fromJson(data);
                } catch (e) {
                  print('Error parsing berita item: $e');
                  print('Data: $data');
                  return null;
                }
              })
              .where((item) => item != null)
              .cast<BeritaDesaModel>()
              .toList();

          print('BeritaDesa Parsed Count: ${allItems.length}');

          // IMPORTANT:
          // Untuk mobile, kita sudah kirim parameter villages_id/village_id/desa_id di query.
          // Jadi hasil dari backend seharusnya sudah ter-filter. Jangan filter lagi di client,
          // karena beberapa record bisa punya field village_id null dan akhirnya "hilang".
          _cache.set<List<BeritaDesaModel>>(key, allItems, ttl: _ttl);
          await _persistent.setJson(
            key,
            allItems.map((e) => e.toJson()).toList(),
            ttl: _ttl,
          );
          return allItems;
        } else {
          throw ServerException(
              message: jsonResponse['message'] ??
                  'Gagal mendapatkan data berita desa');
        }
      } else if (response.statusCode == 401) {
        throw AuthException(message: 'Tidak diizinkan: Token tidak valid');
      } else if (response.statusCode == 404) {
        throw ServerException(message: 'Data berita desa tidak ditemukan');
      } else if (response.statusCode >= 500) {
        throw ServerException(
            message: 'Server sedang bermasalah. Silakan coba lagi nanti');
      } else {
        throw ServerException(
            message:
                'Gagal mendapatkan data berita desa: ${response.statusCode}');
      }
    } on TimeoutException {
      rethrow;
    } on AuthException {
      rethrow;
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(
          message: 'Gagal mendapatkan data berita desa: ${e.toString()}');
    }
  }

  int? _extractVillageId(Map<String, dynamic>? wilayahInfo) {
    if (wilayahInfo == null) return null;

    try {
      // Check for villages_id first (new API field)
      if (wilayahInfo.containsKey('villages_id')) {
        final dynamic value = wilayahInfo['villages_id'];
        if (value is int) return value;
        final parsed = int.tryParse('$value');
        if (parsed != null) return parsed;
      }
      if (wilayahInfo.containsKey('village_id')) {
        final dynamic value = wilayahInfo['village_id'];
        if (value is int) return value;
        final parsed = int.tryParse('$value');
        if (parsed != null) return parsed;
      }
      if (wilayahInfo.containsKey('desa_id')) {
        final dynamic value = wilayahInfo['desa_id'];
        if (value is int) return value;
        final parsed = int.tryParse('$value');
        if (parsed != null) return parsed;
      }
      if (wilayahInfo.containsKey('village') &&
          wilayahInfo['village'] is Map<String, dynamic>) {
        final dynamic value =
            (wilayahInfo['village'] as Map<String, dynamic>)['id'];
        if (value is int) return value;
        final parsed = int.tryParse('$value');
        if (parsed != null) return parsed;
      }
      if (wilayahInfo.containsKey('desa') &&
          wilayahInfo['desa'] is Map<String, dynamic>) {
        final dynamic value =
            (wilayahInfo['desa'] as Map<String, dynamic>)['id'];
        if (value is int) return value;
        final parsed = int.tryParse('$value');
        if (parsed != null) return parsed;
      }
      if (wilayahInfo.containsKey('villageId')) {
        final dynamic value = wilayahInfo['villageId'];
        if (value is int) return value;
        final parsed = int.tryParse('$value');
        if (parsed != null) return parsed;
      }
      if (wilayahInfo.containsKey('desaId')) {
        final dynamic value = wilayahInfo['desaId'];
        if (value is int) return value;
        final parsed = int.tryParse('$value');
        if (parsed != null) return parsed;
      }
    } catch (_) {}

    return null;
  }

  Future<BeritaDesaModel> getBeritaDesaDetail({required int id}) async {
    try {
      final token = await _getAuthToken();
      final String url =
          '${AppConstants.authApiUrl}/user/berita-desa/$id?format=json';
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
            try {
              return BeritaDesaModel.fromJson(payload);
            } catch (e) {
              print('Error parsing berita detail: $e');
              print('Data: $payload');
              throw ServerException(
                  message: 'Format data tidak valid: ${e.toString()}');
            }
          }
          throw ServerException(message: 'Format data tidak valid');
        } else {
          throw ServerException(
              message: jsonResponse['message'] ??
                  'Gagal mendapatkan detail berita desa');
        }
      } else if (response.statusCode == 401) {
        throw AuthException(message: 'Tidak diizinkan: Token tidak valid');
      } else if (response.statusCode == 404) {
        throw ServerException(message: 'Detail berita desa tidak ditemukan');
      } else if (response.statusCode == 500) {
        // Handle 500 error with better error message
        try {
          final Map<String, dynamic> jsonResponse = json.decode(response.body);
          throw ServerException(
              message: jsonResponse['message'] ??
                  'Server error: Gagal mendapatkan detail berita desa');
        } catch (e) {
          throw ServerException(
              message:
                  'Server error: Gagal mendapatkan detail berita desa. Silakan coba lagi.');
        }
      } else if (response.statusCode >= 500) {
        throw ServerException(
            message: 'Server sedang bermasalah. Silakan coba lagi nanti');
      } else {
        throw ServerException(
            message:
                'Gagal mendapatkan detail berita desa: ${response.statusCode}');
      }
    } on TimeoutException {
      rethrow;
    } on AuthException {
      rethrow;
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(
          message: 'Gagal mendapatkan detail berita desa: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> createBeritaDesa({
    required String judul,
    required String deskripsi,
    String? komentar,
    File? gambar,
    bool submitForApproval = true,
  }) async {
    try {
      final token = await _getAuthToken();
      final uri =
          Uri.parse('${AppConstants.authApiUrl}/user/berita-desa?format=json');

      final request = http.MultipartRequest('POST', uri)
        ..headers.addAll({
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
          'X-API-Key': AppConstants.apiKey,
        })
        ..fields['judul'] = judul
        ..fields['deskripsi'] = deskripsi
        ..fields['submit_for_approval'] = submitForApproval ? '1' : '0';

      if (komentar != null && komentar.isNotEmpty) {
        request.fields['komentar'] = komentar;
      }

      if (gambar != null && await gambar.exists()) {
        final fileName = gambar.path.split('/').last;
        request.files.add(await http.MultipartFile.fromPath(
            'gambar', gambar.path,
            filename: fileName));
      }

      final streamed = await request.send().timeout(
        NetworkConstants.defaultTimeout,
        onTimeout: () {
          throw TimeoutException('Koneksi timeout. Silakan coba lagi.');
        },
      );
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);
        if (jsonResponse['status'] == 'success' ||
            jsonResponse['status'] == true) {
          return jsonResponse;
        }
        throw ServerException(
            message: jsonResponse['message'] ?? 'Gagal menyimpan berita');
      } else if (response.statusCode == 422) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);
        throw ServerException(
            message: jsonResponse['message'] ?? 'Validasi gagal');
      } else if (response.statusCode == 401) {
        throw AuthException(message: 'Tidak diizinkan: Token tidak valid');
      } else if (response.statusCode == 500) {
        // Handle 500 error with better error message
        try {
          final Map<String, dynamic> jsonResponse = json.decode(response.body);
          throw ServerException(
              message: jsonResponse['message'] ??
                  'Server error: Gagal menyimpan berita');
        } catch (e) {
          throw ServerException(
              message:
                  'Server error: Gagal menyimpan berita. Silakan coba lagi.');
        }
      } else {
        throw ServerException(
            message: 'Gagal menyimpan berita: ${response.statusCode}');
      }
    } on TimeoutException {
      rethrow;
    } on AuthException {
      rethrow;
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(message: 'Gagal menyimpan berita: ${e.toString()}');
    }
  }

  Future<void> sendApproval({required int id}) async {
    try {
      final token = await _getAuthToken();
      final url =
          '${AppConstants.authApiUrl}/user/berita-desa/$id/send-approval?format=json';
      final response = await client.post(
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
        if (jsonResponse['status'] == 'success' ||
            jsonResponse['status'] == true) {
          return;
        }
        throw ServerException(
            message: jsonResponse['message'] ?? 'Gagal mengirim approval');
      } else if (response.statusCode == 404) {
        throw ServerException(message: 'Berita tidak ditemukan');
      } else if (response.statusCode == 401) {
        throw AuthException(message: 'Tidak diizinkan: Token tidak valid');
      } else if (response.statusCode == 500) {
        // Handle 500 error with better error message
        try {
          final Map<String, dynamic> jsonResponse = json.decode(response.body);
          throw ServerException(
              message: jsonResponse['message'] ??
                  'Server error: Gagal mengirim approval');
        } catch (e) {
          throw ServerException(
              message:
                  'Server error: Gagal mengirim approval. Silakan coba lagi.');
        }
      } else {
        throw ServerException(
            message: 'Gagal mengirim approval: ${response.statusCode}');
      }
    } on TimeoutException {
      rethrow;
    } on AuthException {
      rethrow;
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(
          message: 'Gagal mengirim approval: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> updateBeritaDesa({
    required int id,
    required String judul,
    required String deskripsi,
    String? komentar,
    File? gambar,
    bool submitForApproval = false,
  }) async {
    try {
      final token = await _getAuthToken();
      final uri = Uri.parse(
          '${AppConstants.authApiUrl}/user/berita-desa/$id?format=json');

      final request = http.MultipartRequest('POST', uri)
        ..headers.addAll({
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
          'X-API-Key': AppConstants.apiKey,
        })
        ..fields['_method'] =
            'PUT' // fallback jika server tidak menerima PUT multipart
        ..fields['judul'] = judul
        ..fields['deskripsi'] = deskripsi
        ..fields['submit_for_approval'] = submitForApproval ? '1' : '0';

      if (komentar != null && komentar.isNotEmpty) {
        request.fields['komentar'] = komentar;
      }

      if (gambar != null && await gambar.exists()) {
        final fileName = gambar.path.split('/').last;
        request.files.add(await http.MultipartFile.fromPath(
            'gambar', gambar.path,
            filename: fileName));
      }

      final streamed = await request.send().timeout(
        NetworkConstants.defaultTimeout,
        onTimeout: () {
          throw TimeoutException('Koneksi timeout. Silakan coba lagi.');
        },
      );
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);
        if (jsonResponse['status'] == 'success' ||
            jsonResponse['status'] == true) {
          return jsonResponse;
        }
        throw ServerException(
            message: jsonResponse['message'] ?? 'Gagal memperbarui draf');
      } else if (response.statusCode == 404) {
        throw ServerException(message: 'Draf tidak ditemukan');
      } else if (response.statusCode == 401) {
        throw AuthException(message: 'Tidak diizinkan: Token tidak valid');
      } else if (response.statusCode == 500) {
        // Handle 500 error with better error message
        try {
          final Map<String, dynamic> jsonResponse = json.decode(response.body);
          throw ServerException(
              message: jsonResponse['message'] ??
                  'Server error: Gagal memperbarui draf');
        } catch (e) {
          throw ServerException(
              message:
                  'Server error: Gagal memperbarui draf. Silakan coba lagi.');
        }
      } else {
        throw ServerException(
            message: 'Gagal memperbarui draf: ${response.statusCode}');
      }
    } on TimeoutException {
      rethrow;
    } on AuthException {
      rethrow;
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(message: 'Gagal memperbarui draf: ${e.toString()}');
    }
  }
}
