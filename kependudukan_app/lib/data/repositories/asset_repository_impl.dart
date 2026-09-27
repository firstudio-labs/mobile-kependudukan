import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:ladimas/core/errors/exception.dart';
import 'package:ladimas/core/errors/failures.dart';
import 'package:ladimas/core/network/network_info.dart';
import 'package:ladimas/data/datasources/asset_api_service.dart';
import 'package:ladimas/data/models/asset_model.dart';
import 'package:ladimas/domain/repositories/asset_repository.dart';

class AssetRepositoryImpl implements AssetRepository {
  final AssetApiService apiService;
  final NetworkInfo networkInfo;

  AssetRepositoryImpl({
    required this.apiService,
    required this.networkInfo,
  });

  @override
  Future<Either<Failure, List<AssetModel>>> getAssets() async {
    if (await networkInfo.isConnected) {
      try {
        final assets = await apiService.getAssets();
        return Right(assets.cast<AssetModel>());
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
  Future<Either<Failure, AssetModel>> getAssetDetail(int id) async {
    if (await networkInfo.isConnected) {
      try {
        final asset = await apiService.getAssetDetail(id);
        return Right(asset);
      } on ServerException catch (e) {
        return Left(ServerFailure(message: e.message));
      } on AuthException catch (e) {
        return Left(AuthFailure(message: e.message));
      } catch (e) {
        return Left(ServerFailure(message: e.toString()));
      }
    } else {
      return Left(ServerFailure(message: 'Tidak ada koneksi internet'));
    }
  }

  @override
  Future<Either<Failure, bool>> createAsset(
      Map<String, dynamic> assetData) async {
    if (await networkInfo.isConnected) {
      try {
        final result = await apiService.createAsset(assetData);
        return Right(result);
      } on ServerException catch (e) {
        return Left(ServerFailure(message: e.message));
      } on AuthException catch (e) {
        return Left(AuthFailure(message: e.message));
      } catch (e) {
        return Left(ServerFailure(message: e.toString()));
      }
    } else {
      return Left(ServerFailure(message: 'Tidak ada koneksi internet'));
    }
  }

  @override
  Future<Either<Failure, bool>> createAssetWithImages(
      Map<String, dynamic> assetData, File? fotoDpn, File? fotoSamping) async {
    if (await networkInfo.isConnected) {
      try {
        final result = await apiService.createAssetWithImages(
            assetData, fotoDpn, fotoSamping);
        return Right(result);
      } on ServerException catch (e) {
        return Left(ServerFailure(message: e.message));
      } on AuthException catch (e) {
        return Left(AuthFailure(message: e.message));
      } catch (e) {
        return Left(ServerFailure(message: e.toString()));
      }
    } else {
      return Left(ServerFailure(message: 'Tidak ada koneksi internet'));
    }
  }

  @override
  Future<Either<Failure, bool>> updateAsset(
      int id, Map<String, dynamic> assetData) async {
    if (await networkInfo.isConnected) {
      try {
        final result = await apiService.updateAsset(id, assetData);
        return Right(result);
      } on ServerException catch (e) {
        return Left(ServerFailure(message: e.message));
      } on AuthException catch (e) {
        return Left(AuthFailure(message: e.message));
      } catch (e) {
        return Left(ServerFailure(message: e.toString()));
      }
    } else {
      return Left(ServerFailure(message: 'Tidak ada koneksi internet'));
    }
  }

  @override
  Future<Either<Failure, bool>> updateAssetWithImages(int id,
      Map<String, dynamic> assetData, File? fotoDpn, File? fotoSamping) async {
    if (await networkInfo.isConnected) {
      try {
        final result = await apiService.updateAssetWithImages(
            id, assetData, fotoDpn, fotoSamping);
        return Right(result);
      } on ServerException catch (e) {
        return Left(ServerFailure(message: e.message));
      } on AuthException catch (e) {
        return Left(AuthFailure(message: e.message));
      } catch (e) {
        return Left(ServerFailure(message: e.toString()));
      }
    } else {
      return Left(ServerFailure(message: 'Tidak ada koneksi internet'));
    }
  }

  @override
  Future<Either<Failure, bool>> deleteAsset(int id) async {
    if (await networkInfo.isConnected) {
      try {
        final result = await apiService.deleteAsset(id);
        return Right(result);
      } on ServerException catch (e) {
        return Left(ServerFailure(message: e.message));
      } on AuthException catch (e) {
        return Left(AuthFailure(message: e.message));
      } catch (e) {
        return Left(ServerFailure(message: e.toString()));
      }
    } else {
      return Left(ServerFailure(message: 'Tidak ada koneksi internet'));
    }
  }
}
