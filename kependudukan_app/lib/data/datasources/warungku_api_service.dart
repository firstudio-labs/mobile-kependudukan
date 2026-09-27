import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:ladimas/core/constants/app_constants.dart';
import 'package:ladimas/core/errors/exception.dart';
import 'package:ladimas/data/datasources/auth_local_storage.dart';

class WarungkuApiService {
  final http.Client client;
  final AuthLocalStorage authLocalStorage;

  WarungkuApiService({required this.client, required this.authLocalStorage});

  Future<String> _getAuthToken() async {
    final token = await authLocalStorage.getStoredToken();
    if (token == null || token.isEmpty) {
      throw AuthException(message: 'Anda belum login atau sesi telah berakhir');
    }
    // Some tokens have format "id|token"
    if (token.contains('|')) {
      final parts = token.split('|');
      if (parts.length > 1) return parts[1];
    }
    return token;
  }

  Map<String, String> _headers(String token) => {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
        'X-API-Key': AppConstants.apiKey,
      };

  Uri _buildUri(String path, [Map<String, dynamic>? query]) {
    final base = '${AppConstants.authApiUrl}$path';
    if (query == null || query.isEmpty) return Uri.parse(base);
    final filtered = query.map((k, v) => MapEntry(k, v?.toString() ?? ''))
      ..removeWhere((k, v) => v.isEmpty);
    return Uri.parse(base).replace(queryParameters: filtered);
  }

  // GET /user/warungku
  Future<Map<String, dynamic>> getAll({
    String? search,
    int? perPage,
    int? page,
    String? klasifikasi,
    int? jenisId,
    String? provinceId,
    String? districtId,
    String? subDistrictId,
    String? villageId,
  }) async {
    final token = await _getAuthToken();
    final uri = _buildUri('/user/warungku', {
      'format': 'json',
      'search': search,
      'per_page': perPage,
      'page': page,
      'klasifikasi': klasifikasi,
      'jenis_id': jenisId,
      'province_id': provinceId,
      'district_id': districtId,
      'sub_district_id': subDistrictId,
      'village_id': villageId,
    });
    final res = await client.get(uri, headers: _headers(token)).timeout(
          NetworkConstants.defaultTimeout,
        );
    return _parseListingResponse(res);
  }

  // GET /user/warungku/my
  Future<Map<String, dynamic>> getMy({
    String? search,
    int? perPage,
    int? page,
    String? klasifikasi,
    int? jenisId,
  }) async {
    final token = await _getAuthToken();
    final uri = _buildUri('/user/warungku/my', {
      'format': 'json',
      'search': search,
      'per_page': perPage,
      'page': page,
      'klasifikasi': klasifikasi,
      'jenis_id': jenisId,
    });
    final res = await client.get(uri, headers: _headers(token)).timeout(
          NetworkConstants.defaultTimeout,
        );
    return _parseListingResponse(res);
  }

  Map<String, dynamic> _parseListingResponse(http.Response res) {
    if (res.statusCode == 200) {
      final Map<String, dynamic> body = json.decode(res.body);
      final dynamic data = body['data'];
      // data bisa berupa objek pagination { data: [...] } atau langsung list
      final List<dynamic> items = data is Map<String, dynamic>
          ? (data['data'] as List<dynamic>? ?? [])
          : (data as List<dynamic>? ?? []);
      return {'items': items, 'raw': body, 'filters': body['filters']};
    } else if (res.statusCode == 401) {
      throw AuthException(message: 'Tidak diizinkan: Token tidak valid');
    } else {
      throw ServerException(message: 'Gagal memuat data (${res.statusCode})');
    }
  }

  // GET /user/warungku/{id}
  Future<Map<String, dynamic>> getDetail(int id) async {
    final token = await _getAuthToken();
    final uri = _buildUri('/user/warungku/$id', {'format': 'json'});
    final res = await client.get(uri, headers: _headers(token)).timeout(
          NetworkConstants.defaultTimeout,
        );
    if (res.statusCode == 200) {
      final Map<String, dynamic> body = json.decode(res.body);
      return body['data'] as Map<String, dynamic>;
    } else if (res.statusCode == 401) {
      throw AuthException(message: 'Tidak diizinkan: Token tidak valid');
    }
    throw ServerException(message: 'Gagal memuat detail (${res.statusCode})');
  }

