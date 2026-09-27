import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:ladimas/core/errors/exception.dart';
import 'package:ladimas/core/errors/failures.dart';
import 'package:ladimas/core/network/network_info.dart';
import 'package:ladimas/data/datasources/penduduk_api_service.dart';
import 'package:ladimas/data/models/document_model.dart';
import 'package:ladimas/data/models/family_member_model.dart';
import 'package:ladimas/domain/repositories/family_repository.dart';

class FamilyRepositoryImpl implements FamilyRepository {
  final PendudukApiService apiService;
  final NetworkInfo networkInfo;

  final Map<String, List<FamilyMemberModel>> _familyCache = {};
  final Map<String, DateTime> _familyCacheTimestamp = {};
  final Duration _cacheDuration = const Duration(minutes: 15);

  FamilyRepositoryImpl({
    required this.apiService,
    required this.networkInfo,
  });

  @override
  Future<Either<Failure, List<FamilyMemberModel>>> getFamilyMembers(
    String kk, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh &&
        _familyCache.containsKey(kk) &&
        _familyCacheTimestamp.containsKey(kk)) {
      final timestamp = _familyCacheTimestamp[kk]!;
      final now = DateTime.now();
      if (now.difference(timestamp) < _cacheDuration) {
        return Right(_familyCache[kk]!);
      }
    }

    if (await networkInfo.isConnected) {
      try {
        final members = await apiService.getFamilyMembers(kk);

        // Update cache
        _familyCache[kk] = members;
        _familyCacheTimestamp[kk] = DateTime.now();

        return Right(members);
      } on ServerException catch (e) {
        return Left(ServerFailure(message: e.message));
      } catch (e) {
        return Left(ServerFailure(message: e.toString()));
      }
    } else {
      if (_familyCache.containsKey(kk)) {
        return Right(_familyCache[kk]!);
      }
      return Left(ServerFailure(message: 'No internet connection'));
    }
  }

  Future<Either<Failure, FamilyMemberModel>> getFamilyMember(
      String kk, String nik,
      {bool forceRefresh = false}) async {
    try {
      final membersResult =
          await getFamilyMembers(kk, forceRefresh: forceRefresh);

      return membersResult.fold((failure) => Left(failure), (members) {
        try {
          final member = members.firstWhere((m) => m.nik == nik);
          return Right(member);
        } catch (_) {
          return Left(ServerFailure(message: 'Family member not found'));
        }
      });
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> updateFamilyMemberCoordinate(
      String nik, String coordinate) async {
    if (await networkInfo.isConnected) {
      try {
        final success =
            await apiService.updateFamilyMemberCoordinate(nik, coordinate);

        if (success) {
          _updateMemberCoordinateInCache(nik, coordinate);
        }

        return Right(success);
      } on ServerException catch (e) {
        return Left(ServerFailure(message: e.message));
      } catch (e) {
        return Left(ServerFailure(message: e.toString()));
      }
    } else {
      return Left(ServerFailure(message: 'No internet connection'));
    }
  }

  @override
  Future<Either<Failure, FamilyMemberDocuments>> getFamilyMemberDocuments(
      String nik,
      {bool forceRefresh = false}) async {
    if (await networkInfo.isConnected) {
      try {
        final documents = await apiService.getFamilyMemberDocuments(nik,
            forceRefresh: forceRefresh);
        return Right(documents);
      } on ServerException catch (e) {
        return Left(ServerFailure(message: e.message));
      } on AuthException catch (e) {
        return Left(AuthFailure(message: e.message));
      } catch (e) {
        return Left(ServerFailure(message: e.toString()));
      }
    } else {
      return Left(ServerFailure(message: 'No internet connection'));
    }
  }

  @override
  Future<Either<Failure, DocumentModel>> uploadFamilyMemberDocument(
    String nik,
    String documentType,
    File file,
  ) async {
    if (await networkInfo.isConnected) {
      try {
        final document = await apiService.uploadFamilyMemberDocument(
            nik, documentType, file);
        return Right(document);
      } on ServerException catch (e) {
        return Left(ServerFailure(message: e.message));
      } on AuthException catch (e) {
        return Left(AuthFailure(message: e.message));
      } catch (e) {
        return Left(ServerFailure(message: e.toString()));
      }
    } else {
      return Left(ServerFailure(message: 'No internet connection'));
    }
  }

  @override
  Future<Either<Failure, bool>> deleteFamilyMemberDocument(
    String nik,
    String documentType,
  ) async {
    if (await networkInfo.isConnected) {
      try {
        final success =
            await apiService.deleteFamilyMemberDocument(nik, documentType);
        return Right(success);
      } on ServerException catch (e) {
        return Left(ServerFailure(message: e.message));
      } catch (e) {
        return Left(ServerFailure(message: e.toString()));
      }
    } else {
      return Left(ServerFailure(message: 'No internet connection'));
    }
  }

  void _updateMemberCoordinateInCache(String nik, String coordinate) {
    for (var entry in _familyCache.entries) {
      final members = entry.value;
      for (int i = 0; i < members.length; i++) {
        if (members[i].nik == nik) {
          _familyCache[entry.key]![i] =
              members[i].copyWith(coordinate: coordinate);
        }
      }
    }
  }

  @override
  void clearCache() {
    _familyCache.clear();
    _familyCacheTimestamp.clear();
  }
}
