import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/agenda_model.dart';
import '../../core/constants/app_constants.dart';
import 'auth_local_storage.dart';
import '../../core/error/exceptions.dart';
import 'package:ladimas/core/services/cache_service.dart';
import 'package:ladimas/core/services/persistent_cache_service.dart';

class AgendaApiService {
  final http.Client client;
  final AuthLocalStorage authLocalStorage;
  final CacheService _cache = CacheService();
  final Duration _ttl = const Duration(minutes: 1); // Cache TTL 1 menit
  final PersistentCacheService _persistent = PersistentCacheService();

  AgendaApiService({
    required this.client,
    required this.authLocalStorage,
  });

  // Method untuk clear cache agenda
  Future<void> clearCache() async {
    try {
      // Clear in-memory cache
      _cache.clear();

      // Clear persistent cache
      await _persistent.clear();

      print('✅ Agenda cache cleared');
    } catch (e) {
      print('❌ Error clearing agenda cache: $e');
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

  Future<List<AgendaModel>> getAgenda(
      {int? villageId, bool forceRefresh = false}) async {
    try {
      // Create cache key based on villageId, use 'all' for null villageId
      final key = villageId != null && villageId > 0
          ? 'agenda_list_$villageId'
          : 'agenda_list_all';

      // Check cache first unless forced refresh
      if (!forceRefresh) {
        final cached = _cache.get<List<AgendaModel>>(key);
        if (cached != null) return cached;

        // Try persistent cache
        final persisted = await _persistent.getJson<List<dynamic>>(key);
        if (persisted != null) {
          final restored = persisted
              .whereType<Map<String, dynamic>>()
              .map((e) => AgendaModel.fromJson(e))
              .toList();
          _cache.set<List<AgendaModel>>(key, restored, ttl: _ttl);
          return restored;
        }
      }

      final token = await _getAuthToken();
      final StringBuffer urlBuffer =
          StringBuffer('${AppConstants.authApiUrl}/user/agenda-desa');
      urlBuffer.write('?format=json');

      if (villageId != null && villageId > 0) {
        urlBuffer.write('&villages_id=$villageId');
        urlBuffer.write('&village_id=$villageId');
        urlBuffer.write('&desa_id=$villageId');
      }

      final String url = urlBuffer.toString();

      print('Agenda API - Requesting URL: $url');
      print('Agenda API - Village ID filter: $villageId');

      // Try to get agenda data
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
        print('Agenda API - Response body: ${response.body}');
        final Map<String, dynamic> jsonResponse = json.decode(response.body);
        print('Agenda API - Response status: ${jsonResponse['status']}');

        if (jsonResponse['status'] == 'success') {
          final dynamic rawData = jsonResponse['data'];
          print('Agenda API - Raw data type: ${rawData.runtimeType}');

          List<dynamic> data = [];
          if (rawData is List) {
            data = rawData;
          } else if (rawData is Map && rawData.containsKey('data')) {
            data = rawData['data'] ?? [];
          }

          print('Agenda API - Raw data count: ${data.length}');

          final result = data
              .map((item) => AgendaModel.fromJson(item as Map<String, dynamic>))
              .toList();
          print('Agenda API - Parsed result count: ${result.length}');

          if (result.isNotEmpty) {
            for (var item in result) {
              print(
                  'Agenda API - Item: ${item.judul} (ID: ${item.id}, Village: ${item.villagesId})');
            }
          }

          // Cache the result
          _cache.set<List<AgendaModel>>(key, result, ttl: _ttl);
          await _persistent.setJson(
            key,
            result.map((e) => e.toJson()).toList(),
            ttl: _ttl,
          );

          // If we have a village filter and no results, try loading all agenda
          if (result.isEmpty && villageId != null && villageId > 0) {
            print(
                'Agenda API - No results with village filter, trying to load all agenda');
            try {
              final allAgendaUrl =
                  '${AppConstants.authApiUrl}/user/agenda-desa?format=json';
              print('Agenda API - Requesting all agenda URL: $allAgendaUrl');

              final allResponse = await client.get(
                Uri.parse(allAgendaUrl),
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

              if (allResponse.statusCode == 200) {
                final Map<String, dynamic> allJsonResponse =
                    json.decode(allResponse.body);
                if (allJsonResponse['status'] == 'success') {
                  final dynamic allRawData = allJsonResponse['data'];
                  List<dynamic> allData = [];
                  if (allRawData is List) {
                    allData = allRawData;
                  } else if (allRawData is Map &&
                      allRawData.containsKey('data')) {
                    allData = allRawData['data'] ?? [];
                  }

                  final allResult = allData
                      .map((item) =>
                          AgendaModel.fromJson(item as Map<String, dynamic>))
                      .toList();
                  print('Agenda API - All agenda count: ${allResult.length}');

                  // Cache with 'all' key
                  const String allKey = 'agenda_list_all';
                  _cache.set<List<AgendaModel>>(allKey, allResult, ttl: _ttl);
                  await _persistent.setJson(
                    allKey,
                    allResult.map((e) => e.toJson()).toList(),
                    ttl: _ttl,
                  );

                  return allResult;
                }
              }
            } catch (fallbackError) {
              print('Agenda API - Fallback request failed: $fallbackError');
              // Continue with empty result
            }
          }

          return result;
        } else {
          throw ServerException(
            message: jsonResponse['message'] ?? 'Gagal mengambil data agenda',
          );
        }
      } else if (response.statusCode == 401) {
        throw AuthException(
            message: 'Sesi telah berakhir. Silakan login kembali.');
      } else if (response.statusCode == 403) {
        throw AuthException(
            message: 'Anda tidak memiliki akses untuk melihat agenda.');
      } else if (response.statusCode == 404) {
        throw ServerException(message: 'Data agenda tidak ditemukan.');
      } else if (response.statusCode >= 500) {
        throw ServerException(
            message:
                'Server sedang mengalami gangguan. Silakan coba lagi nanti.');
      } else {
        throw ServerException(
          message:
              'Gagal mengambil data agenda. Status: ${response.statusCode}',
        );
      }
    } on SocketException {
      throw ServerException(
          message: 'Tidak ada koneksi internet. Periksa koneksi Anda.');
    } on FormatException {
      throw ServerException(message: 'Format data tidak valid.');
    } on TimeoutException {
      throw ServerException(message: 'Koneksi timeout. Silakan coba lagi.');
    } catch (e) {
      if (e is AuthException || e is ServerException) {
        rethrow;
      }
      throw ServerException(message: 'Terjadi kesalahan: ${e.toString()}');
    }
  }

  Future<AgendaModel> getAgendaDetail(int id) async {
    try {
      final token = await _getAuthToken();
      final response = await client.get(
        Uri.parse(
            '${AppConstants.authApiUrl}/user/agenda-desa/$id?format=json'),
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
          return AgendaModel.fromJson(jsonResponse['data']);
        } else {
          throw ServerException(
            message: jsonResponse['message'] ?? 'Gagal mengambil detail agenda',
          );
        }
      } else if (response.statusCode == 401) {
        throw AuthException(
            message: 'Sesi telah berakhir. Silakan login kembali.');
      } else if (response.statusCode == 403) {
        throw AuthException(
            message: 'Anda tidak memiliki akses untuk melihat detail agenda.');
      } else if (response.statusCode == 404) {
        throw ServerException(message: 'Agenda tidak ditemukan.');
      } else if (response.statusCode >= 500) {
        throw ServerException(
            message:
                'Server sedang mengalami gangguan. Silakan coba lagi nanti.');
      } else {
        throw ServerException(
          message:
              'Gagal mengambil detail agenda. Status: ${response.statusCode}',
        );
      }
    } on SocketException {
      throw ServerException(
          message: 'Tidak ada koneksi internet. Periksa koneksi Anda.');
    } on FormatException {
      throw ServerException(message: 'Format data tidak valid.');
    } on TimeoutException {
      throw ServerException(message: 'Koneksi timeout. Silakan coba lagi.');
    } catch (e) {
      if (e is AuthException || e is ServerException) {
        rethrow;
      }
      throw ServerException(message: 'Terjadi kesalahan: ${e.toString()}');
    }
  }
}
