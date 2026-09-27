import 'package:ladimas/domain/entities/family_member.dart';

class FamilyMemberModel extends FamilyMember {
  const FamilyMemberModel({
    required super.nik,
    required super.fullName,
    required super.familyStatus,
    super.coordinate,
    super.address,
    super.provinceId,
    super.districtId,
    super.subDistrictId,
    super.villageId,
  });

  static int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  factory FamilyMemberModel.fromJson(Map<String, dynamic> json) {
    return FamilyMemberModel(
      nik: json['nik']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      familyStatus: json['family_status']?.toString() ?? '',
      coordinate: (json['domisili_tag_lokasi'] ?? json['tag_lokasi'] ?? json['coordinate'])?.toString(),
      address: (json['domisili_alamat'] ?? json['alamat'] ?? json['address'])?.toString(),
      provinceId: _toInt(json['domisili_province_id'] ?? json['province_id']),
      districtId: _toInt(json['domisili_district_id'] ?? json['district_id']),
      subDistrictId: _toInt(json['domisili_sub_district_id'] ?? json['sub_district_id']),
      villageId: _toInt(json['domisili_village_id'] ?? json['village_id']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nik': nik,
      'full_name': fullName,
      'family_status': familyStatus,
      'coordinate': coordinate,
      'address': address,
      'province_id': provinceId,
      'district_id': districtId,
      'sub_district_id': subDistrictId,
      'village_id': villageId,
    };
  }

  FamilyMemberModel copyWith({
    String? nik,
    String? fullName,
    String? familyStatus,
    String? coordinate,
    String? address,
    int? provinceId,
    int? districtId,
    int? subDistrictId,
    int? villageId,
  }) {
    return FamilyMemberModel(
      nik: nik ?? this.nik,
      fullName: fullName ?? this.fullName,
      familyStatus: familyStatus ?? this.familyStatus,
      coordinate: coordinate ?? this.coordinate,
      address: address ?? this.address,
      provinceId: provinceId ?? this.provinceId,
      districtId: districtId ?? this.districtId,
      subDistrictId: subDistrictId ?? this.subDistrictId,
      villageId: villageId ?? this.villageId,
    );
  }
}
