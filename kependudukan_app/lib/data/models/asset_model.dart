import 'package:equatable/equatable.dart';

class AssetModel extends Equatable {
  final int id;
  final String namaAset;
  final String namaPemilik;
  final String nikPemilik;
  final String alamat;
  final String? fotoDepan;
  final String? fotoSamping;
  final String? tagLokasi;
  final String klasifikasi;
  final String jenisAset;
  final String? rt;
  final String? rw;
  final String? provinceName;
  final String? districtName;
  final String? subdistrictName;
  final String? villageName;
  final KlasifikasiModel klasifikasiDetail;
  final JenisAsetModel jenisAsetDetail;
  final DateTime? createdAt;
  final int? provinceId;
  final int? districtId;
  final int? subdistrictId;
  final int? villageId;

  const AssetModel({
    required this.id,
    required this.namaAset,
    required this.namaPemilik,
    required this.nikPemilik,
    required this.alamat,
    this.fotoDepan,
    this.fotoSamping,
    this.tagLokasi,
    required this.klasifikasi,
    required this.jenisAset,
    this.rt,
    this.rw,
    this.provinceName,
    this.districtName,
    this.subdistrictName,
    this.villageName,
    required this.klasifikasiDetail,
    required this.jenisAsetDetail,
    this.createdAt,
    this.provinceId,
    this.districtId,
    this.subdistrictId,
    this.villageId,
  });

  factory AssetModel.fromJson(Map<String, dynamic> json) {
    return AssetModel(
      id: json['id'],
      namaAset: json['nama_aset'] ?? '',
      namaPemilik: json['nama_pemilik'] ?? '',
      nikPemilik: json['nik_pemilik'] ?? '',
      alamat: json['address'] ?? '',
      fotoDepan: json['foto_aset_depan'],
      fotoSamping: json['foto_aset_samping'],
      tagLokasi: json['tag_lokasi'],
      rt: json['rt']?.toString() ?? '',
      rw: json['rw']?.toString() ?? '',
      provinceId: json['province_id'],
      districtId: json['district_id'],
      subdistrictId: json['sub_district_id'],
      villageId: json['village_id'],
      provinceName: '', // Will be populated later
      districtName: '', // Will be populated later
      subdistrictName: '', // Will be populated later
      villageName: '', // Will be populated later
      klasifikasi: json['klasifikasi']?['jenis_klasifikasi'] ?? '',
      jenisAset: json['jenis_aset']?['jenis_aset'] ?? '',
      klasifikasiDetail: json['klasifikasi'] != null
          ? KlasifikasiModel.fromJson(json['klasifikasi'])
          : KlasifikasiModel.empty(),
      jenisAsetDetail: json['jenis_aset'] != null
          ? JenisAsetModel.fromJson(json['jenis_aset'])
          : JenisAsetModel.empty(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  @override
  List<Object?> get props => [
        id,
        namaAset,
        namaPemilik,
        nikPemilik,
        alamat,
        fotoDepan,
        fotoSamping,
        tagLokasi,
        klasifikasi,
        jenisAset,
        rt,
        rw,
        provinceName,
        districtName,
        subdistrictName,
        villageName,
        klasifikasiDetail,
        jenisAsetDetail,
        createdAt,
        provinceId,
        districtId,
        subdistrictId,
        villageId
      ];
}

class KlasifikasiModel extends Equatable {
  final int id;
  final int kode;
  final String jenisKlasifikasi;
  final String keterangan;

  const KlasifikasiModel({
    required this.id,
    required this.kode,
    required this.jenisKlasifikasi,
    required this.keterangan,
  });

  factory KlasifikasiModel.fromJson(Map<String, dynamic> json) {
    return KlasifikasiModel(
      id: json['id'] ?? 0,
      kode: json['kode'] ?? 0,
      jenisKlasifikasi: json['jenis_klasifikasi'] ?? '',
      keterangan: json['keterangan'] ?? '',
    );
  }

  factory KlasifikasiModel.empty() {
    return const KlasifikasiModel(
        id: 0, kode: 0, jenisKlasifikasi: '', keterangan: '');
  }

  @override
  List<Object?> get props => [id, kode, jenisKlasifikasi, keterangan];
}

class JenisAsetModel extends Equatable {
  final int id;
  final int kode;
  final String jenisAset;
  final String keterangan;

  const JenisAsetModel({
    required this.id,
    required this.kode,
    required this.jenisAset,
    required this.keterangan,
  });

  factory JenisAsetModel.fromJson(Map<String, dynamic> json) {
    return JenisAsetModel(
      id: json['id'] ?? 0,
      kode: json['kode'] ?? 0,
      jenisAset: json['jenis_aset'] ?? '',
      keterangan: json['keterangan'] ?? '',
    );
  }

  factory JenisAsetModel.empty() {
    return const JenisAsetModel(id: 0, kode: 0, jenisAset: '', keterangan: '');
  }

  @override
  List<Object?> get props => [id, kode, jenisAset, keterangan];
}
