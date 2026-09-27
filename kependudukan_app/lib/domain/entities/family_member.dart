import 'package:equatable/equatable.dart';

class FamilyMember extends Equatable {
  final String nik;
  final String fullName;
  final String familyStatus;
  final String? coordinate;
  final String? address;
  final int? provinceId;
  final int? districtId;
  final int? subDistrictId;
  final int? villageId;

  const FamilyMember({
    required this.nik,
    required this.fullName,
    required this.familyStatus,
    this.coordinate,
    this.address,
    this.provinceId,
    this.districtId,
    this.subDistrictId,
    this.villageId,
  });

  @override
  List<Object?> get props => [
        nik,
        fullName,
        familyStatus,
        coordinate,
        address,
        provinceId,
        districtId,
        subDistrictId,
        villageId,
      ];
}
