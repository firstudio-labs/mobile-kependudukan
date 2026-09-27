import 'dart:convert';
import 'dart:io';
import 'package:ladimas/data/datasources/auth_local_storage.dart';
import 'package:ladimas/data/models/document_model.dart';
import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:ladimas/core/constants/app_constants.dart';
import 'package:ladimas/core/errors/exception.dart';
import 'package:ladimas/domain/entities/penduduk.dart';
import 'package:ladimas/data/models/penduduk_model.dart';
import 'package:ladimas/core/services/wilayah_service.dart';
import 'package:ladimas/data/models/family_member_model.dart';
import 'package:ladimas/core/services/persistent_cache_service.dart';

class PendudukApiService {
  final http.Client client;
  final WilayahService _wilayahService = WilayahService();
  final PersistentCacheService _persistent = PersistentCacheService();

  final Map<String, dynamic> _cache = {};
  final Map<String, DateTime> _cacheTimestamp = {};
  final Duration _cacheDuration = const Duration(minutes: 15);

  // Catatan: endpoint /all-citizens sudah tidak dipakai lagi (tidak scalable untuk 100k data).

  PendudukApiService({required this.client});

  Future<Penduduk> verifyLogin(String nik, String password) async {
    throw ServerException(
      message: 'Login now uses local database instead of API',
    );
  }

  Future<bool> registerPenduduk(
    String nik,
    String password,
    String noHp,
  ) async {
    throw ServerException(
      message: 'Registration now uses local database instead of API',
    );
  }

  Future<bool> checkNikExists(String nik) async {
    try {
      final uri = Uri.parse('${AppConstants.goBaseUrl}/api/v2/citizens/exists')
          .replace(queryParameters: {'nik': nik});

      final response = await client.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'X-API-Key': AppConstants.apiKey,
        },
      );

      if (response.statusCode != 200) {
        throw ServerException(
          message: 'Failed to check NIK: ${response.statusCode}',
        );
      }

      final dynamic responseData = json.decode(response.body);
      if (responseData is Map<String, dynamic>) {
        final data = responseData['data'];
        if (data is Map<String, dynamic> && data['exists'] != null) {
          return data['exists'] == true;
        }
      }

