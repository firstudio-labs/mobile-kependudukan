import 'dart:io';
import 'package:dartz/dartz.dart';
import 'package:ladimas/core/errors/failures.dart';
import 'package:ladimas/data/models/asset_model.dart';

abstract class AssetRepository {
  Future<Either<Failure, List<AssetModel>>> getAssets();

  // Tambahkan metode-metode baru berikut:
  Future<Either<Failure, bool>> createAsset(Map<String, dynamic> assetData);
  Future<Either<Failure, bool>> createAssetWithImages(
      Map<String, dynamic> assetData, File? fotoDpn, File? fotoSamping);
  Future<Either<Failure, AssetModel>> getAssetDetail(int assetId);
  Future<Either<Failure, bool>> updateAsset(
      int id, Map<String, dynamic> assetData);
  Future<Either<Failure, bool>> updateAssetWithImages(
      int id, Map<String, dynamic> assetData, File? fotoDpn, File? fotoSamping);
  Future<Either<Failure, bool>> deleteAsset(int id);
}
