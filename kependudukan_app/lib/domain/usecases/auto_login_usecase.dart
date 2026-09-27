import 'package:dartz/dartz.dart';
import 'package:ladimas/core/errors/failures.dart';
import 'package:ladimas/domain/entities/penduduk.dart';
import 'package:ladimas/domain/repositories/auth_repository.dart';

class AutoLoginUseCase {
  final AuthRepository repository;

  AutoLoginUseCase(this.repository);

  Future<Either<Failure, Penduduk>> call() async {
    return await repository.autoLogin();
  }
}
