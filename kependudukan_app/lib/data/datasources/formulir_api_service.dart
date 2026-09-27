import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:ladimas/core/constants/app_constants.dart';
import 'package:ladimas/data/models/formulir_model.dart';
import 'package:ladimas/data/datasources/auth_local_storage.dart';

class FormulirApiService {
  final http.Client client;
  final AuthLocalStorage authLocalStorage;

  FormulirApiService({
    required this.client,
    required this.authLocalStorage,
  });

  Future<List<FormulirModel>> getActiveFormulirs() async {
    final token = await authLocalStorage.getStoredToken();
    if (token == null || token.isEmpty) {
      return [];
    }

    String bearer = token;
    if (bearer.contains('|')) {
      bearer = bearer.split('|')[1].trim();
    }

    final url = '${AppConstants.authApiUrl}/user/formulir';
    
    final response = await client.get(
      Uri.parse(url),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $bearer',
        'X-API-Key': AppConstants.apiKey,
      },
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      final List formulirsJson = data['data'] ?? [];
      return formulirsJson.map((j) => FormulirModel.fromJson(j)).toList();
    } else {
      throw Exception('Gagal memuat daftar formulir: ${response.statusCode}');
    }
  }

  Future<bool> submitFormulir(int id, Map<String, dynamic> answers) async {
    final token = await authLocalStorage.getStoredToken();
    if (token == null || token.isEmpty) {
      return false;
    }

    String bearer = token;
    if (bearer.contains('|')) {
      bearer = bearer.split('|')[1].trim();
    }

    final url = '${AppConstants.authApiUrl}/user/formulir/$id/submit';
    final response = await client.post(
      Uri.parse(url),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $bearer',
        'X-API-Key': AppConstants.apiKey,
      },
      body: json.encode({'answers': answers}),
    );

    return response.statusCode == 200;
  }
}
