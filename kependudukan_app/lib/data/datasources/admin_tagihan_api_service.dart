import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:ladimas/core/constants/app_constants.dart';
import 'package:ladimas/core/error/exceptions.dart';
import 'package:ladimas/data/datasources/auth_local_storage.dart';

class AdminTagihanApiService {
  final http.Client client;
  final AuthLocalStorage authLocalStorage;

  AdminTagihanApiService(
      {required this.client, required this.authLocalStorage});

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

  Map<String, String> _headers(String bearer) => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $bearer',
        'X-API-Key': AppConstants.apiKey,
      };

  // TAGIHAN CRUD
  Future<Map<String, dynamic>> listTagihan({
    String? status,
    String? search,
    int? bulan,
    int? tahun,
    int? kategoriId,
    int? subKategoriId,
    String? startDate,
    String? endDate,
    int page = 1,
    int perPage = 10,
  }) async {
    final bearer = await _getAuthToken();
    final q = <String, String>{
      'page': '$page',
      'per_page': '$perPage',
    };
    if (status != null && status.isNotEmpty) q['status'] = status;
    if (search != null && search.isNotEmpty) q['search'] = search;
    if (bulan != null) q['bulan'] = '$bulan';
    if (tahun != null) q['tahun'] = '$tahun';
    if (kategoriId != null) q['kategori_id'] = '$kategoriId';
    if (subKategoriId != null) q['sub_kategori_id'] = '$subKategoriId';
    if (startDate != null && startDate.isNotEmpty) q['start_date'] = startDate;
    if (endDate != null && endDate.isNotEmpty) q['end_date'] = endDate;
    final uri = Uri.parse('${AppConstants.authApiUrl}/user/admin/tagihan')
        .replace(queryParameters: q);
    final resp = await client
        .get(uri, headers: _headers(bearer))
        .timeout(NetworkConstants.defaultTimeout);
    if (resp.statusCode == 200) {
      return json.decode(resp.body) as Map<String, dynamic>;
    }
    if (resp.statusCode == 401) throw AuthException(message: 'Unauthorized');
    throw ServerException(message: 'Gagal memuat tagihan: ${resp.statusCode}');
  }

  Future<Map<String, dynamic>> createTagihan(
      Map<String, dynamic> payload) async {
    final bearer = await _getAuthToken();
    final resp = await client
        .post(
          Uri.parse('${AppConstants.authApiUrl}/user/admin/tagihan'),
          headers: _headers(bearer),
          body: json.encode(payload),
        )
        .timeout(NetworkConstants.defaultTimeout);
    if (resp.statusCode == 201 || resp.statusCode == 200) {
      return json.decode(resp.body) as Map<String, dynamic>;
    }
    if (resp.statusCode == 401) throw AuthException(message: 'Unauthorized');
    throw ServerException(message: 'Gagal membuat tagihan: ${resp.statusCode}');
  }

  Future<Map<String, dynamic>> updateTagihan(
      int id, Map<String, dynamic> payload) async {
    final bearer = await _getAuthToken();
    final resp = await client
        .put(
          Uri.parse('${AppConstants.authApiUrl}/user/admin/tagihan/$id'),
          headers: _headers(bearer),
          body: json.encode(payload),
        )
        .timeout(NetworkConstants.defaultTimeout);
    if (resp.statusCode == 200) {
      return json.decode(resp.body) as Map<String, dynamic>;
    }
    if (resp.statusCode == 401) throw AuthException(message: 'Unauthorized');
    throw ServerException(
        message: 'Gagal memperbarui tagihan: ${resp.statusCode}');
  }

  Future<Map<String, dynamic>> createMultipleTagihan(
      {required List<String> selectedNiks,
      required int kategoriId,
      required int subKategoriId,
      double? nominal,
      String? keterangan,
      required String status,
      required String tanggal}) async {
    final bearer = await _getAuthToken();
    final uri = Uri.parse(
        '${AppConstants.authApiUrl}/user/admin/tagihan/store-multiple');
    final payload = {
      'selected_niks': selectedNiks,
      'kategori_id': kategoriId,
      'sub_kategori_id': subKategoriId,
      'nominal': nominal,
      'keterangan': keterangan,
      'status': status,
      'tanggal': tanggal,
    };
    final resp = await client
        .post(uri, headers: _headers(bearer), body: json.encode(payload))
        .timeout(NetworkConstants.defaultTimeout);
    if (resp.statusCode == 201 || resp.statusCode == 200) {
      return json.decode(resp.body) as Map<String, dynamic>;
    }
    if (resp.statusCode == 401) throw AuthException(message: 'Unauthorized');
    throw ServerException(
        message: 'Gagal membuat banyak tagihan: ${resp.statusCode}');
  }

  Future<void> deleteTagihan(int id) async {
    final bearer = await _getAuthToken();
    final resp = await client
        .delete(
          Uri.parse('${AppConstants.authApiUrl}/user/admin/tagihan/$id'),
          headers: _headers(bearer),
        )
        .timeout(NetworkConstants.defaultTimeout);
    if (resp.statusCode == 200) return;
    if (resp.statusCode == 401) throw AuthException(message: 'Unauthorized');
    throw ServerException(
        message: 'Gagal menghapus tagihan: ${resp.statusCode}');
  }

  Future<Map<String, dynamic>> updateStatus(int id, String status) async {
    final bearer = await _getAuthToken();
    final resp = await client
        .post(
          Uri.parse('${AppConstants.authApiUrl}/user/admin/tagihan/$id/status'),
          headers: _headers(bearer),
          body: json.encode({'status': status}),
        )
        .timeout(NetworkConstants.defaultTimeout);
    if (resp.statusCode == 200) {
      return json.decode(resp.body) as Map<String, dynamic>;
    }
    if (resp.statusCode == 401) throw AuthException(message: 'Unauthorized');
    throw ServerException(
        message: 'Gagal memperbarui status: ${resp.statusCode}');
  }

  // KATEGORI & SUB KATEGORI
  Future<List<dynamic>> kategori() async {
    final bearer = await _getAuthToken();
    final resp = await client
        .get(
            Uri.parse('${AppConstants.authApiUrl}/user/admin/tagihan/kategori'),
            headers: _headers(bearer))
        .timeout(NetworkConstants.defaultTimeout);
    if (resp.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(resp.body);
      return (data['data'] as List?) ?? [];
    }
    // fallback ke kategoriIndex jika endpoint ini tidak tersedia
    try {
      return await kategoriIndex(page: 1, perPage: 100);
    } catch (_) {
      throw ServerException(
          message: 'Gagal memuat kategori: ${resp.statusCode}');
    }
  }

  Future<List<dynamic>> kategoriIndex(
      {String? search, int page = 1, int perPage = 10}) async {
    final bearer = await _getAuthToken();
    final q = <String, String>{'page': '$page', 'per_page': '$perPage'};
    if (search != null && search.isNotEmpty) q['search'] = search;
    final uri =
        Uri.parse('${AppConstants.authApiUrl}/user/admin/tagihan/kategori-only')
            .replace(queryParameters: q);
    final resp = await client
        .get(uri, headers: _headers(bearer))
        .timeout(NetworkConstants.defaultTimeout);
    if (resp.statusCode == 200) {
      final decoded = json.decode(resp.body);
      if (decoded is Map<String, dynamic>) {
        final data = decoded['data'];
        if (data is List) return data;
        if (data is Map<String, dynamic>) {
          final items = data['data'];
          if (items is List) return items;
        }
      }
      return [];
    }
    if (resp.statusCode == 404) return [];
    throw ServerException(
        message: 'Gagal memuat kategori-index: ${resp.statusCode}');
  }

  Future<List<dynamic>> subKategoriByKategori(int kategoriId) async {
    final bearer = await _getAuthToken();
    final resp = await client
        .get(
            Uri.parse(
                '${AppConstants.authApiUrl}/user/admin/tagihan/kategori/$kategoriId/sub'),
            headers: _headers(bearer))
        .timeout(NetworkConstants.defaultTimeout);
    if (resp.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(resp.body);
      return (data['data'] as List?) ?? [];
    }
    throw ServerException(message: 'Gagal memuat sub kategori');
  }

  Future<List<dynamic>> subKategoriIndex(
      {int? kategoriId, String? search, int page = 1, int perPage = 10}) async {
    final bearer = await _getAuthToken();
    final q = <String, String>{'page': '$page', 'per_page': '$perPage'};
    if (kategoriId != null) q['kategori_id'] = '$kategoriId';
    if (search != null && search.isNotEmpty) q['search'] = search;
    final uri = Uri.parse(
            '${AppConstants.authApiUrl}/user/admin/tagihan/sub-kategori-only')
        .replace(queryParameters: q);
    final resp = await client
        .get(uri, headers: _headers(bearer))
        .timeout(NetworkConstants.defaultTimeout);
    if (resp.statusCode == 200) {
      final decoded = json.decode(resp.body);
      if (decoded is Map<String, dynamic>) {
        final data = decoded['data'];
        if (data is List) return data;
        if (data is Map<String, dynamic>) {
          final items = data['data'];
          if (items is List) return items;
        }
      }
      return [];
    }
    if (resp.statusCode == 404) return [];
    throw ServerException(
        message: 'Gagal memuat sub-kategori-index: ${resp.statusCode}');
  }

  Future<Map<String, dynamic>> createKategori(String nama) async {
    final bearer = await _getAuthToken();
    final resp = await client
        .post(
            Uri.parse('${AppConstants.authApiUrl}/user/admin/tagihan/kategori'),
            headers: _headers(bearer),
            body: json.encode({'nama_kategori': nama}))
        .timeout(NetworkConstants.defaultTimeout);
    if (resp.statusCode == 201 || resp.statusCode == 200) {
      return json.decode(resp.body) as Map<String, dynamic>;
    }
    throw ServerException(message: 'Gagal membuat kategori');
  }

  Future<Map<String, dynamic>> updateKategori(int id, String nama) async {
    final bearer = await _getAuthToken();
    final resp = await client
        .put(
            Uri.parse(
                '${AppConstants.authApiUrl}/user/admin/tagihan/kategori/$id'),
            headers: _headers(bearer),
            body: json.encode({'nama_kategori': nama}))
        .timeout(NetworkConstants.defaultTimeout);
    if (resp.statusCode == 200) {
      return json.decode(resp.body) as Map<String, dynamic>;
    }
    throw ServerException(message: 'Gagal memperbarui kategori');
  }

  Future<void> deleteKategori(int id) async {
    final bearer = await _getAuthToken();
    final resp = await client
        .delete(
            Uri.parse(
                '${AppConstants.authApiUrl}/user/admin/tagihan/kategori/$id'),
            headers: _headers(bearer))
        .timeout(NetworkConstants.defaultTimeout);
    if (resp.statusCode == 200) return;
    throw ServerException(message: 'Gagal menghapus kategori');
  }

  Future<Map<String, dynamic>> createSubKategori(
      int kategoriId, String nama) async {
    final bearer = await _getAuthToken();
    final resp = await client
        .post(
            Uri.parse(
                '${AppConstants.authApiUrl}/user/admin/tagihan/sub-kategori'),
            headers: _headers(bearer),
            body: json
                .encode({'kategori_id': kategoriId, 'nama_sub_kategori': nama}))
        .timeout(NetworkConstants.defaultTimeout);
    if (resp.statusCode == 201 || resp.statusCode == 200) {
      return json.decode(resp.body) as Map<String, dynamic>;
    }
    throw ServerException(message: 'Gagal membuat sub kategori');
  }

  Future<Map<String, dynamic>> updateSubKategori(
      int id, int kategoriId, String nama) async {
    final bearer = await _getAuthToken();
    final resp = await client
        .put(
            Uri.parse(
                '${AppConstants.authApiUrl}/user/admin/tagihan/sub-kategori/$id'),
            headers: _headers(bearer),
            body: json
                .encode({'kategori_id': kategoriId, 'nama_sub_kategori': nama}))
        .timeout(NetworkConstants.defaultTimeout);
    if (resp.statusCode == 200) {
      return json.decode(resp.body) as Map<String, dynamic>;
    }
    throw ServerException(message: 'Gagal memperbarui sub kategori');
  }

  Future<void> deleteSubKategori(int id) async {
    final bearer = await _getAuthToken();
    final resp = await client
        .delete(
            Uri.parse(
                '${AppConstants.authApiUrl}/user/admin/tagihan/sub-kategori/$id'),
            headers: _headers(bearer))
        .timeout(NetworkConstants.defaultTimeout);
    if (resp.statusCode == 200) return;
    throw ServerException(message: 'Gagal menghapus sub kategori');
  }

  Future<List<dynamic>> dropdownKategori() async {
    final bearer = await _getAuthToken();
    final resp = await client
        .get(
            Uri.parse(
                '${AppConstants.authApiUrl}/user/admin/tagihan/dropdown/kategori'),
            headers: _headers(bearer))
        .timeout(NetworkConstants.defaultTimeout);
    if (resp.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(resp.body);
      return (data['data'] as List?) ?? [];
    }
    throw ServerException(message: 'Gagal memuat dropdown kategori');
  }

  Future<List<dynamic>> dropdownSubKategori(int kategoriId) async {
    final bearer = await _getAuthToken();
    final uri = Uri.parse(
            '${AppConstants.authApiUrl}/user/admin/tagihan/dropdown/sub-kategori')
        .replace(queryParameters: {'kategori_id': '$kategoriId'});
    final resp = await client
        .get(uri, headers: _headers(bearer))
        .timeout(NetworkConstants.defaultTimeout);
    if (resp.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(resp.body);
      return (data['data'] as List?) ?? [];
    }
    throw ServerException(message: 'Gagal memuat dropdown sub kategori');
  }
}
