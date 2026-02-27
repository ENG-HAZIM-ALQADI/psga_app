import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:psga_app/core/constants/app_dimensions.dart';
import 'package:psga_app/core/utils/logger.dart';
import 'package:psga_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:psga_app/features/auth/presentation/bloc/auth_state.dart';
import 'package:psga_app/features/alerts/domain/entities/alert_config_entity.dart';
import 'package:psga_app/features/alerts/domain/usecases/get_alert_config_usecase.dart';
import 'package:psga_app/features/alerts/domain/usecases/save_alert_config_usecase.dart';
import 'package:psga_app/injection_container.dart' as di;

/// شاشة البداية (Splash Screen)
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    AppLogger.info('[SplashPage] بدء شاشة البداية');

    // تهيئة الـ Animations
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeIn,
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutBack,
      ),
    );

    // بدء الأنيميشن
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        // الانتظار لمدة ثانيتين ثم التنقل
        Future.delayed(const Duration(seconds: 2), () {
          if (!mounted) return;

          if (state is Authenticated) {
            AppLogger.success('[SplashPage] المستخدم مسجل دخول: ${state.user.email}');
            
            // ✅ إنشاء AlertConfig افتراضي إذا لم يكن موجوداً
            _ensureAlertConfigExists(state.user.id);
            
            // التنقل إلى الصفحة الرئيسية
            Navigator.pushReplacementNamed(context, '/home');
          } else if (state is Unauthenticated) {
            AppLogger.info('[SplashPage] المستخدم غير مسجل دخول');
            Navigator.pushReplacementNamed(context, '/login');
          } else if (state is AuthError) {
            AppLogger.error('[SplashPage] خطأ في التحقق من المصادقة', state.message);
            // في حالة الخطأ، اذهب إلى Login
            Navigator.pushReplacementNamed(context, '/login');
          }
        });
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF2C2C2C), // لون داكن يتناسب مع اللوجو
        body: Center(
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // شعار التطبيق مع أنيميشن (بدون خلفية بيضاء)
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: 200,
                      height: 200,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),

                const SizedBox(height: AppDimensions.spacingXL),

                // اسم التطبيق مع أنيميشن
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: const Text(
                    'PSGA',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 2,
                    ),
                  ),
                ),

                const SizedBox(height: AppDimensions.spacingSM),

                // الوصف مع أنيميشن
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: const Text(
                    'Personal Security Guard',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                      letterSpacing: 1,
                    ),
                  ),
                ),

                const SizedBox(height: AppDimensions.spacingXXL),

                // مؤشر التحميل
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
  }

  /// التأكد من وجود AlertConfig للمستخدم، وإنشائه إذا لم يكن موجوداً
  Future<void> _ensureAlertConfigExists(String userId) async {
    try {
      final getConfigUseCase = di.sl<GetAlertConfigUseCase>();
      final saveConfigUseCase = di.sl<SaveAlertConfigUseCase>();
      
      AppLogger.info('[SplashPage] التحقق من AlertConfig للمستخدم: $userId');
      
      final configResult = await getConfigUseCase(userId);
      
      await configResult.fold(
        (failure) async {
          // الإعدادات غير موجودة - إنشاء افتراضي
          AppLogger.info('[SplashPage] AlertConfig غير موجود - إنشاء افتراضي');
          
          final defaultConfig = AlertConfigEntity.defaultConfig(userId);
          final params = SaveAlertConfigParams(config: defaultConfig);
          final saveResult = await saveConfigUseCase(params);
          
          saveResult.fold(
            (saveFailure) => AppLogger.error('[SplashPage] فشل حفظ AlertConfig', saveFailure.message),
            (savedConfig) => AppLogger.success('[SplashPage] تم إنشاء AlertConfig افتراضي بنجاح'),
          );
        },
        (config) {
          // الإعدادات موجودة - لا حاجة لفعل شيء
          AppLogger.info('[SplashPage] AlertConfig موجود بالفعل');
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('[SplashPage] خطأ في التحقق من AlertConfig', e, stackTrace);
      // لا نوقف التطبيق - نسمح بالاستمرار
    }
  }
}
