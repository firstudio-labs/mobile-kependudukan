import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ladimas/core/di/injection_container.dart' as di;
import 'package:ladimas/core/theme/app_theme.dart';
import 'package:ladimas/core/utils/db_helper.dart';
import 'package:ladimas/presentation/blocs/auth/auth_bloc.dart';
import 'package:ladimas/presentation/cubits/asset/asset_cubit.dart';
import 'package:ladimas/presentation/cubits/document/document_cubit.dart';
import 'package:ladimas/presentation/cubits/domisili/domisili_cubit.dart';
import 'package:ladimas/presentation/cubits/family/family_cubit.dart';
import 'package:ladimas/presentation/pages/splash/splash_page.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  // Initialize the dependency injection
  await di.init();

  // Initialize the database
  final dbHelper = DbHelper();
  await dbHelper.database;

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => di.sl<AuthBloc>()),
        BlocProvider(create: (_) => di.sl<FamilyCubit>()),
        BlocProvider(create: (_) => di.sl<DomisiliCubit>()),
        BlocProvider(create: (_) => di.sl<AssetCubit>()),
        BlocProvider(create: (_) => di.sl<DocumentCubit>()),
      ],
      child: MaterialApp(
        title: 'LADIMAS',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const SplashScreen(),
      ),
    );
  }
}
