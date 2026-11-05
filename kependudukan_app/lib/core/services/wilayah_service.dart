import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:ladimas/core/constants/app_constants.dart';
import 'package:ladimas/core/services/cache_service.dart';
import 'package:ladimas/core/services/persistent_cache_service.dart';

class WilayahService {
  static final WilayahService _instance = WilayahService._internal();
  factory WilayahService() => _instance;
  WilayahService._internal();

  final CacheService _cache = CacheService();
  final Duration _ttl = const Duration(hours: 6);
  final PersistentCacheService _persistent = PersistentCacheService();

  Map<String, String> get headers => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'X-API-Key': AppConstants.apiKey,
      };

  Future<List<dynamic>> _getList(String cacheKey, String url) async {
    final cached = _cache.get<List<dynamic>>(cacheKey);
    if (cached != null) return cached;

    // Try persistent cache
    final persisted = await _persistent.getJson<List<dynamic>>(cacheKey);
    if (persisted != null) {
      _cache.set<List<dynamic>>(cacheKey, persisted, ttl: _ttl);
      return persisted;
    }

    try {
      final response = await http.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body)['data'] ?? [];
        _cache.set<List<dynamic>>(cacheKey, data, ttl: _ttl);
        await _persistent.setJson(cacheKey, data, ttl: _ttl);
        return data;
      }
    } catch (e) {
      // ignore: avoid_print
      print('Error fetching: $url -> $e');
    }
    return [];
  }

  dynamic _getCache(String type, String id) =>
      _cache.get<dynamic>('${type}_$id');
  void _setCache(String type, String id, dynamic data) =>
      _cache.set<dynamic>('${type}_$id', data, ttl: _ttl);

  /// Cari entri yang cocok dengan `id` (bisa berupa field `id` atau `code`).
  /// Mengembalikan copy supaya list yang di-cache tidak termutasi.
  Map<String, dynamic>? _findEntry(List<dynamic> list, String id) {
    for (final item in list) {
      if (item is! Map) continue;
      if ('${item['id']}' == id || '${item['code']}' == id) {
        return Map<String, dynamic>.from(item);
      }
    }
    return null;
  }

  Future<List<dynamic>> _getProvinces() async =>
      _getList('provinces', '${AppConstants.goBaseUrl}/api/provinces');

  Future<Map<String, dynamic>?> _findDistrictInProvince(
    String provinceCode,
    String id,
  ) async {
    final districts = await _getList(
      'districts_$provinceCode',
      '${AppConstants.goBaseUrl}/api/districts/$provinceCode',
    );
    return _findEntry(districts, id);
  }

