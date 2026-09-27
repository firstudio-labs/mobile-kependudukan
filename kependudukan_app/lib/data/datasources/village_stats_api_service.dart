import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:ladimas/core/constants/app_constants.dart';
import 'package:ladimas/data/models/pemerintah_desa_model.dart';

/// Ambil statistik desa langsung dari Go API (V2) agar lebih cepat dan scalable.
///
/// Endpoint: GET {API_URL}/api/v2/villages/{id}/stats
/// Header: X-API-Key
class VillageStatsApiService {
  final http.Client client;

  VillageStatsApiService({required this.client});

  Future<_VillageStatsBundle> fetchVillageStats(int villageId) async {
    final base = AppConstants.goBaseUrl;
    if (base.isEmpty) {
      throw Exception('API_URL belum diset (.env)');
    }

    final url = '$base/api/v2/villages/$villageId/stats';
    // ignore: avoid_print
    print('🌐 [GoStats] GET $url');
    final resp = await client.get(
      Uri.parse(url),
      headers: {
        'Accept': 'application/json',
        'X-API-Key': AppConstants.apiKey,
      },
    );

    if (resp.statusCode != 200) {
      throw Exception('Go stats error: ${resp.statusCode} ${resp.body}');
    }

    final Map<String, dynamic> payload = json.decode(resp.body);
    final data = payload['data'];
    if (data is! Map) {
      throw Exception('Invalid Go stats payload (missing data)');
    }
    final d = (data as Map).cast<String, dynamic>();

    final genderRaw = (d['gender'] is Map)
        ? (d['gender'] as Map).cast<String, dynamic>()
        : <String, dynamic>{};

    final ageGroupsRaw = (d['age_groups'] is Map)
        ? (d['age_groups'] as Map).cast<String, dynamic>()
        : <String, dynamic>{};

    final educationRaw = (d['education'] is Map)
        ? (d['education'] as Map).cast<String, dynamic>()
        : <String, dynamic>{};

    final religionRaw = (d['religion'] is Map)
        ? (d['religion'] as Map).cast<String, dynamic>()
        : <String, dynamic>{};

    // Bentukkan agar kompatibel dengan model yang sudah ada di mobile.
    final statistikPenduduk = StatistikPenduduk.fromJson({
      'male': genderRaw['male'] ?? 0,
      'female': genderRaw['female'] ?? 0,
      'total': genderRaw['total'] ?? 0,
    });

    final statistikUmur = StatistikUmur.fromJson({
      'groups': {
        '0_17': ageGroupsRaw['0_17'] ?? 0,
        '18_30': ageGroupsRaw['18_30'] ?? 0,
        '31_45': ageGroupsRaw['31_45'] ?? 0,
        '46_60': ageGroupsRaw['46_60'] ?? 0,
        '61_plus': ageGroupsRaw['61_plus'] ?? 0,
      },
      'total_with_age': (ageGroupsRaw['0_17'] ?? 0) +
          (ageGroupsRaw['18_30'] ?? 0) +
          (ageGroupsRaw['31_45'] ?? 0) +
          (ageGroupsRaw['46_60'] ?? 0) +
          (ageGroupsRaw['61_plus'] ?? 0),
    });

    // Normalisasi key pendidikan agar cocok dengan getter StatistikPendidikan di UI.
    final Map<String, int> educationGroups = {
      'tidak/belum sekolah': 0,
      'belum tamat sd/sederajat': 0,
      'tamat sd/sederajat': 0,
      'sltp/smp/sederajat': 0,
      'slta/sma/sederajat': 0,
      'diploma i/ii': 0,
      'akademi/diploma iii/ sarjana muda': 0,
      'diploma iv/ strata i/ strata ii': 0,
      'strata iii': 0,
      'lainnya': 0,
    };
    for (final entry in educationRaw.entries) {
      final k = _normalizeEducationKey(entry.key);
      final v = _asInt(entry.value);
      educationGroups[k] = (educationGroups[k] ?? 0) + v;
    }

    // Normalisasi key agama agar cocok dengan getter StatistikAgama di UI.
    final Map<String, int> religionGroups = {
      'islam': 0,
      'kristen': 0,
      'katolik': 0,
      'hindu': 0,
      'buddha': 0,
      'konghucu': 0,
      'lainnya': 0,
    };
    for (final entry in religionRaw.entries) {
      final k = _normalizeReligionKey(entry.key);
      final v = _asInt(entry.value);
      religionGroups[k] = (religionGroups[k] ?? 0) + v;
    }

    final statistikPendidikan = StatistikPendidikan.fromJson({
      'groups': educationGroups,
      'total_with_education':
          educationGroups.values.fold<int>(0, (a, b) => a + b),
    });

    final statistikAgama = StatistikAgama.fromJson({
      'groups': religionGroups,
      'total_with_religion':
          religionGroups.values.fold<int>(0, (a, b) => a + b),
    });

    return _VillageStatsBundle(
      statistikPenduduk: statistikPenduduk,
      statistikUmur: statistikUmur,
      statistikPendidikan: statistikPendidikan,
      statistikAgama: statistikAgama,
    );
  }

