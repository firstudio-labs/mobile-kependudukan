import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:ladimas/core/errors/failures.dart';
import 'package:ladimas/domain/repositories/auth_repository.dart';

class RegisterPendudukUseCase {
  final AuthRepository repository;

  RegisterPendudukUseCase(this.repository);

  Future<Either<Failure, bool>> call(RegisterPendudukParams params) async {
    // First check if the NIK is the head of the family
    final headOfFamilyResult = await repository.isHeadOfFamily(params.nik);

    return headOfFamilyResult.fold(
      (failure) => Left(failure),
      (isHead) {
        if (!isHead) {
          return Left(AuthFailure(
              message:
                  'Hanya Kepala Keluarga yang dapat melakukan pendaftaran'));
        }
        // If the user is head of family, proceed with registration
        return repository.registerPenduduk(
          params.nik,
          params.password,
          params.noHp,
        );
      },
    );
  }
}

class RegisterPendudukParams extends Equatable {
  final String nik;
  final String password;
  final String noHp;

  const RegisterPendudukParams({
    required this.nik,
    required this.password,
    required this.noHp,
  });

  @override
  List<Object?> get props => [nik, password, noHp];
}
