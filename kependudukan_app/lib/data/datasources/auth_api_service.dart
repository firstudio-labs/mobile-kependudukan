import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:ladimas/core/constants/app_constants.dart';
import 'package:ladimas/core/errors/exception.dart';
import 'package:ladimas/data/models/penduduk_model.dart';

class AuthApiService {
  final http.Client client;

  AuthApiService({required this.client});

  Future<PendudukModel> login(String nik, String password) async {
    try {
      final response = await client.post(
        Uri.parse('${AppConstants.authApiUrl}${AppConstants.endpointLogin}'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-API-Key': AppConstants.apiKey,
        },
        body: json.encode({
          'nik': nik,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);

        if (jsonResponse['status'] == true) {
          return PendudukModel.fromAuthResponse(jsonResponse);
        } else {
          throw AuthException(
              message: jsonResponse['message'] ?? AppConstants.errorAuthFailed);
        }
      } else if (response.statusCode == 401 || response.statusCode == 422) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);
        throw AuthException(
            message: jsonResponse['message'] ?? AppConstants.errorAuthFailed);
      } else {
        throw ServerException(message: 'Server error: ${response.statusCode}');
      }
    } catch (e) {
      if (e is AuthException || e is ServerException) {
        rethrow;
      }
      throw ServerException(message: 'Login failed: ${e.toString()}');
    }
  }

  /// Get raw login response untuk mendapatkan data tambahan seperti alamat dan tag_lokasi
  Future<Map<String, dynamic>?> getRawLoginResponse(
      String nik, String password) async {
    try {
      final response = await client.post(
        Uri.parse('${AppConstants.authApiUrl}${AppConstants.endpointLogin}'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-API-Key': AppConstants.apiKey,
        },
        body: json.encode({
          'nik': nik,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);
        if (jsonResponse['status'] == true) {
          return jsonResponse;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>> adminLogin(
      String nikOrUsername, String password) async {
    try {
      final response = await client.post(
        Uri.parse(
            '${AppConstants.authApiUrl}${AppConstants.endpointAdminLogin}'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-API-Key': AppConstants.apiKey,
        },
        body: json.encode({
          'nik': nikOrUsername,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);
        if (jsonResponse['status'] == true) {
          return jsonResponse['data'] as Map<String, dynamic>;
        } else {
          throw AuthException(
              message: jsonResponse['message'] ?? AppConstants.errorAuthFailed);
        }
      } else if (response.statusCode == 401 || response.statusCode == 422) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);
        throw AuthException(
            message: jsonResponse['message'] ?? AppConstants.errorAuthFailed);
      } else {
        throw ServerException(message: 'Server error: ${response.statusCode}');
      }
    } catch (e) {
      if (e is AuthException || e is ServerException) {
        rethrow;
      }
      throw ServerException(message: 'Login admin failed: ${e.toString()}');
    }
  }

  Future<PendudukModel> register(
      String nik, String password, String noHp) async {
    try {
      final response = await client.post(
        Uri.parse('${AppConstants.authApiUrl}${AppConstants.endpointRegister}'),
        headers: {
          'X-API-Key': AppConstants.apiKey,
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({
          'nik': nik,
          'no_hp': noHp,
          'password': password,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);

        if (jsonResponse['status'] == true) {
          return PendudukModel.fromAuthResponse(jsonResponse);
        } else {
          // Gunakan pesan API jika ada, lokalisasi jika perlu
          final raw =
              (jsonResponse['message'] ?? 'Registrasi gagal').toString();
          throw AuthException(message: _localizeValidationMessage(raw));
        }
      } else if (response.statusCode == 422) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);

        // Ambil detail error jika tersedia
        String errorMessage;
        if (jsonResponse['errors'] != null) {
          errorMessage = _formatValidationErrors(jsonResponse['errors']);
        } else if (jsonResponse['message'] != null) {
          errorMessage = jsonResponse['message'].toString();
        } else {
          errorMessage = AppConstants.errorValidationMessage;
        }

        // Lokalisasi pesan umum dari backend (EN -> ID)
        errorMessage = _localizeValidationMessage(errorMessage);

        throw ValidationException(message: errorMessage);
      } else {
        throw ServerException(message: 'Server error: ${response.statusCode}');
      }
    } catch (e) {
      if (e is AuthException ||
          e is ServerException ||
          e is ValidationException) {
        rethrow;
      }
      throw ServerException(message: 'Registration failed: ${e.toString()}');
    }
  }

  String _formatValidationErrors(Map<String, dynamic> errors) {
    // Prioritaskan pesan spesifik per-field bila ada
    try {
      if (errors.containsKey('nik')) {
        final nikErrors = errors['nik'];
        if (nikErrors is List && nikErrors.isNotEmpty) {
          return _localizeValidationMessage(nikErrors.first.toString());
        }
      }
      if (errors.containsKey('no_hp')) {
        final hpErrors = errors['no_hp'];
        if (hpErrors is List && hpErrors.isNotEmpty) {
          return _localizeValidationMessage(hpErrors.first.toString());
        }
      }
      if (errors.containsKey('password')) {
        final passErrors = errors['password'];
        if (passErrors is List && passErrors.isNotEmpty) {
          return _localizeValidationMessage(passErrors.first.toString());
        }
      }

      // Fallback: gabungkan semua pesan
      final List<String> errorMessages = [];
      errors.forEach((key, value) {
        if (value is List && value.isNotEmpty) {
          errorMessages.add(_localizeValidationMessage(value.first.toString()));
        } else if (value != null) {
          errorMessages.add(_localizeValidationMessage(value.toString()));
        }
      });

      if (errorMessages.isEmpty) return AppConstants.errorValidationMessage;
      return errorMessages.join(', ');
    } catch (_) {
      return AppConstants.errorValidationMessage;
    }
  }

  String _localizeValidationMessage(String message) {
    final lower = message.toLowerCase();

    // Pola umum dari backend (Laravel/others)
    if (lower.contains('has already been taken') ||
        lower.contains('already taken')) {
      if (lower.contains('nik')) return 'NIK sudah terdaftar dalam sistem.';
      if (lower.contains('no hp') ||
          lower.contains('no_hp') ||
          lower.contains('phone')) {
        return 'Nomor HP sudah terdaftar.';
      }
      return 'Data sudah terdaftar.';
    }

    if (lower.contains('required')) {
      if (lower.contains('nik')) return 'NIK wajib diisi.';
      if (lower.contains('password')) return 'Password wajib diisi.';
      if (lower.contains('no hp') ||
          lower.contains('no_hp') ||
          lower.contains('phone')) {
        return 'Nomor HP wajib diisi.';
      }
      return 'Field wajib diisi.';
    }

    if (lower.contains('invalid') || lower.contains('not valid')) {
      if (lower.contains('nik')) return 'NIK tidak valid.';
      if (lower.contains('password')) return 'Password tidak valid.';
      if (lower.contains('phone') || lower.contains('no_hp'))
        return 'Nomor HP tidak valid.';
      return 'Data tidak valid.';
    }

    if (lower.contains('min') && lower.contains('characters')) {
      if (lower.contains('password')) return 'Password minimal 6 karakter.';
    }

    // Kembalikan pesan asli bila tidak terpetakan
    return message;
  }

  Future<PendudukModel> getUserFromResponse(
      Map<String, dynamic> responseData) async {
    try {
      // Extract user data from the response
      final userData = responseData['data'] ?? responseData;

      // Create and return a PendudukModel instance
      return PendudukModel(
        nik: userData['nik'] ?? '',
        noHp: userData['no_hp'] ?? '',
        name: userData['full_name'] ?? userData['name'] ?? '',
      );
    } catch (e) {
      throw ServerException(
        message: 'Failed to parse user data: ${e.toString()}',
      );
    }
  }

  Future<Map<String, dynamic>> verifyCredentials(
      String nik, String password) async {
    try {
      final response = await client.post(
        Uri.parse('${AppConstants.authApiUrl}${AppConstants.endpointLogin}'),
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': AppConstants.apiKey,
        },
        body: json.encode({
          'nik': nik,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw AuthException(message: 'Invalid credentials');
      }
    } catch (e) {
      if (e is AuthException) rethrow;
      throw ServerException(
          message: 'Error verifying credentials: ${e.toString()}');
    }
  }

  Future<bool> registerUser(String nik, String password, String noHp) async {
    try {
      final response = await client.post(
        Uri.parse('${AppConstants.authApiUrl}${AppConstants.endpointRegister}'),
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': AppConstants.apiKey,
        },
        body: json.encode({
          'nik': nik,
          'password': password,
          'no_hp': noHp,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else {
        final errorData = json.decode(response.body);
        throw ServerException(
          message: errorData['message'] ?? 'Registration failed',
        );
      }
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(
          message: 'Error during registration: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> loginPenduduk(
      String nik, String password) async {
    try {
      final response = await client.post(
        Uri.parse('${AppConstants.authApiUrl}${AppConstants.endpointLogin}'),
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': AppConstants.apiKey,
        },
        body: json.encode({'nik': nik, 'password': password}),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw AuthException(message: AppConstants.errorAuthFailed);
      }
    } catch (e) {
      if (e is AuthException) rethrow;
      throw ServerException(message: 'Login error: ${e.toString()}');
    }
  }

  Future<bool> registerPenduduk(
    String nik,
    String password,
    String noHp,
  ) async {
    try {
      final response = await client.post(
        Uri.parse('${AppConstants.authApiUrl}${AppConstants.endpointRegister}'),
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': AppConstants.apiKey,
        },
        body: json.encode({
          'nik': nik,
          'password': password,
          'no_hp': noHp,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else {
        throw ServerException(
            message: 'Registration failed: ${response.statusCode}');
      }
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(message: 'Registration error: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> getUserProfile(String token) async {
    try {
      final response = await client.get(
        Uri.parse('${AppConstants.authApiUrl}/user/profile'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
          'X-API-Key': AppConstants.apiKey,
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);
        if (jsonResponse['success'] == true && jsonResponse['data'] != null) {
          return jsonResponse['data'];
        } else {
          throw ServerException(
              message: jsonResponse['message'] ?? 'Failed to get user profile');
        }
      } else {
        final errorData = json.decode(response.body);
        throw ServerException(
            message: errorData['message'] ??
                'Failed to get user profile: ${response.statusCode}');
      }
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(
          message: 'Error getting user profile: ${e.toString()}');
    }
  }
}