  int _sumMapValues(Map<String, dynamic> m) {
    var total = 0;
    for (final v in m.values) {
      if (v is num) {
        total += v.toInt();
      } else {
        total += int.tryParse('${v ?? 0}') ?? 0;
      }
    }
    return total;
  }

  int _asInt(dynamic v) {
    if (v is num) return v.toInt();
    return int.tryParse('${v ?? 0}') ?? 0;
  }

  String _normalizeEducationKey(String raw) {
    var v = raw.toLowerCase().trim();
    v = v.replaceAll('.', ' ').replaceAll(RegExp(r'\s+'), ' ');

    const map = <String, String>{
      'tidak/belum sekolah': 'tidak/belum sekolah',
      'tidak sekolah': 'tidak/belum sekolah',
      'belum sekolah': 'tidak/belum sekolah',
      'belum tamat sd/sederajat': 'belum tamat sd/sederajat',
      'belum tamat sd': 'belum tamat sd/sederajat',
      'tamat sd/sederajat': 'tamat sd/sederajat',
      'tamat sd': 'tamat sd/sederajat',
      'sltp/smp/sederajat': 'sltp/smp/sederajat',
      'smp': 'sltp/smp/sederajat',
      'mts': 'sltp/smp/sederajat',
      'slta/sma/sederajat': 'slta/sma/sederajat',
      'sma': 'slta/sma/sederajat',
      'smk': 'slta/sma/sederajat',
      'ma': 'slta/sma/sederajat',
      'diploma i/ii': 'diploma i/ii',
      'd1': 'diploma i/ii',
      'd2': 'diploma i/ii',
      'akademi/diploma iii/ sarjana muda': 'akademi/diploma iii/ sarjana muda',
      'd3': 'akademi/diploma iii/ sarjana muda',
      'akademi': 'akademi/diploma iii/ sarjana muda',
      'diploma iv/ strata i/ strata ii': 'diploma iv/ strata i/ strata ii',
      'd4': 'diploma iv/ strata i/ strata ii',
      's1': 'diploma iv/ strata i/ strata ii',
      'sarjana': 'diploma iv/ strata i/ strata ii',
      'strata iii': 'strata iii',
      's2': 'strata iii',
      's3': 'strata iii',
      'magister': 'strata iii',
      'doktor': 'strata iii',
      'lainnya': 'lainnya',
    };
    if (map.containsKey(v)) return map[v]!;

    // Heuristik
    if (v.contains('tidak') || v.contains('belum'))
      return 'tidak/belum sekolah';
    if (v.contains('sd') && v.contains('belum'))
      return 'belum tamat sd/sederajat';
    if (v.contains('sd')) return 'tamat sd/sederajat';
    if (v.contains('smp') || v.contains('mts') || v.contains('sltp')) {
      return 'sltp/smp/sederajat';
    }
    if (v.contains('sma') ||
        v.contains('smk') ||
        v.contains('ma') ||
        v.contains('slta')) {
      return 'slta/sma/sederajat';
    }
    if (v.contains('d1') || v.contains('d2')) return 'diploma i/ii';
    if (v.contains('d3') || v.contains('akademi'))
      return 'akademi/diploma iii/ sarjana muda';
    if (v.contains('d4') || v.contains('s1') || v.contains('sarjana'))
      return 'diploma iv/ strata i/ strata ii';
    if (v.contains('s2') ||
        v.contains('s3') ||
        v.contains('magister') ||
        v.contains('doktor')) return 'strata iii';
    return 'lainnya';
  }

  String _normalizeReligionKey(String raw) {
    final v = raw.toLowerCase().trim();
    if (v.isEmpty || v == 'null' || v == '-') return 'lainnya';
    const map = <String, String>{
      'islam': 'islam',
      'moslem': 'islam',
      'muslim': 'islam',
      'kristen': 'kristen',
      'protestan': 'kristen',
      'katolik': 'katolik',
      'katholik': 'katolik',
      'catholic': 'katolik',
      'hindu': 'hindu',
      'buddha': 'buddha',
      'budha': 'buddha',
      'konghucu': 'konghucu',
      'kong hu cu': 'konghucu',
      'confucian': 'konghucu',
      'lainnya': 'lainnya',
    };
    if (map.containsKey(v)) return map[v]!;
    if (v.contains('islam') || v.contains('muslim')) return 'islam';
    if (v.contains('krist') || v.contains('protest')) return 'kristen';
    if (v.contains('katol') || v.contains('cath')) return 'katolik';
    if (v.contains('hind')) return 'hindu';
    if (v.contains('bud')) return 'buddha';
    if (v.contains('kong') || v.contains('confuc')) return 'konghucu';
    return 'lainnya';
  }
}

class _VillageStatsBundle {
  final StatistikPenduduk statistikPenduduk;
  final StatistikUmur statistikUmur;
  final StatistikPendidikan statistikPendidikan;
  final StatistikAgama statistikAgama;

  _VillageStatsBundle({
    required this.statistikPenduduk,
    required this.statistikUmur,
    required this.statistikPendidikan,
    required this.statistikAgama,
  });
}
