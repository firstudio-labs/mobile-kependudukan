class AgendaModel {
  final int id;
  final String judul;
  final String deskripsi;
  final String gambar;
  final String gambarUrl;
  final String alamat;
  final String tagLokasi;
  final int userId;
  final int? provinceId;
  final int? districtsId;
  final int? subDistrictsId;
  final int? villagesId;
  final String createdAt;
  final String updatedAt;
  final Map<String, dynamic>? wilayahInfo;

  AgendaModel({
    required this.id,
    required this.judul,
    required this.deskripsi,
    required this.gambar,
    required this.gambarUrl,
    required this.alamat,
    required this.tagLokasi,
    required this.userId,
    this.provinceId,
    this.districtsId,
    this.subDistrictsId,
    this.villagesId,
    required this.createdAt,
    required this.updatedAt,
    this.wilayahInfo,
  });

  factory AgendaModel.fromJson(Map<String, dynamic> json) {
    return AgendaModel(
      id: (json['id'] ?? 0) as int,
      judul: (json['judul'] ?? '') as String,
      deskripsi: (json['deskripsi'] ?? '') as String,
      gambar: (json['gambar'] ?? '') as String,
      gambarUrl: (json['gambar_url'] ?? '') as String,
      alamat: (json['alamat'] ?? '') as String,
      tagLokasi: (json['tag_lokasi'] ?? '') as String,
      userId: (json['user_id'] ?? 0) as int,
      provinceId: json['province_id'] != null
          ? int.tryParse(json['province_id'].toString())
          : null,
      districtsId: json['districts_id'] != null
          ? int.tryParse(json['districts_id'].toString())
          : null,
      subDistrictsId: json['sub_districts_id'] != null
          ? int.tryParse(json['sub_districts_id'].toString())
          : null,
      villagesId: json['villages_id'] != null
          ? int.tryParse(json['villages_id'].toString())
          : null,
      createdAt: (json['created_at'] ?? '') as String,
      updatedAt: (json['updated_at'] ?? '') as String,
      wilayahInfo: json['wilayah_info'] is Map<String, dynamic>
          ? (json['wilayah_info'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'judul': judul,
      'deskripsi': deskripsi,
      'gambar': gambar,
      'gambar_url': gambarUrl,
      'alamat': alamat,
      'tag_lokasi': tagLokasi,
      'user_id': userId,
      if (provinceId != null) 'province_id': provinceId,
      if (districtsId != null) 'districts_id': districtsId,
      if (subDistrictsId != null) 'sub_districts_id': subDistrictsId,
      if (villagesId != null) 'villages_id': villagesId,
      'created_at': createdAt,
      'updated_at': updatedAt,
      if (wilayahInfo != null) 'wilayah_info': wilayahInfo,
    };
  }
}
