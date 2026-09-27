import 'package:ladimas/core/network/network_info.dart';
import 'package:ladimas/core/utils/db_helper.dart';
import 'package:ladimas/data/datasources/auth_local_storage.dart';
import 'package:ladimas/data/datasources/penduduk_api_service.dart';
import 'package:ladimas/data/datasources/asset_api_service.dart';
import 'package:ladimas/data/repositories/asset_repository_impl.dart';
import 'package:ladimas/data/repositories/family_repository_impl.dart';
import 'package:ladimas/domain/repositories/asset_repository.dart';
import 'package:ladimas/domain/repositories/auth_repository.dart';
import 'package:ladimas/data/repositories/auth_repository_impl.dart';
import 'package:ladimas/domain/repositories/family_repository.dart';
import 'package:ladimas/domain/usecases/auto_login_usecase.dart';
import 'package:ladimas/domain/usecases/check_nik_exists_usecase.dart';
import 'package:ladimas/domain/usecases/login_penduduk_usecase.dart';
import 'package:ladimas/domain/usecases/logout_usecase.dart';
import 'package:ladimas/domain/usecases/register_penduduk_usecase.dart';
import 'package:ladimas/presentation/blocs/auth/auth_bloc.dart';
import 'package:ladimas/presentation/cubits/asset/asset_cubit.dart';
import 'package:ladimas/presentation/cubits/document/document_cubit.dart';
import 'package:ladimas/presentation/cubits/domisili/domisili_cubit.dart';
import 'package:ladimas/presentation/cubits/family/family_cubit.dart';
import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:ladimas/data/datasources/auth_api_service.dart';
import 'package:ladimas/data/datasources/laporan_api_service.dart';

final sl = GetIt.instance;

Future<void> init() async {
  // Bloc/Cubit
  sl.registerFactory(
    () => AuthBloc(
      loginPendudukUseCase: sl(),
      registerPendudukUseCase: sl(),
      checkNikExistsUseCase: sl(),
      logoutUseCase: sl(),
      autoLoginUseCase: sl(),
    ),
  );

  // Register Cubits
  sl.registerFactory(() => FamilyCubit(repository: sl()));
  sl.registerFactory(() => DomisiliCubit(repository: sl(), authRepository: sl()));
  sl.registerFactory(() => AssetCubit(repository: sl()));

  // Use cases
  sl.registerLazySingleton(() => LoginPendudukUseCase(sl()));
  sl.registerLazySingleton(() => LoginAdminUseCase(sl()));
  sl.registerLazySingleton(() => RegisterPendudukUseCase(sl()));
  sl.registerLazySingleton(() => CheckNikExistsUseCase(sl()));
  sl.registerLazySingleton(() => LogoutUseCase(sl()));
  sl.registerLazySingleton(() => AutoLoginUseCase(sl()));

  // Repository
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      pendudukApiService: sl(),
      authApiService: sl(),
      networkInfo: sl(),
      authLocalStorage: sl(),
    ),
  );

  sl.registerLazySingleton<FamilyRepository>(
    () => FamilyRepositoryImpl(
      apiService: sl(),
      networkInfo: sl(),
    ),
  );

  sl.registerLazySingleton<AssetRepository>(
    () => AssetRepositoryImpl(
      apiService: sl<AssetApiService>(),
      networkInfo: sl(),
    ),
  );

  // Data sources
  sl.registerLazySingleton(() => PendudukApiService(client: sl()));
  sl.registerLazySingleton(() => AuthApiService(client: sl()));
  sl.registerLazySingleton<AssetApiService>(
    () => AssetApiService(
      client: sl(),
      authLocalStorage: sl(),
    ),
  );
  sl.registerLazySingleton(() => AuthLocalStorage(secureStorage: sl()));

  // Core
  sl.registerLazySingleton<NetworkInfo>(() => NetworkInfoImpl(sl()));
  sl.registerLazySingleton(() => DbHelper());

  // External
  sl.registerLazySingleton(() => http.Client());
  sl.registerLazySingleton(() => InternetConnectionChecker());
  sl.registerLazySingleton(() => const FlutterSecureStorage());

  //document
  sl.registerFactory(() => DocumentCubit(repository: sl()));

  // API Services
  sl.registerLazySingleton<VillageReportApiService>(
    () => VillageReportApiService(
      client: sl(),
      authLocalStorage: sl(),
    ),
  );
}
