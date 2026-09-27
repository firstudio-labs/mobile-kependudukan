import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConstants {
  static const String appName = 'LADIMAS';
  static const String dbName = 'kependudukan.db';
  static const int dbVersion = 2;

  static String get apiUrl => dotenv.env['API_URL'] ?? '';
  static String get authApiUrl => dotenv.env['AUTH_API_URL'] ?? '';
  static String get storageUrl => dotenv.env['STORAGE_URL'] ?? '';
  static String get apiKey => dotenv.env['API_KEY'] ?? '';

  /// Base URL untuk Go API.
  /// Jika `API_URL` tidak sengaja diisi dengan suffix `/api`, kita strip supaya
  /// pemanggilan seperti `${goBaseUrl}/api/...` tidak jadi double `/api/api/...`.
  static String get goBaseUrl {
    var v = (dotenv.env['API_URL'] ?? '').trim();
    if (v.endsWith('/')) v = v.substring(0, v.length - 1);
    if (v.toLowerCase().endsWith('/api')) v = v.substring(0, v.length - 4);
    return v;
  }

  /// Base URL storage (Laravel). Jika kosong, fallback ke domain production (legacy).
  static String get storageBaseUrl {
    var v = (dotenv.env['STORAGE_URL'] ?? '').trim();
    if (v.endsWith('/')) v = v.substring(0, v.length - 1);
    if (v.isEmpty) return 'https://pelayanan.desaverse.id/storage';
    return v;
  }

  /// Bangun URL file storage yang aman:
  /// - kalau `path` sudah URL lengkap -> return apa adanya
  /// - kalau `path` kosong -> return ''
  /// - selain itu -> join dengan `storageBaseUrl`
  static String storageFileUrl(String? path) {
    final p = (path ?? '').trim();
    if (p.isEmpty) return '';
    if (p.startsWith('http://') || p.startsWith('https://')) return p;
    final base = storageBaseUrl;
    final clean = p.startsWith('/') ? p.substring(1) : p;
    return '$base/$clean';
  }

  // Cek NIK sekarang gunakan endpoint ringan (tanpa tarik semua data).
  static const String endpointCheckNik = '/api/v2/citizens/exists';
  static const String endpointRegister = '/register';
  static const String endpointLogin = '/login';
  static const String endpointAdminLogin = '/admin/login';

  static const String errorNetworkMessage =
      'Tidak ada koneksi internet. Periksa koneksi Anda dan coba lagi.';
  static const String errorRegistrationFailed = 'Registrasi gagal: ';
  static const String error404Message =
      'Endpoint tidak ditemukan. Hubungi administrator.';

  static const String errorAuthFailed = 'NIK atau password tidak valid.';
  static const String errorNikExists = 'NIK sudah terdaftar dalam sistem.';
  static const String errorNikNotFound = 'NIK tidak ditemukan dalam sistem.';
  static const String errorInvalidCredentials = 'NIK atau password salah.';
  static const String errorAccountLocked =
      'Akun Anda telah diblokir. Hubungi admin.';
  static const String errorSessionExpired =
      'Sesi Anda telah berakhir. Silakan login kembali.';
  static const String successRegistration =
      'Registrasi berhasil! Silakan login dengan akun baru Anda.';
  static const String errorServerMessage =
      'Terjadi kesalahan pada server. Silakan coba beberapa saat lagi.';
  static const String errorTimeoutMessage =
      'Koneksi timeout. Periksa koneksi internet Anda.';
  static const String errorValidationMessage =
      'Data yang dimasukkan tidak valid. Periksa kembali.';

  static const bool isDebugMode = true;
}

// UI Related constants
class UiConstants {
  static const double defaultPadding = 16.0;
  static const double borderRadius = 12.0;
  static const Duration animationDuration = Duration(milliseconds: 300);
}

// Network Related constants
class NetworkConstants {
  static const Duration defaultTimeout = Duration(seconds: 30);
  static const Duration shortTimeout = Duration(seconds: 15);
  static const Duration longTimeout = Duration(seconds: 60);
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 2);
}
