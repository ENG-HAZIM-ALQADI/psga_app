import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../config/app_config.dart';
import '../../../../config/routes.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/utils/logger.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../../../auth/presentation/bloc/auth_state.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    AppLogger.info('[SplashPage] Initializing splash screen', name: 'SplashPage');
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOutBack),
      ),
    );

    _animationController.forward();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    AppLogger.info('[SplashPage] Starting app initialization', name: 'SplashPage');
    
    try {
      await Future.delayed(const Duration(seconds: 2));
      
      AppLogger.info('[SplashPage] Checking authentication via AuthBloc', name: 'SplashPage');
      if (mounted) {
        context.read<AuthBloc>().add(const AuthCheckRequested());
      }
    } catch (e, stackTrace) {
      AppLogger.error(
        '[SplashPage] Error during initialization: $e',
        name: 'SplashPage',
        error: e,
        stackTrace: stackTrace,
      );
      if (mounted && !_hasNavigated) {
        _hasNavigated = true;
        context.go(AppRoutes.login);
      }
    }
  }

  void _handleAuthState(AuthState state) {
    if (_hasNavigated) return;
    
    if (state is AuthSuccess) {
      AppLogger.info('[SplashPage] User is authenticated, navigating to home', name: 'SplashPage');
      _hasNavigated = true;
      context.go(AppRoutes.home);
    } else if (state is AuthUnauthenticated) {
      AppLogger.info('[SplashPage] User not authenticated, navigating to login', name: 'SplashPage');
      _hasNavigated = true;
      context.go(AppRoutes.login);
    } else if (state is AuthFailure) {
      AppLogger.error('[SplashPage] Auth check failed: ${state.message}', name: 'SplashPage');
      _hasNavigated = true;
      context.go(AppRoutes.login);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) => _handleAuthState(state),
      child: Scaffold(
        body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.primary,
              AppColors.primaryDark,
            ],
          ),
        ),
        child: SafeArea(
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Opacity(
                opacity: _fadeAnimation.value,
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: child,
                ),
              );
            },
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 2),
                Container(
                  padding: const EdgeInsets.all(AppDimensions.paddingL),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.security,
                    size: 100,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: AppDimensions.marginL),
                const Text(
                  AppConfig.appNameAr,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppDimensions.marginS),
                Text(
                  AppConfig.appName,
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white.withOpacity(0.8),
                  ),
                  textAlign: TextAlign.center,
                ),
                const Spacer(flex: 2),
                const SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    strokeWidth: 3,
                  ),
                ),
                const SizedBox(height: AppDimensions.marginM),
                Text(
                  'جاري التحميل...',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
                const Spacer(),
                Text(
                  'الإصدار ${AppConfig.appVersion}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.5),
                  ),
                ),
                const SizedBox(height: AppDimensions.marginL),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}
