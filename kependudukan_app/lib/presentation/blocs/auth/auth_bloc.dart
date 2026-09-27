import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ladimas/core/errors/failures.dart';
import 'package:ladimas/domain/usecases/auto_login_usecase.dart';
import 'package:ladimas/domain/usecases/check_nik_exists_usecase.dart';
import 'package:ladimas/domain/usecases/login_penduduk_usecase.dart';
import 'package:ladimas/domain/usecases/logout_usecase.dart';
import 'package:ladimas/domain/usecases/register_penduduk_usecase.dart';
import 'package:ladimas/presentation/blocs/auth/auth_event.dart';
import 'package:ladimas/presentation/blocs/auth/auth_state.dart';
import 'package:get_it/get_it.dart';
import 'package:ladimas/data/datasources/auth_local_storage.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final LoginPendudukUseCase loginPendudukUseCase;
  final RegisterPendudukUseCase registerPendudukUseCase;
  final CheckNikExistsUseCase checkNikExistsUseCase;
  final LogoutUseCase logoutUseCase;
  final AutoLoginUseCase autoLoginUseCase;

  AuthBloc({
    required this.loginPendudukUseCase,
    required this.registerPendudukUseCase,
    required this.checkNikExistsUseCase,
    required this.logoutUseCase,
    required this.autoLoginUseCase,
  }) : super(AuthInitial()) {
    on<LoginPendudukEvent>(_onLoginPenduduk);
    on<LoginAdminEvent>(_onLoginAdmin);
    on<RegisterPendudukEvent>(_onRegister);
    on<CheckNikEvent>(_onCheckNik);
    on<LogoutEvent>(_onLogout);
    on<AutoLoginEvent>(_onAutoLogin);
  }

  Future<void> _onLoginPenduduk(
    LoginPendudukEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    await logoutUseCase(NoParams());

    final result = await loginPendudukUseCase(
      LoginPendudukParams(nik: event.nik, password: event.password),
    );

    result.fold(
      (failure) => emit(_mapFailureToAuthError(failure)),
      (penduduk) => emit(PendudukAuthenticated(penduduk: penduduk)),
    );
  }

  Future<void> _onLoginAdmin(
    LoginAdminEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    await logoutUseCase(NoParams());

    final result = await LoginAdminUseCase(GetIt.instance())(
      LoginAdminParams(
        nikOrUsername: event.nikOrUsername,
        password: event.password,
      ),
    );

    result.fold(
      (failure) => emit(_mapFailureToAuthError(failure)),
      (data) => emit(AdminAuthenticated(adminData: data)),
    );
  }

  Future<void> _onRegister(
    RegisterPendudukEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    // Validate password length
    if (event.password.length < 6) {
      emit(const AuthError(message: 'Password minimal 6 karakter'));
      return;
    }

    // Validate passwords match
    if (event.password != event.confirmPassword) {
      emit(const AuthError(
          message: 'Konfirmasi password tidak cocok dengan password'));
      return;
    }

    // Validate NIK length
    if (event.nik.length != 16) {
      emit(const AuthError(message: 'NIK harus 16 digit angka'));
      return;
    }

    // Validate NIK format (only numbers)
    if (!RegExp(r'^[0-9]+$').hasMatch(event.nik)) {
      emit(const AuthError(message: 'NIK hanya boleh berisi angka'));
      return;
    }

    // Validate phone number
    if (event.noHp.length < 10) {
      emit(const AuthError(message: 'Nomor HP minimal 10 digit'));
      return;
    }
    if (!RegExp(r'^[0-9]+$').hasMatch(event.noHp)) {
      emit(const AuthError(message: 'Nomor HP hanya boleh berisi angka'));
      return;
    }

    final result = await registerPendudukUseCase(
      RegisterPendudukParams(
        nik: event.nik,
        password: event.password,
        noHp: event.noHp,
      ),
    );

    emit(
      result.fold(
        (failure) => _mapFailureToAuthError(failure),
        (_) => RegisterSuccess(),
      ),
    );
  }

  Future<void> _onCheckNik(CheckNikEvent event, Emitter<AuthState> emit) async {
    emit(NikCheckLoading());

    try {
      final result = await checkNikExistsUseCase(
        CheckNikParams(nik: event.nik),
      );

      emit(
        result.fold(
          (failure) => _mapFailureToAuthError(failure),
          (exists) => NikExists(exists: exists),
        ),
      );
    } catch (e) {
      emit(AuthError(message: 'Error checking NIK: ${e.toString()}'));
    }
  }

  Future<void> _onLogout(LogoutEvent event, Emitter<AuthState> emit) async {
    emit(AuthLoading());

    final result = await logoutUseCase(NoParams());

    emit(
      result.fold(
        (failure) => _mapFailureToAuthError(failure),
        (_) => Unauthenticated(),
      ),
    );
  }

  Future<void> _onAutoLogin(
    AutoLoginEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    final result = await autoLoginUseCase();

    await result.fold(
      (_) async => emit(Unauthenticated()),
      (penduduk) async {
        // Tentukan jenis user dari storage
        final storage = GetIt.instance<AuthLocalStorage>();
        final userType = await storage.getStoredUserType();
        if (userType == 'admin') {
          final creds = await storage.getUserCredentials();
          final adminData = {
            'user': {
              'nik': creds?['nik'] ?? '',
              'username': creds?['name'] ?? '',
              'role': creds?['role'] ?? 'admin',
            },
            'role': creds?['role'] ?? 'admin',
            'access_token': creds?['access_token'] ?? '',
            'token_type': creds?['token_type'] ?? 'Bearer',
          };
          emit(AdminAuthenticated(adminData: adminData));
        } else {
          emit(PendudukAuthenticated(penduduk: penduduk));
        }
      },
    );
  }

  // Helper method to map failures to appropriate AuthError states
  AuthError _mapFailureToAuthError(Failure failure) {
    // Map specific failure types to user-friendly messages
    if (failure is AuthFailure) {
      // Handle authentication-specific failures
      if (failure.message.toLowerCase().contains('nik sudah terdaftar') ||
          failure.message.toLowerCase().contains('nik exists') ||
          failure.message.toLowerCase().contains('duplicate')) {
        return const AuthError(
            message:
                'NIK sudah terdaftar dalam sistem. Silakan login atau gunakan NIK lain.');
      }
      if (failure.message.toLowerCase().contains('nik tidak ditemukan') ||
          failure.message.toLowerCase().contains('not found')) {
        return const AuthError(
            message:
                'NIK tidak ditemukan dalam sistem. Periksa kembali NIK Anda.');
      }
      if (failure.message.toLowerCase().contains('password salah') ||
          failure.message.toLowerCase().contains('invalid password')) {
        return const AuthError(
            message:
                'Password yang Anda masukkan salah. Periksa kembali password Anda.');
      }
      if (failure.message.toLowerCase().contains('akun diblokir') ||
          failure.message.toLowerCase().contains('blocked')) {
        return const AuthError(
            message:
                'Akun Anda telah diblokir. Hubungi administrator untuk bantuan.');
      }
      if (failure.message.toLowerCase().contains('sesi expired') ||
          failure.message.toLowerCase().contains('session expired')) {
        return const AuthError(
            message: 'Sesi Anda telah berakhir. Silakan login kembali.');
      }
    }

    if (failure is ServerFailure) {
      if (failure.message.toLowerCase().contains('timeout')) {
        return const AuthError(
            message:
                'Koneksi timeout. Periksa koneksi internet Anda dan coba lagi.');
      }
      if (failure.message.toLowerCase().contains('server error') ||
          failure.message.toLowerCase().contains('500')) {
        return const AuthError(
            message:
                'Terjadi kesalahan pada server. Silakan coba beberapa saat lagi.');
      }
      if (failure.message.toLowerCase().contains('not found') ||
          failure.message.toLowerCase().contains('404')) {
        return const AuthError(
            message: 'Layanan tidak tersedia. Hubungi administrator.');
      }
    }

    if (failure is NetworkFailure) {
      return const AuthError(
          message:
              'Tidak ada koneksi internet. Periksa koneksi Anda dan coba lagi.');
    }

    // Default case: use the original failure message
    return AuthError(message: failure.message);
  }
}

class NoParams {}
