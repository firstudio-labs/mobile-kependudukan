import 'package:ladimas/domain/entities/penduduk.dart';

class PendudukModel extends Penduduk {
  final String? accessToken;
  final String? tokenType;

  const PendudukModel({
    required String nik,
    required String noHp,
    String name = '',
    this.accessToken,
    this.tokenType,
  }) : super(
          nik: nik,
          noHp: noHp,
          name: name,
          token: accessToken ?? '',
        );

  factory PendudukModel.fromJson(Map<String, dynamic> json) {
    return PendudukModel(
      nik: json['nik'],
      noHp: json['no_hp'] ?? '',
      name: json['full_name'] ?? '',
      accessToken: json['access_token'],
      tokenType: json['token_type'],
    );
  }

  factory PendudukModel.fromAuthResponse(Map<String, dynamic> json) {
    final userData = json['data']['user'];
    return PendudukModel(
      nik: userData['nik'],
      noHp: userData['no_hp'] ?? '',
      name: userData['full_name'] ?? userData['name'] ?? '',
      accessToken: json['data']['access_token'],
      tokenType: json['data']['token_type'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nik': nik,
      'no_hp': noHp,
      'full_name': name,
      'access_token': accessToken,
      'token_type': tokenType,
    };
  }

  PendudukModel copyWith({
    String? nik,
    String? noHp,
    String? name,
    String? accessToken,
    String? tokenType,
  }) {
    return PendudukModel(
      nik: nik ?? this.nik,
      noHp: noHp ?? this.noHp,
      name: name ?? this.name,
      accessToken: accessToken ?? this.accessToken,
      tokenType: tokenType ?? this.tokenType,
    );
  }
}
