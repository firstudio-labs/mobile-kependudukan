class VillageReportModel {
  final int id;
  final int laporDesaId;
  final String judulLaporan;
  final String deskripsiLaporan;
  final String gambar;
  final String tagLokasi;
  final String lokasi; // alamat lokasi (jika tersedia)
  final String status;
  final int userId;
  final int villageId;
  final DateTime createdAt;
  final DateTime updatedAt;

  VillageReportModel({
    required this.id,
    required this.laporDesaId,
    required this.judulLaporan,
    required this.deskripsiLaporan,
    required this.gambar,
    required this.tagLokasi,
    required this.lokasi,
    required this.status,
    required this.userId,
    required this.villageId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory VillageReportModel.fromJson(Map<String, dynamic> json) {
    // Helper function to safely convert values to int
    int parseIntSafely(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? 0;
      if (value is double) return value.toInt();
      return 0;
    }

    return VillageReportModel(
      id: parseIntSafely(json['id']),
      laporDesaId: parseIntSafely(json['lapor_desa_id']),
      judulLaporan: json['judul_laporan'] ?? '',
      deskripsiLaporan: json['deskripsi_laporan'] ?? '',
      gambar: json['gambar'] ?? '',
      tagLokasi: json['tag_lokasi'] ?? '',
      lokasi: json['lokasi'] ?? '',
      status: json['status'] ?? '',
      userId: parseIntSafely(json['user_id']),
      villageId: parseIntSafely(json['village_id']),
      createdAt: DateTime.parse(
          json['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(
          json['updated_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'lapor_desa_id': laporDesaId,
      'judul_laporan': judulLaporan,
      'deskripsi_laporan': deskripsiLaporan,
      'gambar': gambar,
      'tag_lokasi': tagLokasi,
      'lokasi': lokasi,
      'status': status,
      'user_id': userId,
      'village_id': villageId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
