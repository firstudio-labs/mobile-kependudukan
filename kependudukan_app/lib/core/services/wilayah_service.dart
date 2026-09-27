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
      print('Error fetching: $url -> $e');
    }
    return [];
  }

  dynamic _getCache(String type, String id) =>
      _cache.get<dynamic>('${type}_$id');
  void _setCache(String type, String id, dynamic data) =>
      _cache.set<dynamic>('${type}_$id', data, ttl: _ttl);

  Future<Map<String, dynamic>?> getProvince(String id) async {
    if (_getCache('province', id) != null) return _getCache('province', id);
    final provinces =
        await _getList('provinces', '${AppConstants.goBaseUrl}/api/provinces');

    Map<String, dynamic>? province;
    try {
      province = provinces.firstWhere((p) => '${p['id']}' == id);
      _setCache('province', id, province);
    } catch (e) {
      province = null;
    }

    return province;
  }

  Future<Map<String, dynamic>?> getDistrict(String id) async {
    if (_getCache('district', id) != null) return _getCache('district', id);
    final provinces =
        await _getList('provinces', '${AppConstants.goBaseUrl}/api/provinces');
    for (final province in provinces) {
      final String provinceCode = '${province['code']}';
      final districts = await _getList(
        'districts_$provinceCode',
        '${AppConstants.goBaseUrl}/api/districts/$provinceCode',
      );

      try {
        final district = districts.firstWhere((d) => '${d['id']}' == id);
        district['province'] = province;
        _setCache('district', id, district);
        return district;
      } catch (_) {
        continue;
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

    if (parentDistrictId != null) {
      final result = await _getSubDistrictWithParent(id, parentDistrictId);
      if (result != null) return result;
    }

    return await _searchSubDistrictInAllProvinces(id);
  }

  Future<Map<String, dynamic>?> _getSubDistrictWithParent(
    String id,
    String parentDistrictId,
  ) async {
    final district = await getDistrict(parentDistrictId);
    if (district == null) return null;

    final String districtCode = '${district['code']}';
    final subs = await _getList(
      'subdistricts_$districtCode',
      '${AppConstants.goBaseUrl}/api/sub-districts/$districtCode',
    );

    try {
      final sub = subs.firstWhere((s) => '${s['id']}' == id);
      sub['district'] = district;
      _setCache('subdistrict', id, sub);
      return sub;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> _searchSubDistrictInAllProvinces(
    String id,
  ) async {
    final provinces =
        await _getList('provinces', '${AppConstants.goBaseUrl}/api/provinces');
    for (final province in provinces) {
      final String provinceCode = '${province['code']}';
      final districts = await _getList(
        'districts_$provinceCode',
        '${AppConstants.goBaseUrl}/api/districts/$provinceCode',
      );
      for (final district in districts) {
        final String districtCode = '${district['code']}';
        final subs = await _getList(
          'subdistricts_$districtCode',
          '${AppConstants.goBaseUrl}/api/sub-districts/$districtCode',
        );

        try {
          final sub = subs.firstWhere((s) => '${s['id']}' == id);
          sub['district'] = district;
          _setCache('subdistrict', id, sub);
          return sub;
        } catch (_) {
          continue;
        }
      }
    }
    return null;
  }

  Future<Map<String, dynamic>?> getVillage(
    String id,
    String? subdistrictId,
    String? districtId,
  ) async {
    if (_getCache('village', id) != null) return _getCache('village', id);

    if (subdistrictId != null) {
      final subdistrict = await getSubDistrict(subdistrictId, districtId);
      if (subdistrict != null) {
        final String subCode = '${subdistrict['code']}';
        final villages = await _getList(
          'villages_$subCode',
          '${AppConstants.goBaseUrl}/api/villages/$subCode',
        );

        try {
          final village = villages.firstWhere((v) => '${v['id']}' == id);
          village['subdistrict'] = subdistrict;
          _setCache('village', id, village);
          return village;
        } catch (_) {}
      }
    }

    final provinces =
        await _getList('provinces', '${AppConstants.goBaseUrl}/api/provinces');
    for (final province in provinces) {
      final String provinceCode = '${province['code']}';
      final districts = await _getList(
        'districts_$provinceCode',
        '${AppConstants.goBaseUrl}/api/districts/$provinceCode',
      );
      for (final district in districts) {
        final String districtCode = '${district['code']}';
        final subs = await _getList(
          'subdistricts_$districtCode',
          '${AppConstants.goBaseUrl}/api/sub-districts/$districtCode',
        );
        for (final subdistrict in subs) {
          final String subCode = '${subdistrict['code']}';
          final villages = await _getList(
            'villages_$subCode',
            '${AppConstants.goBaseUrl}/api/villages/$subCode',
          );

          try {
            final village = villages.firstWhere((v) => '${v['id']}' == id);
            village['subdistrict'] = subdistrict;
            _setCache('village', id, village);
            return village;
          } catch (_) {
            continue;
          }
        }
      }
    }

    return null;
  }
}