Future<Map<String, dynamic>?> getProvince(String id) async {
    if (_getCache('province', id) != null) return _getCache('province', id);
    final provinces = await _getProvinces();

    final province = _findEntry(provinces, id);
    if (province != null) _setCache('province', id, province);
    return province;
  }

  Future<Map<String, dynamic>?> getDistrict(
    String id, [
    String? parentProvinceId,
  ]) async {
    if (_getCache('district', id) != null) return _getCache('district', id);

    // 1. Coba langsung dari provinsi induk jika ID/kode provinsi diketahui
    if (parentProvinceId != null && parentProvinceId.trim().isNotEmpty) {
      final province = await getProvince(parentProvinceId.trim());
      if (province != null) {
        final district = await _findDistrictInProvince(
          '${province['code']}',
          id,
        );
        if (district != null) {
          district['province'] = province;
          _setCache('district', id, district);
          return district;
        }
      }
    }

    // 2. Optimasi cepat: 2 digit pertama ID biasanya kode provinsi (standar BPS)
    if (id.length >= 2) {
      final prefix = id.substring(0, 2);
      final provinces = await _getProvinces();
      final matchedProvs = provinces
          .where((p) => '${p['code']}' == prefix || '${p['id']}' == prefix);
      for (final province in matchedProvs) {
        final district = await _findDistrictInProvince('${province['code']}', id);
        if (district != null) {
          district['province'] = province;
          _setCache('district', id, district);
          return district;
        }
      }
    }

    // 3. Fallback: ambil semua daftar kabupaten secara paralel
    final provinces = await _getProvinces();
    final results = await Future.wait(
      provinces.map(
        (province) => _findDistrictInProvince('${province['code']}', id),
      ),
    );
    for (var i = 0; i < provinces.length; i++) {
      if (results[i] != null) {
        final district = results[i]!;
        district['province'] = provinces[i];
        _setCache('district', id, district);
        return district;
      }
    }
    return null;
  }

  Future<Map<String, dynamic>?> getSubDistrict(
    String id,
    String? parentDistrictId,
  ) async {
    if (_getCache('subdistrict', id) != null) {
      return _getCache('subdistrict', id);
    }

    if (parentDistrictId != null && parentDistrictId.trim().isNotEmpty) {
      final result = await _getSubDistrictWithParent(id, parentDistrictId.trim());
      if (result != null) return result;
    }

    // Fast path BPS: 4 digit pertama = kode kabupaten
    if (id.length >= 7) {
      final sub = await _findSubDistrictInDistrict(id.substring(0, 4), id);
      if (sub != null) {
        _setCache('subdistrict', id, sub);
        return sub;
      }
    }

    return null;
  }

  Future<Map<String, dynamic>?> _getSubDistrictWithParent(
    String id,
    String parentDistrictId,
  ) async {
    final district = await getDistrict(parentDistrictId);
    if (district == null) return null;

    final sub = await _findSubDistrictInDistrict('${district['code']}', id);
    if (sub == null) return null;

    sub['district'] = district;
    _setCache('subdistrict', id, sub);
    return sub;
  }

  Future<Map<String, dynamic>?> _findSubDistrictInDistrict(
    String districtCode,
    String id,
  ) async {
    final subs = await _getList(
      'subdistricts_$districtCode',
      '${AppConstants.goBaseUrl}/api/sub-districts/$districtCode',
    );
    return _findEntry(subs, id);
  }

  Future<Map<String, dynamic>?> getVillage(
    String id,
    String? subdistrictId,
    String? districtId,
  ) async {
    if (_getCache('village', id) != null) return _getCache('village', id);

    // 1. Coba dari kecamatan induk jika ada
    if (subdistrictId != null && subdistrictId.trim().isNotEmpty) {
      final subdistrict = await getSubDistrict(subdistrictId.trim(), districtId);
      if (subdistrict != null) {
        final village = await _findVillageInSubDistrict(
          '${subdistrict['code']}',
          id,
        );
        if (village != null) {
          village['subdistrict'] = subdistrict;
          _setCache('village', id, village);
          return village;
        }
      }
    }

    // 2. Fast path BPS: 7 digit pertama ID = kode kecamatan
    if (id.length >= 10) {
      final village = await _findVillageInSubDistrict(id.substring(0, 7), id);
      if (village != null) {
        _setCache('village', id, village);
        return village;
      }
    }

    // 3. Jika belum ketemu tapi districtId diketahui, cari di kecamatan dalam kabupaten tersebut saja
    if (districtId != null && districtId.trim().isNotEmpty) {
      final district = await getDistrict(districtId.trim());
      if (district != null) {
        final village = await _searchVillageInDistrict('${district['code']}', id);
        if (village != null) return village;
      }
    }

    return null;
  }

  Future<Map<String, dynamic>?> _findVillageInSubDistrict(
    String subCode,
    String id,
  ) async {
    final villages = await _getList(
      'villages_$subCode',
      '${AppConstants.goBaseUrl}/api/villages/$subCode',
    );
    return _findEntry(villages, id);
  }

  Future<Map<String, dynamic>?> _searchVillageInDistrict(
    String districtCode,
    String id,
  ) async {
    final subs = await _getList(
      'subdistricts_$districtCode',
      '${AppConstants.goBaseUrl}/api/sub-districts/$districtCode',
    );
    for (final sub in subs) {
      if (sub is! Map) continue;
      final village = await _findVillageInSubDistrict('${sub['code']}', id);
      if (village != null) {
        village['subdistrict'] = Map<String, dynamic>.from(sub);
        _setCache('village', id, village);
        return village;
      }
    }
    return null;
  }
}
