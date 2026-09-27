import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:ladimas/core/constants/app_constants.dart';
import 'package:ladimas/core/errors/exception.dart';
import 'package:ladimas/data/datasources/auth_local_storage.dart';
import 'package:ladimas/data/models/asset_model.dart';
import 'package:ladimas/core/services/wilayah_service.dart';

class AssetApiService {
  final http.Client client;
  final AuthLocalStorage authLocalStorage;
  final WilayahService _wilayahService = WilayahService();

  List<AssetModel>? _cachedAssets;
  String? _lastUsedToken;

  AssetApiService({
    required this.client,
    required this.authLocalStorage,
  });

  Future<String> _getAuthToken() async {
    final token = await authLocalStorage.getStoredToken();
    if (token == null || token.isEmpty) {
      throw AuthException(message: 'Anda belum login atau sesi telah berakhir');
    }

    if (_lastUsedToken != null && _lastUsedToken != token) {
      clearCache();
    }

    _lastUsedToken = token;

    if (token.contains('|')) {
      final parts = token.split('|');
      if (parts.length > 1) {
        return parts[1];
      }
    }

    return token;
  }

  Future<AssetModel> _populateLocationNames(AssetModel asset) async {
    try {
      String provinceName = '';
      String districtName = '';
      String subdistrictName = '';
      String villageName = '';

      if (asset.provinceId != null) {
        final province =
            await _wilayahService.getProvince(asset.provinceId.toString());
        if (province != null) {
          provinceName = province['name'] ?? '';
        }
      }

      if (asset.districtId != null) {
        final district =
            await _wilayahService.getDistrict(asset.districtId.toString());
        if (district != null) {
          districtName = district['name'] ?? '';
        }
      }

      if (asset.subdistrictId != null) {
        final subdistrict = await _wilayahService.getSubDistrict(
          asset.subdistrictId.toString(),
          asset.districtId?.toString(),
        );
        if (subdistrict != null) {
          subdistrictName = subdistrict['name'] ?? '';
        }
      }

      if (asset.villageId != null) {
        final village = await _wilayahService.getVillage(
          asset.villageId.toString(),
          asset.subdistrictId?.toString(),
          asset.districtId?.toString(),
        );
        if (village != null) {
          villageName = village['name'] ?? '';
        }
      }

      return AssetModel(
        id: asset.id,
        namaAset: asset.namaAset,
        namaPemilik: asset.namaPemilik,
        nikPemilik: asset.nikPemilik,
        alamat: asset.alamat,
        fotoDepan: asset.fotoDepan,
        fotoSamping: asset.fotoSamping,
        tagLokasi: asset.tagLokasi,
        klasifikasi: asset.klasifikasi,
        jenisAset: asset.jenisAset,
        rt: asset.rt,
        rw: asset.rw,
        provinceName: provinceName,
        districtName: districtName,
        subdistrictName: subdistrictName,
        villageName: villageName,
        klasifikasiDetail: asset.klasifikasiDetail,
        jenisAsetDetail: asset.jenisAsetDetail,
        createdAt: asset.createdAt,
        provinceId: asset.provinceId,
        districtId: asset.districtId,
        subdistrictId: asset.subdistrictId,
        villageId: asset.villageId,
      );
    } catch (e) {
      print('Error populating location names: $e');
      return asset;
    }
  }

