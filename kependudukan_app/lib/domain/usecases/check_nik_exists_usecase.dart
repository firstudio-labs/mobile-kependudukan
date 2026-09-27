import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:ladimas/core/errors/failures.dart';
import 'package:ladimas/domain/repositories/auth_repository.dart';

class CheckNikExistsUseCase {
  final AuthRepository repository;

  CheckNikExistsUseCase(this.repository);

  Future<Either<Failure, bool>> call(CheckNikParams params) async {
    return await repository.checkNikExists(params.nik);
  }
}

class CheckNikParams extends Equatable {
  final String nik;

  const CheckNikParams({required this.nik});

  @override
  List<Object?> get props => [nik];
}
