import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:ladimas/core/constants/app_constants.dart';
import 'package:ladimas/core/errors/exception.dart';
import 'package:ladimas/data/models/klasifikasi_model.dart';

class KlasifikasiApiService {
  final http.Client client;

  KlasifikasiApiService({required this.client});

  Future<List<KlasifikasiModel>> getKlasifikasi() async {
    try {
      final response = await client.get(
        Uri.parse('${AppConstants.authApiUrl}/klasifikasi'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'X-API-Key': AppConstants.apiKey,
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);

        if (jsonResponse['status'] == "success") {
          final List<dynamic> klasifikasiList = jsonResponse['data'];
          return klasifikasiList
              .map((json) => KlasifikasiModel.fromJson(json))
              .toList();
        } else {
          throw ServerException(
              message:
                  jsonResponse['message'] ?? 'Failed to get classifications');
        }
      } else {
        throw ServerException(message: 'Server error: ${response.statusCode}');
      }
    } catch (e) {
      if (e is ServerException) {
        rethrow;
      }
      throw ServerException(
          message: 'Failed to get classifications: ${e.toString()}');
    }
  }
}
