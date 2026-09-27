import 'package:dartz/dartz.dart';
import 'package:ladimas/core/errors/failures.dart';
import 'package:ladimas/domain/repositories/auth_repository.dart';
import 'package:ladimas/presentation/blocs/auth/auth_bloc.dart';

class LogoutUseCase {
  final AuthRepository repository;

  LogoutUseCase(this.repository);

  Future<Either<Failure, void>> call(NoParams params) async {
    return await repository.logout();
  }
}