  // GET /user/warungku/{id}/edit - untuk edit form dengan data + filter
  Future<Map<String, dynamic>> getEditData(int id) async {
    final token = await _getAuthToken();
    final uri = _buildUri('/user/warungku/$id/edit', {'format': 'json'});
    final res = await client.get(uri, headers: _headers(token)).timeout(
          NetworkConstants.defaultTimeout,
        );
    print('🔍 Edit API Response Status: ${res.statusCode}');
    print('🔍 Edit API Response Body: ${res.body}');

    if (res.statusCode == 200) {
      final Map<String, dynamic> body = json.decode(res.body);
      return body;
    } else if (res.statusCode == 401) {
      throw AuthException(message: 'Tidak diizinkan: Token tidak valid');
    }
    throw ServerException(
        message: 'Gagal memuat data edit (${res.statusCode})');
  }

  // GET /user/warungku/filters -> klasifikasi & jenis
  Future<Map<String, dynamic>> getFilters() async {
    final token = await _getAuthToken();
    final uri = _buildUri('/user/warungku/filters');
    final res = await client.get(uri, headers: _headers(token)).timeout(
          NetworkConstants.defaultTimeout,
        );
    if (res.statusCode == 200) {
      return json.decode(res.body) as Map<String, dynamic>;
    } else if (res.statusCode == 401) {
      throw AuthException(message: 'Tidak diizinkan: Token tidak valid');
    }
    throw ServerException(message: 'Gagal memuat filter (${res.statusCode})');
  }

  // Wilayah options
  Future<List<dynamic>> getProvinces() async {
    final token = await _getAuthToken();
    final uri = _buildUri('/user/warungku/wilayah/provinces');
    final res = await client.get(uri, headers: _headers(token)).timeout(
          NetworkConstants.defaultTimeout,
        );
    if (res.statusCode == 200) {
      final Map<String, dynamic> body = json.decode(res.body);
      return (body['data'] as List<dynamic>? ?? []);
    }
    throw ServerException(message: 'Gagal memuat provinsi');
  }

  Future<List<dynamic>> getDistricts(String provinceCode) async {
    final token = await _getAuthToken();
    final uri = _buildUri('/user/warungku/wilayah/districts/$provinceCode');
    final res = await client.get(uri, headers: _headers(token)).timeout(
          NetworkConstants.defaultTimeout,
        );
    if (res.statusCode == 200) {
      final Map<String, dynamic> body = json.decode(res.body);
      return (body['data'] as List<dynamic>? ?? []);
    }
    throw ServerException(message: 'Gagal memuat kabupaten/kota');
  }

  Future<List<dynamic>> getSubDistricts(String districtCode) async {
    final token = await _getAuthToken();
    final uri = _buildUri('/user/warungku/wilayah/sub-districts/$districtCode');
    final res = await client.get(uri, headers: _headers(token)).timeout(
          NetworkConstants.defaultTimeout,
        );
    if (res.statusCode == 200) {
      final Map<String, dynamic> body = json.decode(res.body);
      return (body['data'] as List<dynamic>? ?? []);
    }
    throw ServerException(message: 'Gagal memuat kecamatan');
  }

  Future<List<dynamic>> getVillages(String subDistrictCode) async {
    final token = await _getAuthToken();
    final uri = _buildUri('/user/warungku/wilayah/villages/$subDistrictCode');
    final res = await client.get(uri, headers: _headers(token)).timeout(
          NetworkConstants.defaultTimeout,
        );
    if (res.statusCode == 200) {
      final Map<String, dynamic> body = json.decode(res.body);
      return (body['data'] as List<dynamic>? ?? []);
    }
    throw ServerException(message: 'Gagal memuat desa/kelurahan');
  }

