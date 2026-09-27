import 'package:equatable/equatable.dart';
import 'package:ladimas/data/models/asset_model.dart';

abstract class AssetState extends Equatable {
  const AssetState();

  @override
  List<Object?> get props => [];
}

class AssetInitial extends AssetState {}

class AssetLoading extends AssetState {
  final List<AssetModel> assets;

  const AssetLoading([this.assets = const []]);
}

class AssetLoaded extends AssetState {
  final List<AssetModel> assets;

  const AssetLoaded(this.assets);

  @override
  List<Object?> get props => [assets];
}

class AssetDetailLoaded extends AssetState {
  final AssetModel asset;

  const AssetDetailLoaded(this.asset);

  @override
  List<Object?> get props => [asset];
}

class AssetError extends AssetState {
  final String message;

  const AssetError(this.message);

  @override
  List<Object?> get props => [message];
}

class AssetSubmitting extends AssetState {}

class AssetSubmitted extends AssetState {}
