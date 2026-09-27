import 'package:dartz/dartz.dart';
import 'package:ladimas/core/errors/failures.dart';
import 'package:ladimas/domain/entities/penduduk.dart';

abstract class AuthRepository {
  Future<Either<Failure, Penduduk>> loginPenduduk(String nik, String password);

  Future<Either<Failure, Map<String, dynamic>>> loginAdmin(
      String nikOrUsername, String password);

  Future<Either<Failure, bool>> registerPenduduk(
    String nik,
    String password,
    String noHp,
  );

  Future<Either<Failure, bool>> checkNikExists(String nik);

  Future<Either<Failure, void>> logout();

  Future<Either<Failure, Penduduk>> autoLogin();

  Future<Either<Failure, Map<String, dynamic>>> getPendudukDetail(String nik);

  Future<Either<Failure, Map<String, dynamic>>> getUserProfile();

  Future<Either<Failure, bool>> isHeadOfFamily(String nik);
}