  // POST /user/warungku (multipart karna foto)
  Future<bool> createProduct({
    required String namaProduk,
    int? jenisMasterId,
    String? deskripsi,
    required int harga,
    required int stok,
    File? foto,
  }) async {
    final token = await _getAuthToken();
    final uri = _buildUri('/user/warungku');
    final req = http.MultipartRequest('POST', uri);
    req.headers.addAll(_headers(token));
    req.fields['nama_produk'] = namaProduk;
    if (jenisMasterId != null) req.fields['jenis_master_id'] = '$jenisMasterId';
    if (deskripsi != null) req.fields['deskripsi'] = deskripsi;
    req.fields['harga'] = '$harga';
    req.fields['stok'] = '$stok';
    if (foto != null) {
      try {
        if (await foto.exists()) {
          req.files.add(await http.MultipartFile.fromPath('foto', foto.path));
        }
      } catch (_) {}
    }
    final res = await http.Response.fromStream(await req.send());
    if (res.statusCode == 201 || res.statusCode == 200) return true;
    if (res.statusCode == 401) {
      throw AuthException(message: 'Tidak diizinkan: Token tidak valid');
    }
    throw ServerException(message: 'Gagal membuat produk (${res.statusCode})');
  }

  // POST /user/warungku/{id}
  Future<bool> updateProduct({
    required int id,
    required String namaProduk,
    int? klasifikasiMasterId,
    int? jenisMasterId,
    String? deskripsi,
    required int harga,
    required int stok,
    File? foto,
  }) async {
    final token = await _getAuthToken();
    final uri = _buildUri('/user/warungku/$id');
    final req = http.MultipartRequest('POST', uri);
    req.headers.addAll(_headers(token));
    req.fields['nama_produk'] = namaProduk;
    if (klasifikasiMasterId != null) {
      req.fields['klasifikasi_master_id'] = '$klasifikasiMasterId';
    }
    if (jenisMasterId != null) req.fields['jenis_master_id'] = '$jenisMasterId';
    if (deskripsi != null) req.fields['deskripsi'] = deskripsi;
    req.fields['harga'] = '$harga';
    req.fields['stok'] = '$stok';
    if (foto != null) {
      try {
        if (await foto.exists()) {
          req.files.add(await http.MultipartFile.fromPath('foto', foto.path));
        }
      } catch (_) {}
    }
    final res = await http.Response.fromStream(await req.send());
    if (res.statusCode == 200) return true;
    if (res.statusCode == 401) {
      throw AuthException(message: 'Tidak diizinkan: Token tidak valid');
    }
    throw ServerException(
        message: 'Gagal memperbarui produk (${res.statusCode})');
  }

  // DELETE /user/warungku/{id}
  Future<bool> deleteProduct(int id) async {
    final token = await _getAuthToken();
    final uri = _buildUri('/user/warungku/$id');
    final res = await client.delete(uri, headers: _headers(token)).timeout(
          NetworkConstants.defaultTimeout,
        );
    if (res.statusCode == 200) return true;
    if (res.statusCode == 401) {
      throw AuthException(message: 'Tidak diizinkan: Token tidak valid');
    }
    throw ServerException(
        message: 'Gagal menghapus produk (${res.statusCode})');
  }

  // Dropdown khusus form: klasifikasi list
  Future<List<String>> getKlasifikasiList() async {
    final token = await _getAuthToken();
    final uri = _buildUri('/user/warungku/filters/klasifikasi');
    final res = await client.get(uri, headers: _headers(token)).timeout(
          NetworkConstants.defaultTimeout,
        );
    if (res.statusCode == 200) {
      final Map<String, dynamic> body = json.decode(res.body);
      final List<dynamic> data = body['data'] as List<dynamic>? ?? [];
      return data.map((e) => e.toString()).toList();
    } else if (res.statusCode == 401) {
      throw AuthException(message: 'Tidak diizinkan: Token tidak valid');
    }
    throw ServerException(
        message: 'Gagal memuat klasifikasi (${res.statusCode})');
  }

  // Dropdown khusus form: jenis by klasifikasi
  Future<List<Map<String, dynamic>>> getJenisByKlasifikasi(
      String klasifikasi) async {
    final token = await _getAuthToken();
    final uri = _buildUri('/user/warungku/filters/jenis', {
      'klasifikasi': klasifikasi,
    });
    final res = await client.get(uri, headers: _headers(token)).timeout(
          NetworkConstants.defaultTimeout,
        );
    if (res.statusCode == 200) {
      final Map<String, dynamic> body = json.decode(res.body);
      final List<dynamic> data = body['data'] as List<dynamic>? ?? [];
      return data
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
    } else if (res.statusCode == 401) {
      throw AuthException(message: 'Tidak diizinkan: Token tidak valid');
    }
    throw ServerException(message: 'Gagal memuat jenis (${res.statusCode})');
  }
}
