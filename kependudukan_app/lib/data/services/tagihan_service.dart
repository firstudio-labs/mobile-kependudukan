import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/tagihan_model.dart';
import 'package:ladimas/core/constants/app_constants.dart';

class TagihanService {
  final String token;

  TagihanService({required this.token});

  String get _baseUrl {
    // authApiUrl biasanya sudah include `/api`
    // endpoint tagihan berada di `/api/user/...`
    var base = AppConstants.authApiUrl.trim();
    if (base.endsWith('/')) base = base.substring(0, base.length - 1);
    if (base.isEmpty) {
      // fallback lama (production) kalau .env belum diset
      return 'https://pelayanan.desaverse.id/api/user';
    }
    return '$base/user';
  }

  String get _bearerToken {
    // beberapa token tersimpan sebagai "id|token"
    final t = token.trim();
    if (t.contains('|')) return t.split('|').last.trim();
    return t;
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $_bearerToken',
        'X-API-Key': AppConstants.apiKey,
      };

  /// Mendapatkan daftar tagihan dengan filter
  Future<TagihanResponse> getTagihan({
    String? status,
    int? bulan,
    int? tahun,
    int? kategoriId,
    int? subKategoriId,
    String? startDate, // format: YYYY-MM-DD
    String? endDate, // format: YYYY-MM-DD
    int perPage = 10,
  }) async {
    try {
      final Map<String, String> queryParams = {
        'per_page': perPage.toString(),
      };

      if (status != null && status.isNotEmpty) {
        queryParams['status'] = status;
      }
      if (bulan != null) {
        queryParams['bulan'] = bulan.toString();
      }
      if (tahun != null) {
        queryParams['tahun'] = tahun.toString();
      }
      if (kategoriId != null) {
        queryParams['kategori_id'] = kategoriId.toString();
      }
      if (subKategoriId != null) {
        queryParams['sub_kategori_id'] = subKategoriId.toString();
      }
      if (startDate != null && startDate.isNotEmpty) {
        queryParams['start_date'] = startDate;
      }
      if (endDate != null && endDate.isNotEmpty) {
        queryParams['end_date'] = endDate;
      }

      final uri = Uri.parse('$_baseUrl/tagihan').replace(
        queryParameters: queryParams,
      );

      final response =
          await http.get(uri, headers: _headers).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);
        return TagihanResponse.fromJson(jsonData);
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized: Token tidak valid');
      } else {
        throw Exception(
            'Gagal mengambil data tagihan: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  /// Mendapatkan detail tagihan berdasarkan ID
  Future<TagihanDetailResponse> getTagihanDetail(int tagihanId) async {
    try {
      final uri = Uri.parse('$_baseUrl/tagihan/$tagihanId');
      final response =
          await http.get(uri, headers: _headers).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);
        return TagihanDetailResponse.fromJson(jsonData);
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized: Token tidak valid');
      } else if (response.statusCode == 403) {
        throw Exception('Forbidden: Anda tidak memiliki akses ke tagihan ini');
      } else if (response.statusCode == 404) {
        throw Exception('Tagihan tidak ditemukan');
      } else {
        throw Exception(
            'Gagal mengambil detail tagihan: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  /// Mendapatkan daftar kategori tagihan
  Future<KategoriTagihanResponse> getKategoriTagihan() async {
    try {
      final uri = Uri.parse('$_baseUrl/tagihan-kategori');
      final response =
          await http.get(uri, headers: _headers).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);
        return KategoriTagihanResponse.fromJson(jsonData);
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized: Token tidak valid');
      } else {
        throw Exception(
            'Gagal mengambil kategori tagihan: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  /// Helper method untuk mendapatkan label status dalam bahasa Indonesia
  String getStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'belum_bayar':
        return 'Belum Bayar';
      case 'sudah_bayar':
        return 'Sudah Bayar';
      case 'terlambat':
        return 'Terlambat';
      case 'dibatalkan':
        return 'Dibatalkan';
      case 'pending':
        return 'Menunggu';
      case 'lunas':
        return 'Lunas';
      case 'belum_lunas':
        return 'Belum Lunas';
      default:
        return status;
    }
  }

  /// Helper method untuk mendapatkan warna status
  String getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'belum_bayar':
      case 'belum_lunas':
        return 'red';
      case 'sudah_bayar':
      case 'lunas':
        return 'green';
      case 'terlambat':
        return 'orange';
      case 'dibatalkan':
        return 'grey';
      case 'pending':
        return 'blue';
      default:
        return 'grey';
    }
  }

  /// Helper method untuk format tanggal
  String formatTanggal(String tanggal) {
    try {
      final DateTime date = DateTime.parse(tanggal);
      final List<String> bulan = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'Mei',
        'Jun',
        'Jul',
        'Agu',
        'Sep',
        'Okt',
        'Nov',
        'Des'
      ];

      return '${date.day} ${bulan[date.month - 1]} ${date.year}';
    } catch (e) {
      return tanggal;
    }
  }

  /// Helper method untuk format nominal
  String formatNominal(double nominal) {
    if (nominal >= 1000000) {
      return 'Rp ${(nominal / 1000000).toStringAsFixed(1)}M';
    } else if (nominal >= 1000) {
      return 'Rp ${(nominal / 1000).toStringAsFixed(0)}K';
    } else {
      return 'Rp ${nominal.toStringAsFixed(0)}';
    }
  }
}
