class TagihanModel {
  final int id;
  final String? nik;
  final String? fullName;
  final int villagesId;
  final String tanggal;
  final String status;
  final String? statusLabel;
  final double nominal;
  final String? nominalFormatted;
  final String? keterangan;
  final KategoriTagihan? kategori;
  final SubKategoriTagihan? subKategori;
  final String? createdAt;
  final String? updatedAt;

  TagihanModel({
    required this.id,
    this.nik,
    this.fullName,
    required this.villagesId,
    required this.tanggal,
    required this.status,
    this.statusLabel,
    required this.nominal,
    this.nominalFormatted,
    this.keterangan,
    this.kategori,
    this.subKategori,
    this.createdAt,
    this.updatedAt,
  });

  factory TagihanModel.fromJson(Map<String, dynamic> json) {
    // Handle different response structures for kategori and sub_kategori
    KategoriTagihan? kategori;
    SubKategoriTagihan? subKategori;

    if (json['kategori'] != null) {
      if (json['kategori'] is Map<String, dynamic>) {
        // Detail response format
        kategori =
            KategoriTagihan.fromJson(json['kategori'] as Map<String, dynamic>);
      } else if (json['kategori'] is String) {
        // List response format - create dummy object with string value
        kategori = KategoriTagihan(id: 0, nama: json['kategori'] as String);
      }
    }

    if (json['sub_kategori'] != null) {
      if (json['sub_kategori'] is Map<String, dynamic>) {
        // Detail response format
        subKategori = SubKategoriTagihan.fromJson(
            json['sub_kategori'] as Map<String, dynamic>);
      } else if (json['sub_kategori'] is String) {
        // List response format - create dummy object with string value
        subKategori =
            SubKategoriTagihan(id: 0, nama: json['sub_kategori'] as String);
      }
    }

    return TagihanModel(
      id: json['id'] as int,
      nik: json['nik']?.toString(),
      fullName: json['full_name']?.toString(),
      villagesId: json['villages_id'] ?? 0, // Default value if not present
      tanggal: json['tanggal'] as String,
      status: json['status'] as String,
      statusLabel: json['status_label']?.toString(),
      nominal: (json['nominal'] as num).toDouble(),
      nominalFormatted: json['nominal_formatted']?.toString(),
      keterangan: json['keterangan']?.toString(),
      kategori: kategori,
      subKategori: subKategori,
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nik': nik,
      'full_name': fullName,
      'villages_id': villagesId,
      'tanggal': tanggal,
      'status': status,
      'status_label': statusLabel,
      'nominal': nominal,
      'nominal_formatted': nominalFormatted,
      'keterangan': keterangan,
      'kategori': kategori?.toJson(),
      'sub_kategori': subKategori?.toJson(),
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}

class KategoriTagihan {
  final int id;
  final String nama;

  KategoriTagihan({
    required this.id,
    required this.nama,
  });

  factory KategoriTagihan.fromJson(Map<String, dynamic> json) {
    return KategoriTagihan(
      id: json['id'] as int,
      nama: json['nama'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nama': nama,
    };
  }
}

class SubKategoriTagihan {
  final int id;
  final String nama;

  SubKategoriTagihan({
    required this.id,
    required this.nama,
  });

  factory SubKategoriTagihan.fromJson(Map<String, dynamic> json) {
    return SubKategoriTagihan(
      id: json['id'] as int,
      nama: json['nama'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nama': nama,
    };
  }
}

class TagihanResponse {
  final List<TagihanModel> data;
  final PaginationInfo pagination;

  TagihanResponse({
    required this.data,
    required this.pagination,
  });

  factory TagihanResponse.fromJson(Map<String, dynamic> json) {
    final dataList = (json['data']['data'] as List<dynamic>)
        .map((item) => TagihanModel.fromJson(item as Map<String, dynamic>))
        .toList();

    return TagihanResponse(
      data: dataList,
      pagination: PaginationInfo.fromJson(json['data']),
    );
  }
}

class PaginationInfo {
  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;
  final String? nextPageUrl;
  final String? prevPageUrl;

  PaginationInfo({
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
    required this.total,
    this.nextPageUrl,
    this.prevPageUrl,
  });

  factory PaginationInfo.fromJson(Map<String, dynamic> json) {
    return PaginationInfo(
      currentPage: json['current_page'] as int,
      lastPage: json['last_page'] as int,
      perPage: json['per_page'] as int,
      total: json['total'] as int,
      nextPageUrl: json['next_page_url']?.toString(),
      prevPageUrl: json['prev_page_url']?.toString(),
    );
  }
}

class TagihanDetailResponse {
  final TagihanModel data;

  TagihanDetailResponse({
    required this.data,
  });

  factory TagihanDetailResponse.fromJson(Map<String, dynamic> json) {
    return TagihanDetailResponse(
      data: TagihanModel.fromJson(json['data'] as Map<String, dynamic>),
    );
  }
}

class KategoriTagihanResponse {
  final List<KategoriTagihanModel> data;

  KategoriTagihanResponse({
    required this.data,
  });

  factory KategoriTagihanResponse.fromJson(Map<String, dynamic> json) {
    final dataList = (json['data'] as List<dynamic>)
        .map((item) =>
            KategoriTagihanModel.fromJson(item as Map<String, dynamic>))
        .toList();

    return KategoriTagihanResponse(
      data: dataList,
    );
  }
}

class KategoriTagihanModel {
  final int id;
  final String nama;
  final List<SubKategoriTagihan> subKategori;

  KategoriTagihanModel({
    required this.id,
    required this.nama,
    required this.subKategori,
  });

  factory KategoriTagihanModel.fromJson(Map<String, dynamic> json) {
    final subKategoriList = (json['sub_kategori'] as List<dynamic>)
        .map(
            (item) => SubKategoriTagihan.fromJson(item as Map<String, dynamic>))
        .toList();

    return KategoriTagihanModel(
      id: json['id'] as int,
      nama: json['nama'] as String,
      subKategori: subKategoriList,
    );
  }
}
