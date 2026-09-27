import 'package:dartz/dartz.dart';
import 'package:ladimas/core/constants/app_constants.dart';
import 'package:ladimas/core/errors/exception.dart' as exc;
import 'package:ladimas/core/errors/failures.dart';
import 'package:ladimas/core/network/network_info.dart';
import 'package:ladimas/data/datasources/asset_api_service.dart';
import 'package:ladimas/data/datasources/auth_api_service.dart';
import 'package:ladimas/data/datasources/auth_local_storage.dart';
import 'package:ladimas/data/datasources/penduduk_api_service.dart';
import 'package:ladimas/domain/entities/penduduk.dart';
import 'package:ladimas/domain/repositories/auth_repository.dart';
import 'package:get_it/get_it.dart';

class AuthRepositoryImpl implements AuthRepository {
  final PendudukApiService pendudukApiService;
  final AuthApiService authApiService;
  final NetworkInfo networkInfo;
  final AuthLocalStorage authLocalStorage;

  AuthRepositoryImpl({
    required this.pendudukApiService,
    required this.authApiService,
    required this.networkInfo,
    required this.authLocalStorage,
  });

  @override
  Future<Either<Failure, bool>> checkNikExists(String nik) async {
    if (await networkInfo.isConnected) {
      try {
        return const Right(false);
      } on exc.ServerException catch (e) {
        return Left(ServerFailure(message: e.message));
      } catch (e) {
        return Left(
            ServerFailure(message: 'Error checking NIK: ${e.toString()}'));
      }
    } else {
      return Left(ServerFailure(message: AppConstants.errorNetworkMessage));
    }
  }

