import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ladimas/domain/repositories/asset_repository.dart';
import 'package:ladimas/presentation/cubits/asset/asset_state.dart';

class AssetCubit extends Cubit<AssetState> {
  final AssetRepository repository;

  AssetCubit({required this.repository}) : super(AssetInitial());

  Future<void> loadAssets() async {
    emit(const AssetLoading());

    final result = await repository.getAssets();

    result.fold(
      (failure) => emit(AssetError(failure.message)),
      (assets) => emit(AssetLoaded(assets)),
    );
  }

  Future<void> loadAssetDetail(int assetId) async {
    emit(const AssetLoading());

    final result = await repository.getAssetDetail(assetId);

    result.fold(
      (failure) => emit(AssetError(failure.message)),
      (asset) => emit(AssetDetailLoaded(asset)),
    );
  }

  Future<void> createAsset(Map<String, dynamic> assetData) async {
    emit(AssetSubmitting());

    final result = await repository.createAsset(assetData);

    result.fold(
      (failure) => emit(AssetError(failure.message)),
      (success) {
        emit(AssetSubmitted());
        // Muat ulang daftar asset setelah berhasil menambahkan
        loadAssets();
      },
    );
  }

  Future<void> createAssetWithImages(
      Map<String, dynamic> assetData, File? fotoDpn, File? fotoSamping) async {
    emit(AssetSubmitting());

    final result =
        await repository.createAssetWithImages(assetData, fotoDpn, fotoSamping);

    result.fold(
      (failure) => emit(AssetError(failure.message)),
      (success) {
        emit(AssetSubmitted());
        // Muat ulang daftar asset setelah berhasil menambahkan
        loadAssets();
      },
    );
  }

  Future<void> updateAsset(int id, Map<String, dynamic> assetData) async {
    emit(AssetSubmitting());

    final result = await repository.updateAsset(id, assetData);

    result.fold(
      (failure) => emit(AssetError(failure.message)),
      (success) {
        emit(AssetSubmitted());
        loadAssets();
      },
    );
  }

  Future<void> updateAssetWithImages(int id, Map<String, dynamic> assetData,
      File? fotoDpn, File? fotoSamping) async {
    emit(AssetSubmitting());

    final result = await repository.updateAssetWithImages(
        id, assetData, fotoDpn, fotoSamping);

    result.fold(
      (failure) => emit(AssetError(failure.message)),
      (success) {
        emit(AssetSubmitted());
        loadAssets();
      },
    );
  }

  Future<void> deleteAsset(int id) async {
    emit(AssetSubmitting());

    final result = await repository.deleteAsset(id);

    result.fold(
      (failure) => emit(AssetError(failure.message)),
      (success) {
        emit(AssetSubmitted());
        loadAssets();
      },
    );
  }
}
