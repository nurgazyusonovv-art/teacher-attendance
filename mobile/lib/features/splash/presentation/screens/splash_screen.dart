import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;
  Timer? _timer;
  bool _minTimeElapsed = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _scaleAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
    );

    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeIn,
    );

    _animController.forward();

    // Check auth status
    context.read<AuthCubit>().checkAuthStatus();

    // 3 seconds timer
    _timer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _minTimeElapsed = true);
        _checkAndNavigate();
      }
    });
  }

  void _checkAndNavigate() {
    if (!mounted || !_minTimeElapsed) return;
    final state = context.read<AuthCubit>().state;
    if (state is AuthLoading) return; // Wait until auth check finishes

    if (state is Authenticated) {
      if (state.user.role == 'ADMIN') {
        context.go('/admin');
      } else {
        context.go('/home');
      }
    } else {
      context.go('/login');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) {
        if (_minTimeElapsed) {
          _checkAndNavigate();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A), // Premium Dark Slate
        body: Stack(
          children: [
            // Background Gradient Glow
            Positioned(
              top: -100,
              left: -50,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.primaryColor.withValues(alpha: 0.25),
                ),
              ),
            ),
            Positioned(
              bottom: -100,
              right: -50,
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.secondaryColor.withValues(alpha: 0.2),
                ),
              ),
            ),

            // Main Center Content
            SafeArea(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(flex: 2),

                    // Animated Logo
                    ScaleTransition(
                      scale: _scaleAnim,
                      child: FadeTransition(
                        opacity: _fadeAnim,
                        child: Container(
                          width: 110,
                          height: 110,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryColor.withValues(alpha: 0.4),
                                blurRadius: 30,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: Image.asset(
                              'assets/images/app_logo.png',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // App Title
                    FadeTransition(
                      opacity: _fadeAnim,
                      child: Column(
                        children: [
                          const Text(
                            'Мугалим Каттоо',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Мектептеги катышууну көзөмөлдөө системасы',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: Colors.white.withValues(alpha: 0.65),
                              fontWeight: FontWeight.w400,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),

                    const Spacer(flex: 2),

                    // Modern Progress Indicator
                    FadeTransition(
                      opacity: _fadeAnim,
                      child: Column(
                        children: [
                          SizedBox(
                            width: 140,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: const LinearProgressIndicator(
                                minHeight: 4,
                                backgroundColor: Color(0xFF1E293B),
                                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryLight),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Сессия текшерилүүдө...',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Colors.white.withValues(alpha: 0.45),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),

                    // Footer School Tag
                    FadeTransition(
                      opacity: _fadeAnim,
                      child: Text(
                        '№1 Орто Мектеп • Asia/Bishkek (UTC+6)',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.35),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
