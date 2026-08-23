import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../core/constants/app_constants.dart';
import '../core/theme/admin_theme.dart';
import '../features/auth/data/repositories/admin_auth_repository.dart';
import '../features/auth/presentation/cubit/admin_auth_cubit.dart';
import 'router.dart';

class TeacherAdminApp extends StatefulWidget {
  const TeacherAdminApp({super.key});

  @override
  State<TeacherAdminApp> createState() => _TeacherAdminAppState();
}

class _TeacherAdminAppState extends State<TeacherAdminApp> {
  late final AdminAuthRepository _authRepository;
  late final AdminAuthCubit _authCubit;

  @override
  void initState() {
    super.initState();
    _authRepository = AdminAuthRepository();
    _authCubit = AdminAuthCubit(authRepository: _authRepository)..checkAuthStatus();
  }

  @override
  void dispose() {
    _authCubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AdminAuthCubit>.value(
      value: _authCubit,
      child: MaterialApp.router(
        title: AppConstants.appName,
        theme: AdminTheme.theme,
        debugShowCheckedModeBanner: false,
        routerConfig: adminRouter,
      ),
    );
  }
}