  @override
  Future<Either<Failure, Penduduk>> loginPenduduk(
      String nik, String password) async {
    if (await networkInfo.isConnected) {
      try {
        final penduduk = await authApiService.login(nik, password);

        // Ambil data tambahan (alamat dan tag_lokasi) dari raw response
        // Kita perlu memanggil API lagi untuk mendapatkan raw response
        // Atau modifikasi AuthApiService untuk mengembalikan raw response juga
        // Untuk sementara, kita akan mengambil dari response login yang sudah ada
        // dengan memanggil API login sekali lagi untuk mendapatkan raw response
        String? alamat;
        String? tagLokasi;

        try {
          final rawResponse =
              await authApiService.getRawLoginResponse(nik, password);
          if (rawResponse != null && rawResponse['status'] == true) {
            final userData = rawResponse['data']?['user'];
            if (userData != null) {
              alamat = userData['alamat']?.toString();
              tagLokasi = userData['tag_lokasi']?.toString();
            }
          }
        } catch (e) {
          // Jika gagal mengambil raw response, lanjutkan tanpa alamat dan tag_lokasi
          print('⚠️  [Auth] Failed to get raw login response: $e');
        }

        await authLocalStorage.saveUserCredentials(
          nik: penduduk.nik,
          password: password,
          noHp: penduduk.noHp,
          name: penduduk.name,
          accessToken: penduduk.accessToken,
          tokenType: penduduk.tokenType,
          role: 'penduduk',
          userType: 'penduduk',
          alamat: alamat,
          tagLokasi: tagLokasi,
        );

        GetIt.instance<AssetApiService>().clearCache();

        // Cache KK secara async setelah login (tidak blocking)
        // Ini akan mempercepat loading menu keluarga di kunjungan berikutnya
        _cacheKKAfterLoginAsync(penduduk.nik);

        return Right(penduduk);
      } on exc.AuthException catch (e) {
        return Left(AuthFailure(message: e.message));
      } on exc.ServerException catch (e) {
        return Left(ServerFailure(message: e.message));
      } catch (e) {
        return Left(ServerFailure(message: e.toString()));
      }
    } else {
      return Left(ServerFailure(message: AppConstants.errorNetworkMessage));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> loginAdmin(
      String nikOrUsername, String password) async {
    if (await networkInfo.isConnected) {
      try {
        final data = await authApiService.adminLogin(nikOrUsername, password);
        // Simpan token admin ke storage
        final user = data['user'] as Map<String, dynamic>?;
        await authLocalStorage.saveUserCredentials(
          nik: (user?['nik'] ?? '').toString(),
          password: password,
          name: (user?['username'] ?? user?['nama'] ?? '').toString(),
          accessToken: (data['access_token'] ?? '').toString(),
          tokenType: (data['token_type'] ?? 'Bearer').toString(),
          role: (data['role'] ?? user?['role'] ?? '').toString(),
          userType: 'admin',
        );
        // Bersihkan cache aset ketika berpindah user
        GetIt.instance<AssetApiService>().clearCache();
        return Right(data);
      } on exc.AuthException catch (e) {
        return Left(AuthFailure(message: e.message));
      } on exc.ServerException catch (e) {
        return Left(ServerFailure(message: e.message));
      } catch (e) {
        return Left(ServerFailure(message: e.toString()));
      }
    } else {
      return Left(ServerFailure(message: AppConstants.errorNetworkMessage));
    }
  }

  @override
  Future<Either<Failure, bool>> registerPenduduk(
    String nik,
    String password,
    String noHp,
  ) async {
    if (await networkInfo.isConnected) {
      try {
        final penduduk = await authApiService.register(nik, password, noHp);

        await authLocalStorage.saveUserCredentials(
          nik: nik,
          password: password,
          noHp: noHp,
          accessToken: penduduk.accessToken,
          tokenType: penduduk.tokenType,
        );

        return const Right(true);
      } on exc.ValidationException catch (e) {
        return Left(ServerFailure(message: e.message));
      } on exc.AuthException catch (e) {
        return Left(AuthFailure(message: e.message));
      } on exc.ServerException catch (e) {
        return Left(ServerFailure(message: e.message));
      } catch (e) {
        return Left(
            ServerFailure(message: 'Registration error: ${e.toString()}'));
      }
    } else {
      return Left(ServerFailure(message: AppConstants.errorNetworkMessage));
    }
  }

  @override
  Future<Either<Failure, void>> logout() async {
    try {
      // Clear semua cache data saat logout
      await authLocalStorage.clearAllCache();
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Penduduk>> autoLogin() async {
    try {
      final hasCredentials = await authLocalStorage.hasUserCredentials();
      if (!hasCredentials) {
        return Left(AuthFailure(message: 'No stored credentials'));
      }

      final penduduk = await authLocalStorage.getStoredPenduduk();
      if (penduduk == null) {
        return Left(AuthFailure(message: 'Failed to get stored user data'));
      }

      if (penduduk.accessToken != null && penduduk.accessToken!.isNotEmpty) {
        return Right(penduduk);
      }

      final credentials = await authLocalStorage.getUserCredentials();
      if (credentials == null) {
        await authLocalStorage.clearUserCredentials();
        return Left(AuthFailure(message: 'Stored credentials are invalid'));
      }

      if (await networkInfo.isConnected) {
        try {
          return await loginPenduduk(
              credentials['nik'], credentials['password']);
        } catch (e) {
          return Left(
              AuthFailure(message: 'Failed to login with stored credentials'));
        }
      }

      return Left(ServerFailure(message: AppConstants.errorNetworkMessage));
    } catch (e) {
      return Left(CacheFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getPendudukDetail(
      String nik) async {
    if (await networkInfo.isConnected) {
      try {
        final detail = await pendudukApiService.getPendudukDetailByNik(nik);

        // Cache KK untuk mempercepat loading menu keluarga
        final kk = detail['kk']?.toString() ?? '';
        if (kk.isNotEmpty) {
          await authLocalStorage.cacheKKByNik(nik, kk);
        }

        return Right(detail);
      } on exc.ServerException catch (e) {
        return Left(ServerFailure(message: e.message));
      } catch (e) {
        return Left(ServerFailure(message: e.toString()));
      }
    } else {
      return Left(ServerFailure(message: 'No internet connection'));
    }
  }

  /// Method cepat untuk mendapatkan KK saja (menggunakan cache jika tersedia)
  Future<Either<Failure, String>> getKKByNik(String nik) async {
    // Cek cache dulu
    final cachedKK = await authLocalStorage.getCachedKKByNik(nik);
    if (cachedKK != null && cachedKK.isNotEmpty) {
      return Right(cachedKK);
    }

    // Jika tidak ada di cache, coba ambil dari API
    if (await networkInfo.isConnected) {
      try {
        final kk = await pendudukApiService.getKKByNik(nik);
        if (kk != null && kk.isNotEmpty) {
          // Cache hasilnya
          await authLocalStorage.cacheKKByNik(nik, kk);
          return Right(kk);
        }
        return Left(
            ServerFailure(message: 'KK tidak ditemukan untuk NIK $nik'));
      } catch (e) {
        return Left(ServerFailure(message: e.toString()));
      }
    } else {
      return Left(ServerFailure(message: 'No internet connection'));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getUserProfile() async {
    if (await networkInfo.isConnected) {
      try {
        final token = await authLocalStorage.getStoredToken();
        if (token == null || token.isEmpty) {
          return Left(AuthFailure(message: 'No authentication token found'));
        }

        final cleanToken = token.contains('|') ? token.split('|').last : token;
        final profile = await authApiService.getUserProfile(cleanToken);
        return Right(profile);
      } on exc.ServerException catch (e) {
        return Left(ServerFailure(message: e.message));
      } catch (e) {
        return Left(ServerFailure(message: e.toString()));
      }
    } else {
      return Left(ServerFailure(message: 'No internet connection'));
    }
  }

  @override
  Future<Either<Failure, bool>> isHeadOfFamily(String nik) async {
    if (await networkInfo.isConnected) {
      try {
        final isHead = await pendudukApiService.isHeadOfFamily(nik);
        return Right(isHead);
      } on exc.ServerException catch (e) {
        return Left(ServerFailure(message: e.message));
      } catch (e) {
        return Left(ServerFailure(
            message: 'Error checking head of family: ${e.toString()}'));
      }
    } else {
      return Left(ServerFailure(message: 'No internet connection'));
    }
  }

  /// Cache KK setelah login secara async (non-blocking)
  void _cacheKKAfterLoginAsync(String nik) {
    // Jalankan di background tanpa blocking proses login
    Future.microtask(() async {
      try {
        // Tunggu sedikit untuk memastikan koneksi sudah stabil
        await Future.delayed(const Duration(milliseconds: 500));

        // Cek apakah sudah ada di cache
        final cachedKK = await authLocalStorage.getCachedKKByNik(nik);
        if (cachedKK != null && cachedKK.isNotEmpty) {
          return; // Sudah ada di cache, tidak perlu fetch lagi
        }

        // Ambil KK dengan method cepat
        if (await networkInfo.isConnected) {
          final kk = await pendudukApiService.getKKByNik(nik);
          if (kk != null && kk.isNotEmpty) {
            await authLocalStorage.cacheKKByNik(nik, kk);
          }
        }
      } catch (e) {
        // Ignore error, tidak critical untuk proses login
        print('Failed to cache KK after login: $e');
      }
    });
  }
}
