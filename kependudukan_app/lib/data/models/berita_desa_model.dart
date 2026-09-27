class BeritaDesaModel {
  final int id;
  final String judul;
  final String deskripsi;
  final String komentar;
  final String gambar;
  final String gambarUrl;
  final int userId;
  final String createdAt;
  final String updatedAt;
  final Map<String, dynamic>? wilayahInfo;
  final int? villageId;

  BeritaDesaModel({
    required this.id,
    required this.judul,
    required this.deskripsi,
    required this.komentar,
    required this.gambar,
    required this.gambarUrl,
    required this.userId,
    required this.createdAt,
    required this.updatedAt,
    this.wilayahInfo,
    this.villageId,
  });

  factory BeritaDesaModel.fromJson(Map<String, dynamic> json) {
    return BeritaDesaModel(
      id: (json['id'] ?? 0) as int,
      judul: (json['judul'] ?? '') as String,
      deskripsi: (json['deskripsi'] ?? '') as String,
      komentar: (json['komentar'] ?? '') as String,
      gambar: (json['gambar'] ?? '') as String,
      gambarUrl: (json['gambar_url'] ?? '') as String,
      userId: (json['user_id'] ?? 0) as int,
      createdAt: (json['created_at'] ?? '') as String,
      updatedAt: (json['updated_at'] ?? '') as String,
      wilayahInfo: json['wilayah_info'] is Map<String, dynamic>
          ? (json['wilayah_info'] as Map<String, dynamic>)
          : null,
      villageId: _parseVillageId(json),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'judul': judul,
      'deskripsi': deskripsi,
      'komentar': komentar,
      'gambar': gambar,
      'gambar_url': gambarUrl,
      'user_id': userId,
      'created_at': createdAt,
      'updated_at': updatedAt,
      if (wilayahInfo != null) 'wilayah_info': wilayahInfo,
      if (villageId != null) 'villages_id': villageId,
    };
  }

  static int? _parseVillageId(Map<String, dynamic> json) {
    try {
      // Check for villages_id first (new API field)
      if (json.containsKey('villages_id')) {
        final dynamic v = json['villages_id'];
        if (v is int) return v;
        return int.tryParse('$v');
      }
      if (json.containsKey('village_id')) {
        final dynamic v = json['village_id'];
        if (v is int) return v;
        return int.tryParse('$v');
      }
      if (json.containsKey('desa_id')) {
        final dynamic v = json['desa_id'];
        if (v is int) return v;
        return int.tryParse('$v');
      }
      if (json['village'] is Map<String, dynamic>) {
        final dynamic v = (json['village'] as Map<String, dynamic>)['id'];
        if (v is int) return v;
        return int.tryParse('$v');
      }
      if (json['desa'] is Map<String, dynamic>) {
        final dynamic v = (json['desa'] as Map<String, dynamic>)['id'];
        if (v is int) return v;
        return int.tryParse('$v');
      }
      if (json['wilayah_info'] is Map<String, dynamic>) {
        final Map<String, dynamic> wi = json['wilayah_info'];
        if (wi.containsKey('villages_id')) {
          final dynamic v = wi['villages_id'];
          if (v is int) return v;
          return int.tryParse('$v');
        }
        if (wi.containsKey('village_id')) {
          final dynamic v = wi['village_id'];
          if (v is int) return v;
          return int.tryParse('$v');
        }
        if (wi.containsKey('desa_id')) {
          final dynamic v = wi['desa_id'];
          if (v is int) return v;
          return int.tryParse('$v');
        }
        if (wi['village'] is Map<String, dynamic>) {
          final dynamic v = (wi['village'] as Map<String, dynamic>)['id'];
          if (v is int) return v;
          return int.tryParse('$v');
        }
        if (wi['desa'] is Map<String, dynamic>) {
          final dynamic v = (wi['desa'] as Map<String, dynamic>)['id'];
          if (v is int) return v;
          return int.tryParse('$v');
        }
      }
    } catch (_) {}
    return null;
  }
}
