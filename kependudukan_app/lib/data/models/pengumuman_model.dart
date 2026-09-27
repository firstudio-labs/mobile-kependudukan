class PengumumanModel {
  final int id;
  final String judul;
  final String deskripsi;
  final String gambar;
  final String gambarUrl;
  final String createdAt;
  final String updatedAt;

  PengumumanModel({
    required this.id,
    required this.judul,
    required this.deskripsi,
    required this.gambar,
    required this.gambarUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PengumumanModel.fromJson(Map<String, dynamic> json) {
    return PengumumanModel(
      id: (json['id'] ?? 0) as int,
      judul: (json['judul'] ?? '') as String,
      deskripsi: (json['deskripsi'] ?? '') as String,
      gambar: (json['gambar'] ?? '') as String,
      gambarUrl: (json['gambar_url'] ?? '') as String,
      createdAt: (json['created_at'] ?? '') as String,
      updatedAt: (json['updated_at'] ?? '') as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'judul': judul,
      'deskripsi': deskripsi,
      'gambar': gambar,
      'gambar_url': gambarUrl,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}
