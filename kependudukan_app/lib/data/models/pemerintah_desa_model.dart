class PemerintahDesaModel {
  final int? villageId;
  final List<KepalaDesa> kepalaDesa;
  final List<PerangkatDesa> perangkatDesa;
  final List<DataWilayah> dataWilayah;
  final StatistikPenduduk? statistikPenduduk;
  final StatistikUmur? statistikUmur;
  final StatistikPendidikan? statistikPendidikan;
  final StatistikAgama? statistikAgama;
  final List<UsahaDesa> usahaDesa;
  final List<SaranaUmum> saranaUmum;
  final List<SaranaUmumByKategori> saranaUmumByKategori;
  final List<KesenianBudaya> kesenianBudaya;
  final List<Abdes> abdes;
  final List<WarungkuKlasifikasiJenis> warungkuKlasifikasiJenis;
  final String? pemerintahAlamat;
  final String? pemerintahKontak;
  final int? pemerintahProvinceId;
  final int? pemerintahDistrictId;
  final int? pemerintahSubDistrictId;
  final int? pemerintahVillagesId;

  PemerintahDesaModel({
    this.villageId,
    required this.kepalaDesa,
    required this.perangkatDesa,
    required this.dataWilayah,
    this.statistikPenduduk,
    this.statistikUmur,
    this.statistikPendidikan,
    this.statistikAgama,
    this.usahaDesa = const [],
    this.saranaUmum = const [],
    this.saranaUmumByKategori = const [],
    this.kesenianBudaya = const [],
    this.abdes = const [],
    this.warungkuKlasifikasiJenis = const [],
    this.pemerintahAlamat,
    this.pemerintahKontak,
    this.pemerintahProvinceId,
    this.pemerintahDistrictId,
    this.pemerintahSubDistrictId,
    this.pemerintahVillagesId,
  });

  factory PemerintahDesaModel.fromJson(Map<String, dynamic> json) {
    // Parse kepala desa terlebih dahulu agar bisa override photo dari pemerintah_desa
    List<KepalaDesa> kepala = (json['kepala_desa'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(KepalaDesa.fromJson)
        .toList();

    return PemerintahDesaModel(
      villageId: json['desa']?['village_id'] as int?,
      kepalaDesa: kepala,
      perangkatDesa: (json['perangkat_desa'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(PerangkatDesa.fromJson)
          .toList(),
      dataWilayah: (json['data_wilayah'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(DataWilayah.fromJson)
          .toList(),
      statistikPenduduk: json['statistik_penduduk'] is Map
          ? StatistikPenduduk.fromJson(
              (json['statistik_penduduk'] as Map).cast<String, dynamic>())
          : null,
      statistikUmur: json['statistik_umur'] is Map
          ? StatistikUmur.fromJson(
              (json['statistik_umur'] as Map).cast<String, dynamic>())
          : null,
      statistikPendidikan: json['statistik_pendidikan'] is Map
          ? StatistikPendidikan.fromJson(
              (json['statistik_pendidikan'] as Map).cast<String, dynamic>())
          : null,
      statistikAgama: json['statistik_agama'] is Map
          ? StatistikAgama.fromJson(
              (json['statistik_agama'] as Map).cast<String, dynamic>())
          : null,
      usahaDesa: (json['usaha_desa'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(UsahaDesa.fromJson)
          .toList(),
      saranaUmum: (json['sarana_umum'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(SaranaUmum.fromJson)
          .toList(),
      saranaUmumByKategori:
          (json['sarana_umum_by_kategori'] as List<dynamic>? ?? [])
              .whereType<Map<String, dynamic>>()
              .map(SaranaUmumByKategori.fromJson)
              .toList(),
      kesenianBudaya: (json['kesenian_budaya'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(KesenianBudaya.fromJson)
          .toList(),
      abdes: (json['abdes'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(Abdes.fromJson)
          .toList(),
      warungkuKlasifikasiJenis:
          (json['warungku_klasifikasi_jenis'] as List<dynamic>? ?? [])
              .whereType<Map<String, dynamic>>()
              .map(WarungkuKlasifikasiJenis.fromJson)
              .toList(),
      // Ambil alamat & kontak dari entri pertama pemerintah_desa jika tersedia
      pemerintahAlamat: () {
        final list = json['pemerintah_desa'];
        if (list is List && list.isNotEmpty && list.first is Map) {
          final m = (list.first as Map).cast<String, dynamic>();
          return (m['alamat'] ?? m['address'])?.toString();
        }
        return null;
      }(),
      pemerintahKontak: () {
        final list = json['pemerintah_desa'];
        if (list is List && list.isNotEmpty && list.first is Map) {
          final m = (list.first as Map).cast<String, dynamic>();
          return (m['no_hp'] ?? m['kontak'] ?? m['phone'])?.toString();
        }
        return null;
      }(),
      pemerintahProvinceId: () {
        final list = json['pemerintah_desa'];
        if (list is List && list.isNotEmpty && list.first is Map) {
          final m = (list.first as Map).cast<String, dynamic>();
          final v = m['province_id'];
          return v is num ? v.toInt() : int.tryParse('${v ?? ''}');
        }
        return null;
      }(),
      pemerintahDistrictId: () {
        final list = json['pemerintah_desa'];
        if (list is List && list.isNotEmpty && list.first is Map) {
          final m = (list.first as Map).cast<String, dynamic>();
          final v = m['districts_id'];
          return v is num ? v.toInt() : int.tryParse('${v ?? ''}');
        }
        return null;
      }(),
      pemerintahSubDistrictId: () {
        final list = json['pemerintah_desa'];
        if (list is List && list.isNotEmpty && list.first is Map) {
          final m = (list.first as Map).cast<String, dynamic>();
          final v = m['sub_districts_id'];
          return v is num ? v.toInt() : int.tryParse('${v ?? ''}');
        }
        return null;
      }(),
      pemerintahVillagesId: () {
        final list = json['pemerintah_desa'];
        if (list is List && list.isNotEmpty && list.first is Map) {
          final m = (list.first as Map).cast<String, dynamic>();
          final v = m['villages_id'];
          return v is num ? v.toInt() : int.tryParse('${v ?? ''}');
        }
        return null;
      }(),
    );
  }
}

class KepalaDesa {
  final int id;
  final String nama;
  final String? periode;
  final String? photoUrl;

  KepalaDesa(
      {required this.id, required this.nama, this.periode, this.photoUrl});

  factory KepalaDesa.fromJson(Map<String, dynamic> json) {
    return KepalaDesa(
      id: (json['id'] as num?)?.toInt() ?? 0,
      nama: (json['nama'] ?? '').toString(),
      periode: json['periode']?.toString(),
      photoUrl: (json['foto_url'] ??
              json['photo_url'] ??
              json['foto'] ??
              json['photo'] ??
              json['preview_url'])
          ?.toString(),
    );
  }
}

class PerangkatDesa {
  final int id;
  final String jabatan;
  final String nama;
  final String? periode;
  final String? photoUrl;

  PerangkatDesa({
    required this.id,
    required this.jabatan,
    required this.nama,
    this.periode,
    this.photoUrl,
  });

  factory PerangkatDesa.fromJson(Map<String, dynamic> json) {
    return PerangkatDesa(
      id: (json['id'] as num?)?.toInt() ?? 0,
      jabatan: (json['jabatan'] ?? '').toString(),
      nama: (json['nama'] ?? '').toString(),
      periode: json['periode']?.toString(),
      photoUrl: (json['foto_url'] ??
              json['photo_url'] ??
              json['foto'] ??
              json['photo'] ??
              json['preview_url'])
          ?.toString(),
    );
  }
}

class DataWilayah {
  final int id;
  final String? luasWilayah;
  final String? batasWilayah;
  final int? jumlahDusun;
  final int? jumlahRT;
  final int? industri;
  final int? usahaMikro;
  final int? umkm;
  final int? pertanian;
  final int? peternakan;
  final int? perikanan;
  final int? perkebunan;
  final int? lainnya;

  DataWilayah({
    required this.id,
    this.luasWilayah,
    this.batasWilayah,
    this.jumlahDusun,
    this.jumlahRT,
    this.industri,
    this.usahaMikro,
    this.umkm,
    this.pertanian,
    this.peternakan,
    this.perikanan,
    this.perkebunan,
    this.lainnya,
  });

  factory DataWilayah.fromJson(Map<String, dynamic> json) {
    int? asInt(dynamic v) => v == null
        ? null
        : (v is num
            ? v.toInt()
            : int.tryParse(v.toString().replaceAll(RegExp(r'[^0-9-]'), '')));

    return DataWilayah(
      id: (json['id'] as num?)?.toInt() ?? 0,
      luasWilayah: json['luas_wilayah']?.toString(),
      batasWilayah: json['batas_wilayah']?.toString(),
      jumlahDusun: asInt(json['jumlah_dusun']),
      jumlahRT: asInt(json['jumlah_rt']),
      industri: asInt(json['industri']),
      usahaMikro: asInt(json['usaha_mikro']),
      umkm: asInt(json['umkm']),
      pertanian: asInt(json['pertanian']),
      peternakan: asInt(json['peternakan']),
      perikanan: asInt(json['perikanan']),
      perkebunan: asInt(json['perkebunan']),
      lainnya: asInt(json['lainnya']),
    );
  }
}

class StatistikPenduduk {
  final int male;
  final int female;
  final int total;

  StatistikPenduduk(
      {required this.male, required this.female, required this.total});

  factory StatistikPenduduk.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic v) =>
        (v is num) ? v.toInt() : int.tryParse('${v ?? 0}') ?? 0;
    return StatistikPenduduk(
      male: asInt(json['male']),
      female: asInt(json['female']),
      total: asInt(json['total']),
    );
  }
}

class UsahaDesa {
  final int id;
  final String namaUsaha;
  final String? alamat;
  final String? jenis;
  final String? photoUrl;

  UsahaDesa({
    required this.id,
    required this.namaUsaha,
    this.alamat,
    this.jenis,
    this.photoUrl,
  });

  factory UsahaDesa.fromJson(Map<String, dynamic> json) {
    // Jenis bisa dikirim sebagai 'jenis', 'jenis_usaha', atau 'kategori'
    final dynamic rawJenis =
        json['jenis'] ?? json['jenis_usaha'] ?? json['kategori'];
    return UsahaDesa(
      id: (json['id'] as num?)?.toInt() ?? 0,
      namaUsaha: (json['nama_usaha'] ?? json['nama'] ?? '').toString(),
      alamat: json['alamat']?.toString(),
      jenis: rawJenis?.toString(),
      photoUrl: (json['foto_url'] ??
              json['photo_url'] ??
              json['foto'] ??
              json['photo'] ??
              json['gambar'] ??
              json['image'] ??
              json['preview_url'])
          ?.toString(),
    );
  }
}

class SaranaUmum {
  final int id;
  final String namaSarana;
  final String? kategori;
  final int? kategoriId;
  final String? photoUrl;

  SaranaUmum(
      {required this.id,
      required this.namaSarana,
      this.kategori,
      this.kategoriId,
      this.photoUrl});

  factory SaranaUmum.fromJson(Map<String, dynamic> json) {
    // Kategori bisa datang sebagai string/angka/objek dengan berbagai nama field
    final dynamic rawKategori = json['kategori'] ??
        json['kategori_sarana'] ??
        json['kategoriSarana'] ??
        json['category'] ??
        json['nama_kategori'] ??
        json['kategori_sarana_nama'] ??
        json['kategoriSaranaNama'] ??
        json['kategori_nama'] ??
        json['kategoriName'];

    String? kategoriName;
    if (rawKategori is Map) {
      kategoriName = (rawKategori['nama'] ??
              rawKategori['name'] ??
              rawKategori['kategori'])
          ?.toString();
    } else {
      if (rawKategori is num) {
        kategoriName = 'Kategori ${rawKategori.toInt()}';
      } else {
        kategoriName = rawKategori?.toString();
      }
    }

    // Tangkap id kategori dari beberapa kemungkinan nama field
    final dynamic rawKategoriId = json['kategori_sarana_id'] ??
        json['kategoriSaranaId'] ??
        json['category_id'] ??
        json['kategori_id'];
    final int? kategoriId = rawKategoriId is num
        ? rawKategoriId.toInt()
        : int.tryParse('${rawKategoriId ?? ''}');

    return SaranaUmum(
      id: (json['id'] as num?)?.toInt() ?? 0,
      namaSarana: (json['nama_sarana'] ?? json['nama'] ?? '').toString(),
      kategori: kategoriName,
      kategoriId: kategoriId,
      photoUrl: (json['foto_url'] ??
              json['photo_url'] ??
              json['foto'] ??
              json['photo'] ??
              json['gambar'] ??
              json['image'] ??
              json['preview_url'])
          ?.toString(),
    );
  }
}

class KesenianBudaya {
  final int id;
  final String namaKesenian;
  final String? jenis;
  final int? jenisId;
  final String? photoUrl;

  KesenianBudaya({
    required this.id,
    required this.namaKesenian,
    this.jenis,
    this.jenisId,
    this.photoUrl,
  });

  factory KesenianBudaya.fromJson(Map<String, dynamic> json) {
    final dynamic rawJenis = json['jenis'] ?? json['kategori'] ?? json['tipe'];
    final dynamic rawJenisId =
        json['jenis_id'] ?? json['kategori_id'] ?? json['tipe_id'];
    return KesenianBudaya(
      id: (json['id'] as num?)?.toInt() ?? 0,
      namaKesenian: (json['nama_kesenian'] ?? json['nama'] ?? '').toString(),
      jenis: rawJenis?.toString(),
      jenisId: rawJenisId is num
          ? rawJenisId.toInt()
          : int.tryParse('${rawJenisId ?? ''}'),
      photoUrl: (json['foto_url'] ??
              json['photo_url'] ??
              json['foto'] ??
              json['photo'] ??
              json['gambar'] ??
              json['image'] ??
              json['preview_url'])
          ?.toString(),
    );
  }
}

class Abdes {
  final int id;
  final String jenis;
  final String kategori;
  final String? jumlahAnggaran;

  Abdes({
    required this.id,
    required this.jenis,
    required this.kategori,
    this.jumlahAnggaran,
  });

  factory Abdes.fromJson(Map<String, dynamic> json) {
    return Abdes(
      id: (json['id'] as num?)?.toInt() ?? 0,
      jenis: (json['jenis'] ?? '').toString(),
      kategori: (json['kategori'] ?? json['nama'] ?? '').toString(),
      jumlahAnggaran: json['jumlah_anggaran']?.toString(),
    );
  }
}

class SaranaUmumByKategori {
  final SaranaKategori kategori;
  final List<SaranaRingkas> sarana;

  SaranaUmumByKategori({required this.kategori, required this.sarana});

  factory SaranaUmumByKategori.fromJson(Map<String, dynamic> json) {
    return SaranaUmumByKategori(
      kategori: SaranaKategori.fromJson(
          (json['kategori'] as Map).cast<String, dynamic>()),
      sarana: (json['sarana'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(SaranaRingkas.fromJson)
          .toList(),
    );
  }
}

class SaranaKategori {
  final int id;
  final String? jenisSarana;
  final String? kategori;

  SaranaKategori({required this.id, this.jenisSarana, this.kategori});

  factory SaranaKategori.fromJson(Map<String, dynamic> json) {
    return SaranaKategori(
      id: (json['id'] as num?)?.toInt() ?? 0,
      jenisSarana: json['jenis_sarana']?.toString(),
      kategori: json['kategori']?.toString(),
    );
  }
}

class SaranaRingkas {
  final int id;
  final String namaSarana;
  final String? alamat;
  final String? kontak;
  final String? photoUrl;

  SaranaRingkas({
    required this.id,
    required this.namaSarana,
    this.alamat,
    this.kontak,
    this.photoUrl,
  });

  factory SaranaRingkas.fromJson(Map<String, dynamic> json) {
    return SaranaRingkas(
      id: (json['id'] as num?)?.toInt() ?? 0,
      namaSarana: (json['nama_sarana'] ?? '').toString(),
      alamat: json['alamat']?.toString(),
      kontak: json['kontak']?.toString(),
      photoUrl: (json['foto_url'] ??
              json['photo_url'] ??
              json['foto'] ??
              json['photo'] ??
              json['gambar'] ??
              json['image'] ??
              json['preview_url'])
          ?.toString(),
    );
  }
}

class WarungkuKlasifikasiJenis {
  final int id;
  final String jenis;
  final String klasifikasi;
  final int totalBarang;

  WarungkuKlasifikasiJenis({
    required this.id,
    required this.jenis,
    required this.klasifikasi,
    required this.totalBarang,
  });

  factory WarungkuKlasifikasiJenis.fromJson(Map<String, dynamic> json) {
    return WarungkuKlasifikasiJenis(
      id: (json['id'] as num?)?.toInt() ?? 0,
      jenis: (json['jenis'] ?? '').toString(),
      klasifikasi: (json['klasifikasi'] ?? '').toString(),
      totalBarang: (json['total_barang'] is num)
          ? (json['total_barang'] as num).toInt()
          : int.tryParse('${json['total_barang'] ?? 0}') ?? 0,
    );
  }
}

class StatistikUmur {
  final Map<String, int> groups;
  final int totalWithAge;

  StatistikUmur({
    required this.groups,
    required this.totalWithAge,
  });

  factory StatistikUmur.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic v) =>
        (v is num) ? v.toInt() : int.tryParse('${v ?? 0}') ?? 0;

    // Parse groups object
    Map<String, int> groups = {};
    if (json['groups'] is Map) {
      final groupsMap = json['groups'] as Map<String, dynamic>;
      groupsMap.forEach((key, value) {
        groups[key] = asInt(value);
      });
    }

    return StatistikUmur(
      groups: groups,
      totalWithAge: asInt(json['total_with_age']),
    );
  }

  // Helper getters untuk akses mudah ke data
  int get usia0_17 => groups['0_17'] ?? 0;
  int get usia18_30 => groups['18_30'] ?? 0;
  int get usia31_45 => groups['31_45'] ?? 0;
  int get usia46_60 => groups['46_60'] ?? 0;
  int get usia61_plus => groups['61_plus'] ?? 0;
}

class StatistikPendidikan {
  final Map<String, int> groups;
  final int totalWithEducation;

  StatistikPendidikan({
    required this.groups,
    required this.totalWithEducation,
  });

  factory StatistikPendidikan.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic v) =>
        (v is num) ? v.toInt() : int.tryParse('${v ?? 0}') ?? 0;

    // Parse groups object
    Map<String, int> groups = {};
    if (json['groups'] is Map) {
      final groupsMap = json['groups'] as Map<String, dynamic>;
      groupsMap.forEach((key, value) {
        groups[key] = asInt(value);
      });
    }

    return StatistikPendidikan(
      groups: groups,
      totalWithEducation: asInt(json['total_with_education']),
    );
  }

  // Helper getters untuk akses mudah ke data
  int get tidakSekolah => groups['tidak/belum sekolah'] ?? 0;
  int get belumTamatSD => groups['belum tamat sd/sederajat'] ?? 0;
  int get tamatSD => groups['tamat sd/sederajat'] ?? 0;
  int get sltp => groups['sltp/smp/sederajat'] ?? 0;
  int get slta => groups['slta/sma/sederajat'] ?? 0;
  int get diplomaI => groups['diploma i/ii'] ?? 0;
  int get diplomaIII => groups['akademi/diploma iii/ sarjana muda'] ?? 0;
  int get diplomaIV => groups['diploma iv/ strata i/ strata ii'] ?? 0;
  int get strataIII => groups['strata iii'] ?? 0;
  int get lainnya => groups['lainnya'] ?? 0;
}

class StatistikAgama {
  final Map<String, int> groups;
  final int totalWithReligion;

  StatistikAgama({
    required this.groups,
    required this.totalWithReligion,
  });

  factory StatistikAgama.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic v) =>
        (v is num) ? v.toInt() : int.tryParse('${v ?? 0}') ?? 0;

    // Parse groups object
    Map<String, int> groups = {};
    if (json['groups'] is Map) {
      final groupsMap = json['groups'] as Map<String, dynamic>;
      groupsMap.forEach((key, value) {
        groups[key] = asInt(value);
      });
    }

    return StatistikAgama(
      groups: groups,
      totalWithReligion: asInt(json['total_with_religion']),
    );
  }

  // Helper getters untuk akses mudah ke data
  int get islam => groups['islam'] ?? 0;
  int get kristen => groups['kristen'] ?? 0;
  int get katolik => groups['katolik'] ?? 0;
  int get hindu => groups['hindu'] ?? 0;
  int get buddha => groups['buddha'] ?? 0;
  int get konghucu => groups['konghucu'] ?? 0;
  int get lainnya => groups['lainnya'] ?? 0;
}
