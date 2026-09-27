import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:ladimas/core/constants/app_constants.dart';
import 'package:ladimas/core/errors/exception.dart';
import 'package:ladimas/data/datasources/auth_local_storage.dart';
import 'package:ladimas/data/models/laporan_model.dart';
import 'package:ladimas/core/services/cache_service.dart';
import 'package:ladimas/core/services/persistent_cache_service.dart';

class RuangLingkupData {
  final int id;
  final String ruangLingkup;
  final String bidang;
  final String keterangan;

  RuangLingkupData({
    required this.id,
    required this.ruangLingkup,
    required this.bidang,
    required this.keterangan,
  });

  factory RuangLingkupData.fromJson(Map<String, dynamic> json) {
    // Robust ID conversion
    int id;
    final rawId = json['id'];

    if (rawId is int) {
      id = rawId;
    } else if (rawId is String) {
      id = int.tryParse(rawId) ?? 0;
    } else if (rawId is double) {
      id = rawId.toInt();
    } else {
      id = 0;
    }

    return RuangLingkupData(
      id: id,
      ruangLingkup: json['ruang_lingkup'] ?? '',
      bidang: json['bidang'] ?? '',
      keterangan: json['keterangan'] ?? '',
    );
  }
}

class VillageReportApiService {
  final http.Client client;
  final AuthLocalStorage authLocalStorage;
  final CacheService _cache = CacheService();
  final Duration _ttl = const Duration(minutes: 1); // Kurangi dari 5 menit ke 1 menit
  final PersistentCacheService _persistent = PersistentCacheService();

  VillageReportApiService({
    required this.client,
    required this.authLocalStorage,
  });

  // Method untuk clear cache village report
  Future<void> clearCache() async {
    try {
      // Clear in-memory cache
      _cache.clear();

      // Clear persistent cache
      await _persistent.clear();

      print('✅ Village report cache cleared');
    } catch (e) {
      print('❌ Error clearing village report cache: $e');
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
        return parts[1];
      }
    }

