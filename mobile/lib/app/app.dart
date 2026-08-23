import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../core/constants/app_constants.dart';
import '../core/network/api_client.dart';
import '../core/storage/secure_storage_service.dart';
import '../core/theme/app_theme.dart';
import '../features/attendance/data/repositories/attendance_repository.dart';
import '../features/attendance/presentation/cubit/attendance_cubit.dart';
import '../features/auth/data/repositories/auth_repository.dart';
import '../features/auth/presentation/cubit/auth_cubit.dart';
import 'router.dart';

class TeacherApp extends StatefulWidget {
  const TeacherApp({super.key});

  @override
  State<TeacherApp> createState() => _TeacherAppState();
}

class _TeacherAppState extends State<TeacherApp> {
  late final SecureStorageService _storageService;
  late final ApiClient _apiClient;
  late final AuthRepository _authRepository;
  late final AuthCubit _authCubit;
  late final AttendanceRepository _attendanceRepository;
  late final AttendanceCubit _attendanceCubit;

  @override
  void initState() {
    super.initState();
    _storageService = SecureStorageService();
    _apiClient = ApiClient(storageService: _storageService);
    _authRepository = AuthRepository(
      apiClient: _apiClient,
      storageService: _storageService,
    );
    _authCubit = AuthCubit(authRepository: _authRepository)..checkAuthStatus();
    _attendanceRepository = AttendanceRepository();
    _attendanceCubit = AttendanceCubit(repository: _attendanceRepository);
  }

  @override
  void dispose() {
    _authCubit.close();
    _attendanceCubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthCubit>.value(value: _authCubit),
        BlocProvider<AttendanceCubit>.value(value: _attendanceCubit),
      ],
      child: MaterialApp.router(
        title: AppConstants.appName,
        theme: AppTheme.lightTheme,
        debugShowCheckedModeBanner: false,
        routerConfig: appRouter,
      ),
    );
  }
}
