import 'package:ladimas/core/errors/failures.dart';
import 'package:ladimas/core/utils/db_helper.dart';
import 'package:ladimas/data/models/penduduk_model.dart';
import 'package:dartz/dartz.dart';

abstract class AuthLocalDataSource {
  Future<Either<Failure, PendudukModel>> getPendudukByLogin(
    String nik,
    String password,
  );
}

class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  final DbHelper dbHelper;

  AuthLocalDataSourceImpl({required this.dbHelper});

  @override
  Future<Either<Failure, PendudukModel>> getPendudukByLogin(
    String nik,
    String password,
  ) async {
    try {
      final db = await dbHelper.database;
      var result = await db.query(
        'penduduk',
        where: 'nik = ? AND password = ?',
        whereArgs: [nik, password],
        limit: 1,
      );

      if (result.isNotEmpty) {
        return Right(PendudukModel.fromJson(result.first));
      } else {
        return Left(AuthenticationFailure(message: 'Kredensial tidak valid'));
      }
    } catch (e) {
      return Left(DatabaseFailure(message: e.toString()));
    }
  }
}
