import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:ladimas/core/constants/app_constants.dart';
import 'package:ladimas/core/errors/exception.dart';
import 'package:ladimas/data/models/jenis_aset_model.dart';

class JenisAsetApiService {
  final http.Client client;

  JenisAsetApiService({required this.client});

  Future<List<JenisAsetModel>> getJenisAset() async {
    try {
      final response = await client.get(
        Uri.parse('${AppConstants.authApiUrl}/jenis-aset'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'X-API-Key': AppConstants.apiKey,
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);

        if (jsonResponse['status'] == "success") {
          final List<dynamic> jenisAsetList = jsonResponse['data'];
          return jenisAsetList
              .map((json) => JenisAsetModel.fromJson(json))
              .toList();
        } else {
          throw ServerException(
              message: jsonResponse['message'] ?? 'Failed to get jenis aset');
        }
      } else {
        throw ServerException(message: 'Server error: ${response.statusCode}');
      }
    } catch (e) {
      if (e is ServerException) {
        rethrow;
      }
      throw ServerException(
          message: 'Failed to get jenis aset: ${e.toString()}');
    }
  }
}
