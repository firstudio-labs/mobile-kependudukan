import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:ladimas/core/errors/failures.dart';
import 'package:ladimas/domain/entities/penduduk.dart';
import 'package:ladimas/domain/repositories/auth_repository.dart';

class LoginPendudukUseCase {
  final AuthRepository repository;

  LoginPendudukUseCase(this.repository);

  Future<Either<Failure, Penduduk>> call(LoginPendudukParams params) async {
    return await repository.loginPenduduk(params.nik, params.password);
  }
}

class LoginAdminUseCase {
  final AuthRepository repository;

  LoginAdminUseCase(this.repository);

  Future<Either<Failure, Map<String, dynamic>>> call(
      LoginAdminParams params) async {
    return await repository.loginAdmin(params.nikOrUsername, params.password);
  }
}

class LoginAdminParams {
  final String nikOrUsername;
  final String password;

  LoginAdminParams({required this.nikOrUsername, required this.password});
}

class LoginPendudukParams extends Equatable {
  final String nik;
  final String password;

  const LoginPendudukParams({required this.nik, required this.password});

  @override
  List<Object?> get props => [nik, password];
}