  Future<List<AssetModel>> getAssets() async {
    try {
      if (_cachedAssets != null) {
        return _cachedAssets!;
      }
      final authToken = await _getAuthToken();

      final response = await client.get(
        Uri.parse('${AppConstants.authApiUrl}/user/kelola-aset'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
      );

      if (response.statusCode == 200) {
        final dynamic jsonResponse = json.decode(response.body);

        if (jsonResponse['status'] == "success") {
          if (jsonResponse['data'] is List) {
            final List<dynamic> assetList = jsonResponse['data'];
            final assets = await Future.wait(
              assetList.map((assetJson) async {
                final asset = AssetModel.fromJson(assetJson);
                return await _populateLocationNames(asset);
              }),
            );

            _cachedAssets = assets;
            return assets;
          } else {
            throw ServerException(
                message: 'Format data dari server tidak sesuai');
          }
        } else {
          throw ServerException(
              message: jsonResponse['message'] ?? 'Gagal mendapatkan aset');
        }
      } else if (response.statusCode == 401) {
        throw AuthException(message: 'Unauthorized: Invalid token');
      } else {
        throw ServerException(
            message: 'Gagal mendapatkan aset. Status: ${response.statusCode}');
      }
    } catch (e) {
      if (e is AuthException || e is ServerException) {
        rethrow;
      }
      throw ServerException(message: 'Failed to get assets: ${e.toString()}');
    }
  }

  Future<AssetModel> getAssetDetail(int id) async {
    try {
      final authToken = await _getAuthToken();

      final response = await client.get(
        Uri.parse('${AppConstants.authApiUrl}/user/kelola-aset'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);
        if (jsonResponse['status'] == 'success') {
          final List<dynamic> assetsData = jsonResponse['data'];
          final assetData = assetsData.firstWhere((asset) => asset['id'] == id,
              orElse: () => throw ServerException(message: 'Asset not found'));
          final asset = AssetModel.fromJson(assetData);
          return await _populateLocationNames(asset);
        } else {
          throw ServerException(
              message: jsonResponse['message'] ?? 'Unknown error');
        }
      } else if (response.statusCode == 401) {
        throw AuthException(message: 'Unauthorized: Invalid token');
      } else {
        throw ServerException(message: 'Server error: ${response.statusCode}');
      }
    } catch (e) {
      if (e is AuthException || e is ServerException) {
        rethrow;
      }
      throw ServerException(
          message: 'Failed to get asset detail: ${e.toString()}');
    }
  }

  Future<bool> createAsset(Map<String, dynamic> assetData) async {
    try {
      final authToken = await _getAuthToken();

      final response = await client.post(
        Uri.parse('${AppConstants.authApiUrl}/user/kelola-aset'),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(assetData),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final dynamic jsonResponse = json.decode(response.body);

        if (jsonResponse['status'] == "success") {
          _cachedAssets = null;
          return true;
        } else {
          throw ServerException(
              message: jsonResponse['message'] ?? 'Gagal membuat asset');
        }
      } else if (response.statusCode == 401) {
        throw AuthException(message: 'Tidak diizinkan: Token tidak valid');
      } else if (response.statusCode == 422) {
        final dynamic jsonResponse = json.decode(response.body);
        throw ServerException(
            message: jsonResponse['message'] ?? 'Terjadi kesalahan validasi');
      } else {
        throw ServerException(
            message: 'Gagal membuat asset: ${response.statusCode}');
      }
    } catch (e) {
      if (e is AuthException || e is ServerException) {
        rethrow;
      }
      throw ServerException(message: 'Gagal membuat asset: ${e.toString()}');
    }
  }

  Future<bool> createAssetWithImages(
      Map<String, dynamic> assetData, File? fotoDpn, File? fotoSamping) async {
    try {
      final authToken = await _getAuthToken();

      // Buat request multipart
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${AppConstants.authApiUrl}/user/kelola-aset'),
      );

      // Tambahkan headers
      request.headers['Authorization'] = 'Bearer $authToken';
      request.headers['Accept'] = 'application/json';

      // Tambahkan field teks dari assetData
      assetData.forEach((key, value) {
        if (value != null) {
          request.fields[key] = value.toString();
        }
      });

      // Tambahkan file gambar jika ada
      if (fotoDpn != null) {
        var frontStream = http.ByteStream(fotoDpn.openRead());
        var frontLength = await fotoDpn.length();
        var frontMultipartFile = http.MultipartFile(
          'foto_aset_depan',
          frontStream,
          frontLength,
          filename: '${DateTime.now().millisecondsSinceEpoch}_depan.jpg',
        );
        request.files.add(frontMultipartFile);
      }

      if (fotoSamping != null) {
        var sideStream = http.ByteStream(fotoSamping.openRead());
        var sideLength = await fotoSamping.length();
        var sideMultipartFile = http.MultipartFile(
          'foto_aset_samping',
          sideStream,
          sideLength,
          filename: '${DateTime.now().millisecondsSinceEpoch}_samping.jpg',
        );
        request.files.add(sideMultipartFile);
      }

      // Kirim request
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201 || response.statusCode == 200) {
        final dynamic jsonResponse = json.decode(response.body);

        if (jsonResponse['status'] == "success") {
          // Bersihkan cache untuk memastikan data segar saat pengambilan berikutnya
          _cachedAssets = null;
          return true;
        } else {
          throw ServerException(
              message: jsonResponse['message'] ?? 'Gagal membuat asset');
        }
      } else if (response.statusCode == 401) {
        throw AuthException(message: 'Tidak diizinkan: Token tidak valid');
      } else if (response.statusCode == 422) {
        // Error validasi
        final dynamic jsonResponse = json.decode(response.body);
        throw ServerException(
            message: jsonResponse['message'] ?? 'Terjadi kesalahan validasi');
      } else {
        throw ServerException(
            message: 'Gagal membuat asset: ${response.statusCode}');
      }
    } catch (e) {
      if (e is AuthException || e is ServerException) {
        rethrow;
      }
      throw ServerException(
          message: 'Gagal membuat asset dengan gambar: ${e.toString()}');
    }
  }

  Future<bool> updateAsset(int id, Map<String, dynamic> assetData) async {
    try {
      final authToken = await _getAuthToken();

      final response = await client.put(
        Uri.parse('${AppConstants.authApiUrl}/user/kelola-aset/$id'),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: json.encode(assetData),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final dynamic jsonResponse = json.decode(response.body);
        if (jsonResponse['status'] == "success") {
          clearCache();
          return true;
        } else {
          throw ServerException(
              message: jsonResponse['message'] ?? 'Gagal mengupdate asset');
        }
      } else if (response.statusCode == 401) {
        throw AuthException(message: 'Tidak diizinkan: Token tidak valid');
      } else if (response.statusCode == 422) {
        final errorData = json.decode(response.body);
        throw ServerException(
            message:
                'Validasi gagal: ${errorData['message'] ?? 'Periksa input Anda'}');
      } else {
        throw ServerException(
            message: 'Gagal mengupdate asset: ${response.statusCode}');
      }
    } catch (e) {
      if (e is AuthException || e is ServerException) {
        rethrow;
      }
      throw ServerException(message: 'Gagal mengupdate asset: ${e.toString()}');
    }
  }

  Future<bool> updateAssetWithImages(int id, Map<String, dynamic> assetData,
      File? fotoDpn, File? fotoSamping) async {
    try {
      final authToken = await _getAuthToken();

      // Buat request multipart
      var request = http.MultipartRequest(
        'POST', // Gunakan POST dengan _method=PUT
        Uri.parse('${AppConstants.authApiUrl}/user/kelola-aset/$id'),
      );

      // Tambahkan headers
      request.headers['Authorization'] = 'Bearer $authToken';
      request.headers['Accept'] = 'application/json';

      // Tambahkan _method=PUT untuk emulasi PUT request dengan file
      request.fields['_method'] = 'PUT';

      // Tambahkan field teks dari assetData
      assetData.forEach((key, value) {
        if (value != null) {
          request.fields[key] = value.toString();
        }
      });

      // Tambahkan file gambar jika ada
      if (fotoDpn != null) {
        request.files.add(await http.MultipartFile.fromPath(
          'foto_aset_depan',
          fotoDpn.path,
          filename:
              'foto_depan_${DateTime.now().millisecondsSinceEpoch}.${fotoDpn.path.split('.').last}',
        ));
      }

      if (fotoSamping != null) {
        request.files.add(await http.MultipartFile.fromPath(
          'foto_aset_samping',
          fotoSamping.path,
          filename:
              'foto_samping_${DateTime.now().millisecondsSinceEpoch}.${fotoSamping.path.split('.').last}',
        ));
      }

      // Kirim request
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Clear cache to refresh data
        clearCache();
        return true;
      } else if (response.statusCode == 401) {
        throw AuthException(message: 'Tidak diizinkan: Token tidak valid');
      } else if (response.statusCode == 422) {
        final errorData = json.decode(response.body);
        throw ServerException(
            message:
                'Validasi gagal: ${errorData['message'] ?? 'Periksa input Anda'}');
      } else {
        throw ServerException(
            message: 'Gagal mengupdate asset: ${response.statusCode}');
      }
    } catch (e) {
      if (e is AuthException || e is ServerException) {
        rethrow;
      }
      throw ServerException(message: 'Gagal mengupdate asset: ${e.toString()}');
    }
  }

  Future<bool> deleteAsset(int id) async {
    try {
      final authToken = await _getAuthToken();

      final response = await client.delete(
        Uri.parse('${AppConstants.authApiUrl}/user/kelola-aset/$id'),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final dynamic jsonResponse = json.decode(response.body);
        if (jsonResponse['status'] == "success") {
          _cachedAssets = null;
          return true;
        } else {
          throw ServerException(
              message: jsonResponse['message'] ?? 'Gagal menghapus aset');
        }
      } else if (response.statusCode == 401) {
        throw AuthException(message: 'Tidak diizinkan: Token tidak valid');
      } else {
        throw ServerException(
            message: 'Gagal menghapus aset: ${response.statusCode}');
      }
    } catch (e) {
      if (e is AuthException || e is ServerException) {
        rethrow;
      }
      throw ServerException(message: 'Gagal menghapus aset: ${e.toString()}');
    }
  }

  void clearCache() {
    _cachedAssets = null;
  }
}