    return token;
  }

  Future<List<RuangLingkupData>> getLaporDesaOptions() async {
    try {
      final response = await client.get(
        Uri.parse('${AppConstants.authApiUrl}/lapor-desa'),
        headers: {
          'Accept': 'application/json',
          'X-API-Key': AppConstants.apiKey,
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);

        if (jsonResponse['status'] == 'success' &&
            jsonResponse['data'] is List) {
          final List<dynamic> optionsData = jsonResponse['data'];
          return optionsData
              .map((data) => RuangLingkupData.fromJson(data))
              .toList();
        } else {
          throw ServerException(
              message: jsonResponse['message'] ??
                  'Gagal mendapatkan data ruang lingkup');
        }
      } else if (response.statusCode == 401) {
        throw AuthException(message: 'Tidak diizinkan: Api key tidak valid');
      } else {
        throw ServerException(
            message:
                'Gagal mendapatkan data ruang lingkup: ${response.statusCode}');
      }
    } catch (e) {
      if (e is AuthException || e is ServerException) {
        rethrow;
      }
      throw ServerException(
          message: 'Gagal mendapatkan data ruang lingkup: ${e.toString()}');
    }
  }

  Future<List<VillageReportModel>> getVillageReports(
      {bool forceRefresh = false}) async {
    try {
      final key = 'village_reports_list';

      // Check cache first unless forced refresh
      if (!forceRefresh) {
        final cached = _cache.get<List<VillageReportModel>>(key);
        if (cached != null) return cached;

        // Try persistent cache
        final persisted = await _persistent.getJson<List<dynamic>>(key);
        if (persisted != null) {
          final restored = persisted
              .whereType<Map<String, dynamic>>()
              .map((e) => VillageReportModel.fromJson(e))
              .toList();
          _cache.set<List<VillageReportModel>>(key, restored, ttl: _ttl);
          return restored;
        }
      }

      final token = await _getAuthToken();

      final response = await client.get(
        Uri.parse('${AppConstants.authApiUrl}/user/laporan-desa'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);

        if (jsonResponse['status'] == 'success' &&
            jsonResponse['data'] is List) {
          final List<dynamic> reportsData = jsonResponse['data'];
          final result = reportsData
              .map((report) => VillageReportModel.fromJson(report))
              .toList();

          // Cache the result
          _cache.set<List<VillageReportModel>>(key, result, ttl: _ttl);
          await _persistent.setJson(
            key,
            result.map((e) => e.toJson()).toList(),
            ttl: _ttl,
          );

          return result;
        } else {
          throw ServerException(
              message:
                  jsonResponse['message'] ?? 'Gagal mendapatkan data laporan');
        }
      } else if (response.statusCode == 401) {
        throw AuthException(message: 'Tidak diizinkan: Token tidak valid');
      } else {
        throw ServerException(
            message: 'Gagal mendapatkan data laporan: ${response.statusCode}');
      }
    } catch (e) {
      if (e is AuthException || e is ServerException) {
        rethrow;
      }
      throw ServerException(
          message: 'Gagal mendapatkan data laporan: ${e.toString()}');
    }
  }

  Future<VillageReportModel> createVillageReport({
    required String judulLaporan,
    required String deskripsiLaporan,
    required String tagLokasi,
    required File gambar,
    required int ruangLingkupId,
    double? tagLat,
    double? tagLng,
    String? locationAddress,
  }) async {
    try {
      final token = await _getAuthToken();
      final uri = Uri.parse('${AppConstants.authApiUrl}/user/laporan-desa');

      // Create multipart request
      final request = http.MultipartRequest('POST', uri);

      // Add headers
      request.headers.addAll({
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      });

      // Add text fields
      request.fields['judul_laporan'] = judulLaporan;
      request.fields['deskripsi_laporan'] = deskripsiLaporan;
      request.fields['tag_lokasi'] = tagLokasi;

      // Tambahkan field koordinat terpisah dan alamat lokasi bila tersedia (sesuai API)
      if (tagLat != null) {
        request.fields['tag_lat'] = tagLat.toStringAsFixed(6);
      }
      if (tagLng != null) {
        request.fields['tag_lng'] = tagLng.toStringAsFixed(6);
      }
      if (locationAddress != null && locationAddress.trim().isNotEmpty) {
        request.fields['location_address'] = locationAddress.trim();
      }

      // Fix for the int conversion issue
      if (ruangLingkupId <= 0) {
        throw ServerException(message: 'ID ruang lingkup tidak valid');
      }

      // Make sure we send a string representation of the integer
      request.fields['lapor_desa_id'] = ruangLingkupId.toString();

      // Add image file
      final imageFile =
          await http.MultipartFile.fromPath('gambar', gambar.path);
      request.files.add(imageFile);

      // Send request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      // Handle response
      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);

        if (jsonResponse['status'] == 'success') {
          print(
              "Response data: ${jsonResponse['data']}"); // Debug print for response data
          return VillageReportModel.fromJson(jsonResponse['data']);
        } else {
          throw ServerException(
              message: jsonResponse['message'] ?? 'Gagal membuat laporan');
        }
      } else {
        final errorResponse = json.decode(response.body);

        throw ServerException(
            message:
                'Gagal membuat laporan: ${response.statusCode} - ${errorResponse['message'] ?? "Unknown error"}');
      }
    } catch (e) {
      if (e is AuthException || e is ServerException) {
        rethrow;
      }

      if (e
          .toString()
          .contains("type 'String' is not a subtype of type 'int'")) {
        throw ServerException(
            message:
                'Gagal membuat laporan: Format ID tidak sesuai. Pastikan ID berupa angka.');
      }
      throw ServerException(message: 'Gagal membuat laporan: ${e.toString()}');
    }
  }
}