      throw ServerException(message: 'Format respons cek NIK tidak valid');
    } catch (e) {
      if (e is ServerException) {
        rethrow;
      }
      throw ServerException(message: 'Error checking NIK: ${e.toString()}');
    }
  }

  Future<PendudukModel?> getPendudukByNik(String nik) async {
    try {
      final detail = await getPendudukDetailByNik(nik);
      return PendudukModel(
        nik: detail['nik']?.toString() ?? nik,
        noHp: (detail['no_hp'] ?? detail['telephone'] ?? '').toString(),
        name: (detail['full_name'] ?? '').toString(),
      );
    } catch (e) {
      throw ServerException(
        message: 'Error fetching penduduk data: ${e.toString()}',
      );
    }
  }

  Future<List<Map<String, dynamic>>> getCitizensByVillageId(
      int villageId) async {
    try {
      // Ambil data lite dari server (paginated, payload kecil)
      final resp = await searchCitizensLite(
        villageId: villageId,
        search: '',
        page: 1,
        itemsPerPage: 200,
      );
      return resp;
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(
          message: 'Error fetching citizens: ${e.toString()}');
    }
  }

  Future<List<Map<String, dynamic>>> getCitizensByVillageIdLiteExtended(
      int villageId) async {
    try {
      final resp = await searchCitizensLite(
        villageId: villageId,
        search: '',
        page: 1,
        itemsPerPage: 200,
      );
      return resp;
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(
          message: 'Error fetching citizens (extended): ${e.toString()}');
    }
  }

  Future<List<Map<String, dynamic>>> getAllCitizensLite() async {
    try {
      return await searchCitizensLite(
        search: '',
        page: 1,
        itemsPerPage: 200,
      );
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(
          message: 'Error fetching citizens: ${e.toString()}');
    }
  }

  Future<List<Map<String, dynamic>>> getAllCitizensLiteExtended() async {
    try {
      return await searchCitizensLite(
        search: '',
        page: 1,
        itemsPerPage: 200,
      );
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(
          message: 'Error fetching citizens (extended): ${e.toString()}');
    }
  }

  /// Method cepat untuk mendapatkan KK saja tanpa memproses data lengkap
  /// Digunakan untuk mempercepat loading menu keluarga
  Future<String?> getKKByNik(String nik) async {
    try {
      final detail = await getPendudukDetailByNik(nik);
      final kk = detail['kk']?.toString() ?? '';
      return kk.isNotEmpty ? kk : null;
    } catch (e) {
      print('Error getting KK by NIK: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> getPendudukDetailByNik(String nik) async {
    try {
      final response = await client.get(
        Uri.parse('${AppConstants.goBaseUrl}/api/citizens/$nik'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'X-API-Key': AppConstants.apiKey,
        },
      );

      if (response.statusCode != 200) {
        throw ServerException(
          message: 'Gagal mengambil detail penduduk: ${response.statusCode}',
        );
      }

      final dynamic responseData = json.decode(response.body);
      final citizen = (responseData is Map<String, dynamic>)
          ? (responseData['data'] as Map<String, dynamic>?)
          : null;
      if (citizen == null) {
        throw ServerException(message: 'Format data penduduk tidak valid');
      }

      final provinceId = citizen['province_id'] ?? 0;
      final districtId = citizen['district_id'] ?? 0;
      final subDistrictId = citizen['sub_district_id'] ?? 0;
      final villageId = citizen['village_id'] ?? 0;

      final locationNames = await _getLocationNames(
        (provinceId is int) ? provinceId : int.tryParse('$provinceId') ?? 0,
        (districtId is int) ? districtId : int.tryParse('$districtId') ?? 0,
        (subDistrictId is int)
            ? subDistrictId
            : int.tryParse('$subDistrictId') ?? 0,
        (villageId is int) ? villageId : int.tryParse('$villageId') ?? 0,
      );

      return {
        'nik': citizen['nik']?.toString() ?? '',
        'kk': citizen['kk']?.toString() ?? '',
        'full_name': citizen['full_name'] ?? '',
        'gender': citizen['gender'] ?? '',
        'birth_date': citizen['birth_date'] ?? '',
        'age': citizen['age'] ?? 0,
        'birth_place': citizen['birth_place'] ?? '',
        'address': citizen['address'] ?? '',
        'province_id': provinceId,
        'district_id': districtId,
        'sub_district_id': subDistrictId,
        'village_id': villageId,
        'rt': citizen['rt'] ?? '',
        'rw': citizen['rw'] ?? '',
        'province_name': locationNames['province_name'],
        'district_name': locationNames['district_name'],
        'sub_district_name': locationNames['sub_district_name'],
        'village_name': locationNames['village_name'],
        'blood_type': citizen['blood_type'] ?? '',
        'education_status': citizen['education_status'] ?? '',
        'job_type_id': citizen['job_type_id'] ?? 0,
        'religion': citizen['religion'] ?? '',
        'marital_status': citizen['marital_status'] ?? '',
        'family_status': citizen['family_status'] ?? '',
        'citizen_status': citizen['citizen_status'] ?? '',
        'no_hp': citizen['telephone'] ?? '',
      };
    } catch (e) {
      if (e is ServerException) {
        rethrow;
      }
      throw ServerException(
        message: 'Error fetching penduduk data: ${e.toString()}',
      );
    }
  }

  /// Pencarian citizens ringan (server-side) untuk dropdown/autocomplete.
  /// Menghindari tarik `/all-citizens` yang berat untuk 100k data.
  Future<List<Map<String, dynamic>>> searchCitizensLite({
    required String search,
    int? villageId,
    int page = 1,
    int itemsPerPage = 50,
  }) async {
    try {
      final qp = <String, String>{
        'search': search,
        'page': page.toString(),
        'items_per_page': itemsPerPage.toString(),
      };
      if (villageId != null) {
        qp['village_id'] = villageId.toString();
      }

      final uri = Uri.parse('${AppConstants.goBaseUrl}/api/v2/citizens-lite')
          .replace(queryParameters: qp);

      final response = await client.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'X-API-Key': AppConstants.apiKey,
        },
      );

      if (response.statusCode != 200) {
        throw ServerException(
            message: 'Gagal mengambil daftar penduduk: ${response.statusCode}');
      }

      final dynamic jsonResp = json.decode(response.body);
      if (jsonResp is! Map<String, dynamic>) {
        throw ServerException(message: 'Format response tidak valid');
      }

      final data = jsonResp['data'];
      final citizens = (data is Map<String, dynamic>) ? data['citizens'] : null;
      if (citizens is! List) {
        return [];
      }

      return citizens.whereType<Map<String, dynamic>>().map((c) {
        return {
          'nik': c['nik']?.toString() ?? '',
          'full_name': (c['full_name'] ?? '').toString(),
          'kk': c['kk']?.toString() ?? '',
          'village_id': c['village_id'] ?? 0,
          'family_status': (c['family_status'] ?? '').toString(),
        };
      }).toList();
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(message: 'Gagal search penduduk: ${e.toString()}');
    }
  }

  Future<Map<String, String>> _getLocationNames(
    int provinceId,
    int districtId,
    int subDistrictId,
    int villageId,
  ) async {
    try {
      final provinceIdStr = provinceId.toString();
      final districtIdStr = districtId.toString();
      final subDistrictIdStr = subDistrictId.toString();
      final villageIdStr = villageId.toString();

      String provinceName = 'Provinsi';
      String districtName = 'Kabupaten/Kota';
      String subDistrictName = 'Kecamatan';
      String villageName = 'Desa/Kelurahan';

      try {
        final province = await _wilayahService.getProvince(provinceIdStr);
        if (province != null) {
          provinceName = province['name'] ?? provinceName;
        }

        final district = await _wilayahService.getDistrict(districtIdStr);
        if (district != null) {
          districtName = district['name'] ?? districtName;
        }

        final subDistrict = await _wilayahService.getSubDistrict(
          subDistrictIdStr,
          districtIdStr,
        );
        if (subDistrict != null) {
          subDistrictName = subDistrict['name'] ?? subDistrictName;
        }

        final village = await _wilayahService.getVillage(
          villageIdStr,
          subDistrictIdStr,
          districtIdStr,
        );
        if (village != null) {
          villageName = village['name'] ?? villageName;
        }
      } catch (e) {
        print('Error fetching location names: $e');
      }

      return {
        'province_name': provinceName,
        'district_name': districtName,
        'sub_district_name': subDistrictName,
        'village_name': villageName,
      };
    } catch (e) {
      return {
        'province_name': 'Provinsi',
        'district_name': 'Kabupaten/Kota',
        'sub_district_name': 'Kecamatan',
        'village_name': 'Desa/Kelurahan',
      };
    }
  }

  Future<List<FamilyMemberModel>> getFamilyMembers(String kk) async {
    final cacheKey = 'family_$kk';

    if (_cache.containsKey(cacheKey) && _cacheTimestamp.containsKey(cacheKey)) {
      final timestamp = _cacheTimestamp[cacheKey]!;
      final now = DateTime.now();
      if (now.difference(timestamp) < _cacheDuration) {
        return _cache[cacheKey] as List<FamilyMemberModel>;
      }
    }

    // Try persistent cache for cold start
    final persisted = await _persistent.getJson<List<dynamic>>(cacheKey);
    if (persisted != null) {
      final members = persisted
          .whereType<Map<String, dynamic>>()
          .map((member) => FamilyMemberModel.fromJson(member))
          .toList();
      _cache[cacheKey] = members;
      _cacheTimestamp[cacheKey] = DateTime.now();
      return members;
    }

    try {
      if (kk.isEmpty) {
        throw ValidationException(message: 'KK number cannot be empty');
      }

      final response = await client.get(
        Uri.parse('${AppConstants.goBaseUrl}/api/citizens-family/$kk'),
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': AppConstants.apiKey,
        },
      );

      if (response.statusCode == 200) {
        final dynamic responseData = json.decode(response.body);

        List<dynamic> familyData = [];
        if (responseData is List) {
          familyData = responseData;
        } else if (responseData is Map<String, dynamic> &&
            responseData.containsKey('data') &&
            responseData['data'] is List) {
          familyData = responseData['data'];
        }

        final members = familyData
            .map((member) => FamilyMemberModel.fromJson(member))
            .toList();

        _cache[cacheKey] = members;
        _cacheTimestamp[cacheKey] = DateTime.now();

        // Persist raw list to device for fast next launch
        await _persistent.setJson(cacheKey, familyData, ttl: _cacheDuration);

        return members;
      } else {
        throw ServerException(
          message: 'Failed to fetch family data: ${response.statusCode}',
        );
      }
    } catch (e) {
      if (e is ServerException || e is ValidationException) {
        rethrow;
      }

      throw ServerException(
        message: 'Error fetching family data: ${e.toString()}',
      );
    }
  }

  Future<bool> updateFamilyMemberCoordinate(
    String nik,
    String coordinate,
  ) async {
    try {
      await Future.delayed(const Duration(milliseconds: 500));

      _updateCoordinateInCache(nik, coordinate);

      return true;
    } catch (e) {
      throw ServerException(
        message: 'Error updating coordinates: ${e.toString()}',
      );
    }
  }

  Future<FamilyMemberDocuments> getFamilyMemberDocuments(String nik,
      {bool forceRefresh = false}) async {
    final cacheKey = 'documents_$nik';

    // Check cache first unless forced refresh
    if (!forceRefresh &&
        _cache.containsKey(cacheKey) &&
        _cacheTimestamp.containsKey(cacheKey)) {
      final timestamp = _cacheTimestamp[cacheKey]!;
      final now = DateTime.now();
      if (now.difference(timestamp) < _cacheDuration) {
        return _cache[cacheKey] as FamilyMemberDocuments;
      }
    }

    // Try persistent cache if not forced
    if (!forceRefresh) {
      final persisted =
          await _persistent.getJson<Map<String, dynamic>>(cacheKey);
      if (persisted != null) {
        final documents = FamilyMemberDocuments.fromJson(persisted);
        _cache[cacheKey] = documents;
        _cacheTimestamp[cacheKey] = DateTime.now();
        return documents;
      }
    }

    try {
      // Get auth token from storage
      final authLocalStorage = GetIt.instance<AuthLocalStorage>();
      final rawToken = await authLocalStorage.getStoredToken();

      if (rawToken == null || rawToken.isEmpty) {
        throw AuthException(
            message: 'Anda belum login atau sesi telah berakhir');
      }

      // Extract the token part after the pipe character
      String token = rawToken;
      if (rawToken.contains('|')) {
        final parts = rawToken.split('|');
        if (parts.length > 1) {
          token = parts[1];
        }
      }

      final response = await client.get(
        Uri.parse(
            '${AppConstants.authApiUrl}/user/family-member/$nik/documents'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);

        if (jsonResponse['success'] == true) {
          final documents =
              FamilyMemberDocuments.fromJson(jsonResponse['documents']);

          // Cache and persist the result
          _cache[cacheKey] = documents;
          _cacheTimestamp[cacheKey] = DateTime.now();
          await _persistent.setJson(cacheKey, jsonResponse['documents'],
              ttl: _cacheDuration);

          return documents;
        }

        throw ServerException(
            message: jsonResponse['message'] ?? 'Failed to fetch documents');
      } else if (response.statusCode == 401) {
        throw AuthException(message: 'Unauthorized: Invalid token');
      } else {
        throw ServerException(
            message: 'Failed to fetch documents: ${response.statusCode}');
      }
    } catch (e) {
      if (e is AuthException || e is ServerException) {
        rethrow;
      }
      throw ServerException(message: 'Document fetch error: ${e.toString()}');
    }
  }

  Future<DocumentModel> uploadFamilyMemberDocument(
      String nik, String documentType, File file) async {
    try {
      // Get auth token from storage
      final authLocalStorage = GetIt.instance<AuthLocalStorage>();
      final rawToken = await authLocalStorage.getStoredToken();

      if (rawToken == null || rawToken.isEmpty) {
        throw AuthException(
            message: 'Anda belum login atau sesi telah berakhir');
      }

      // Extract the token part after the pipe character
      String token = rawToken;
      if (rawToken.contains('|')) {
        final parts = rawToken.split('|');
        if (parts.length > 1) {
          token = parts[1];
        }
      }

      // Get file extension
      final String fileExtension = _getFileExtension(file.path);

      // Prepare the multipart request
      var request = http.MultipartRequest(
        'POST',
        Uri.parse(
            '${AppConstants.authApiUrl}/user/family-member/$nik/upload-document'),
      );

      // Add the authorization header with Bearer prefix - matching the GET request format
      request.headers['Accept'] = 'application/json';
      request.headers['Authorization'] = 'Bearer $token';

      // Add the document type
      request.fields['document_type'] = documentType;

      // Add the file
      var fileStream = http.ByteStream(file.openRead());
      var length = await file.length();
      var multipartFile = http.MultipartFile(
        'file',
        fileStream,
        length,
        filename: '$documentType.$fileExtension',
      );
      request.files.add(multipartFile);

      // Send the request
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);

        if (jsonResponse['success'] == true &&
            jsonResponse['document'] != null) {
          final cacheKey = 'documents_$nik';
          _cache.remove(cacheKey);
          _cacheTimestamp.remove(cacheKey);
          await _persistent.invalidate(cacheKey);

          return DocumentModel.fromJson(jsonResponse['document']);
        }

        throw ServerException(
            message: jsonResponse['message'] ?? 'Failed to upload document');
      } else if (response.statusCode == 401) {
        throw AuthException(message: 'Unauthorized: Invalid token');
      } else {
        throw ServerException(
            message: 'Failed to upload document: ${response.statusCode}');
      }
    } catch (e) {
      if (e is AuthException || e is ServerException) {
        rethrow;
      }
      throw ServerException(
          message: 'Failed to upload document: ${e.toString()}');
    }
  }

  String _getFileExtension(String fileName) {
    return fileName.contains('.') ? fileName.split('.').last : '';
  }

  Future<bool> deleteFamilyMemberDocument(
      String nik, String documentType) async {
    try {
      // Get auth token from storage
      final authLocalStorage = GetIt.instance<AuthLocalStorage>();
      final rawToken = await authLocalStorage.getStoredToken();

      if (rawToken == null || rawToken.isEmpty) {
        throw ServerException(message: 'Unauthorized: No token available');
      }

      // Extract the token part after the pipe character
      String token = rawToken;
      if (rawToken.contains('|')) {
        final parts = rawToken.split('|');
        if (parts.length > 1) {
          token = parts[1];
        }
      }

      final response = await client.delete(
        Uri.parse(
            '${AppConstants.authApiUrl}/user/family-member/$nik/delete-document/$documentType'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
          'X-API-Key': AppConstants.apiKey,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        // Remove from cache and persistent store
        final cacheKey = 'documents_$nik';
        if (_cache.containsKey(cacheKey)) {
          _cache.remove(cacheKey);
          _cacheTimestamp.remove(cacheKey);
        }
        await _persistent.invalidate(cacheKey);
        return true;
      } else if (response.statusCode == 401) {
        throw ServerException(message: 'Unauthorized: Invalid token');
      } else {
        throw ServerException(
            message: 'Failed to delete document: ${response.statusCode}');
      }
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(
          message: 'Failed to delete document: ${e.toString()}');
    }
  }

  void _updateCoordinateInCache(String nik, String coordinate) {
    _cache.forEach((key, value) {
      if (key.startsWith('family_') && value is List<FamilyMemberModel>) {
        for (int i = 0; i < value.length; i++) {
          if (value[i].nik == nik) {
            (value)[i] = value[i].copyWith(coordinate: coordinate);
          }
        }
      }
    });
  }

  // NOTE: _getAllCitizensCached() dan _fetchAndCacheAllCitizens() sengaja dihapus
  // untuk mencegah regresi performa (download massal 100k+ data).

  Future<bool> isHeadOfFamily(String nik) async {
    try {
      // Get the citizen's data to get their KK number
      final citizenData = await getPendudukDetailByNik(nik);
      final kk = citizenData['kk']?.toString() ?? '';

      if (kk.isEmpty) {
        throw ServerException(message: 'KK number not found for this NIK');
      }

      // Get all family members for this KK
      final familyMembers = await getFamilyMembers(kk);

      // Find the member with the given NIK and check if they are the head of family
      final member = familyMembers.firstWhere(
        (member) => member.nik == nik,
        orElse: () =>
            FamilyMemberModel(nik: '', fullName: '', familyStatus: ''),
      );

      // Check if this member's family status contains 'kepala keluarga'
      final isHeadOfFamily =
          member.familyStatus.toLowerCase().contains('kepala keluarga');
      return isHeadOfFamily;
    } catch (e) {
      if (e is ServerException || e is ValidationException) {
        rethrow;
      }
      throw ServerException(
        message: 'Error checking head of family status: ${e.toString()}',
      );
    }
  }

  void clearCache() {
    _cache.clear();
    _cacheTimestamp.clear();
  }
}
