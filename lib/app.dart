import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:psga_app/config/themes.dart';
import 'package:psga_app/core/locale/locale_cubit.dart';
import 'package:psga_app/core/theme/theme_cubit.dart';
import 'package:psga_app/core/utils/logger.dart';
import 'package:psga_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:psga_app/features/auth/presentation/bloc/auth_event.dart';
import 'package:psga_app/features/auth/presentation/bloc/auth_state.dart';
import 'package:psga_app/features/auth/presentation/pages/forgot_password_page.dart';
import 'package:psga_app/features/auth/presentation/pages/login_page.dart';
import 'package:psga_app/features/auth/presentation/pages/register_page.dart';
import 'package:psga_app/features/auth/presentation/pages/verify_email_page.dart';
import 'package:psga_app/features/splash/presentation/pages/splash_page.dart';
import 'package:psga_app/features/home/presentation/pages/home_page.dart';
import 'package:psga_app/features/home/presentation/pages/profile_page.dart';
import 'package:psga_app/features/home/presentation/pages/settings_page.dart';
import 'package:psga_app/features/home/presentation/pages/change_password_page.dart';
import 'package:psga_app/features/routes/presentation/pages/create_route_page.dart';
import 'package:psga_app/features/routes/presentation/pages/route_detail_page.dart';
import 'package:psga_app/features/routes/domain/entities/route.dart';
import 'package:psga_app/features/trips/presentation/pages/active_trip_page.dart';
import 'package:psga_app/features/trips/presentation/pages/trip_detail_page.dart';
import 'package:psga_app/features/trips/presentation/pages/trip_settings_page.dart';
import 'package:psga_app/features/alerts/presentation/pages/emergency_page.dart';
import 'package:psga_app/features/alerts/presentation/pages/alert_settings_page.dart';
import 'package:psga_app/features/alerts/presentation/pages/contacts_page.dart';
import 'package:psga_app/features/routes/presentation/bloc/routes_bloc.dart';
import 'package:psga_app/features/trips/presentation/bloc/trip_bloc.dart';
import 'package:psga_app/features/trips/presentation/bloc/trip_event.dart';
import 'package:psga_app/features/trips/presentation/bloc/trip_state.dart';
import 'package:psga_app/features/alerts/presentation/bloc/alert/alert_bloc.dart';
import 'package:psga_app/features/alerts/presentation/bloc/contact/contact_bloc.dart';
import 'package:psga_app/features/maps/presentation/bloc/location/location_bloc.dart';
import 'package:psga_app/injection_container.dart' as di;

/// التطبيق الرئيسي
/// ✅ RouteObserver global لـ didPopNext في الصفحات
final RouteObserver<ModalRoute<void>> appRouteObserver = RouteObserver<ModalRoute<void>>();

class PSGAApp extends StatefulWidget {
  const PSGAApp({super.key});

  @override
  State<PSGAApp> createState() => _PSGAAppState();
}

class _PSGAAppState extends State<PSGAApp> with WidgetsBindingObserver {

  @override
  void initState() {
    super.initState();
    // ✅ تطوير 3: مراقبة دورة حياة التطبيق لإنهاء الرحلة عند الإغلاق
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// ✅ يُستدعى عند تغيّر حالة التطبيق (نشط، خلفية، إغلاق)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.detached) {
      AppLogger.warning('[PSGAApp] التطبيق يُغلق - إنهاء أي رحلة نشطة');
      _endActiveTripIfExists();
    }
  }

  /// إنهاء الرحلة النشطة عند إغلاق التطبيق
  void _endActiveTripIfExists() {
    try {
      final tripBloc = di.sl<TripBloc>();
      final authBloc = di.sl<AuthBloc>();
      
      final authState = authBloc.state;
      if (authState is! Authenticated) return;
      
      final tripState = tripBloc.state;
      String? activeTripId;
      
      if (tripState is TripActive) {
        activeTripId = tripState.trip.id;
      } else if (tripState is TripPaused) {
        activeTripId = tripState.trip.id;
      }
      
      if (activeTripId != null) {
        AppLogger.warning('[PSGAApp] إنهاء الرحلة النشطة: $activeTripId');
        tripBloc.add(EndTripEvent(tripId: activeTripId));
      }
    } catch (e) {
      AppLogger.error('[PSGAApp] فشل إنهاء الرحلة عند الإغلاق', e);
    }
  }

  @override
  Widget build(BuildContext context) {
    AppLogger.info('[PSGAApp] بناء التطبيق');

    return MultiBlocProvider(
      providers: [
        // ThemeCubit - متاح في كل التطبيق
        BlocProvider<ThemeCubit>(
          create: (_) => ThemeCubit(),
        ),

        // LocaleCubit - لإدارة اللغة
        BlocProvider<LocaleCubit>(
          create: (_) => LocaleCubit(),
        ),

        // AuthBloc - متاح في كل التطبيق
        BlocProvider<AuthBloc>(
          create: (_) => di.sl<AuthBloc>()..add(const AuthCheckRequested()),
        ),

        // RoutesBloc
        BlocProvider<RoutesBloc>(
          create: (_) => di.sl<RoutesBloc>(),
        ),

        // TripBloc
        BlocProvider<TripBloc>(
          create: (_) => di.sl<TripBloc>(),
        ),

        // AlertBloc
        BlocProvider<AlertBloc>(
          create: (_) => di.sl<AlertBloc>(),
        ),

        // ContactBloc
        BlocProvider<ContactBloc>(
          create: (_) => di.sl<ContactBloc>(),
        ),

        // LocationBloc
        BlocProvider<LocationBloc>(
          create: (_) => di.sl<LocationBloc>(),
        ),
      ],
      child: BlocBuilder<ThemeCubit, ThemeState>(
        builder: (context, themeState) {
          return BlocBuilder<LocaleCubit, Locale>(
            builder: (context, locale) {
              return MaterialApp(
            // معلومات التطبيق
            title: 'PSGA - Personal Security Guard',
            debugShowCheckedModeBanner: false,

            // الترجمة
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('en'), // الإنجليزية
              Locale('ar'), // العربية
            ],
            locale: locale, // اللغة من LocaleCubit

            // الثيم - يتغير تلقائياً عند تغيير themeState
            theme: AppThemes.lightTheme,
            darkTheme: AppThemes.darkTheme,
            themeMode: context.read<ThemeCubit>().themeMode,

            // الصفحة الرئيسية
            home: const SplashPage(),
            
            // ✅ RouteObserver لدعم didPopNext في الصفحات
            navigatorObservers: [appRouteObserver],

        // Routes البسيطة (بدون معاملات)
        routes: {
          '/splash': (context) => const SplashPage(),
          '/login': (context) => const LoginPage(),
          '/register': (context) => const RegisterPage(),
          '/forgot-password': (context) => const ForgotPasswordPage(),
          '/verify-email': (context) => const VerifyEmailPage(),
          '/home': (context) => const HomePage(),
          '/profile': (context) => const ProfilePage(),
          '/settings': (context) => const SettingsPage(),
          '/change-password': (context) => const ChangePasswordPage(),
        },

        // معالجة Routes المعقدة (مع معاملات)
        onGenerateRoute: (settings) {
          AppLogger.info('[PSGAApp] التنقل إلى: ${settings.name}');

          // استخراج userId من AuthBloc للصفحات التي تحتاجه
          String? getUserId(BuildContext context) {
            final authState = context.read<AuthBloc>().state;
            if (authState is Authenticated) {
              return authState.user.id;
            }
            return null;
          }

          // Route: Trip Detail
          if (settings.name == '/trip-detail') {
            final tripId = settings.arguments as String?;
            if (tripId != null) {
              return MaterialPageRoute(
                builder: (context) => TripDetailPage(tripId: tripId),
                settings: settings,
              );
            }
          }

          // Route: Route Detail
          if (settings.name == '/route-detail') {
            final routeId = settings.arguments as String?;
            if (routeId != null) {
              return MaterialPageRoute(
                builder: (context) => RouteDetailPage(routeId: routeId),
                settings: settings,
              );
            }
          }

          // Route: Create/Edit Route
          if (settings.name == '/create-route') {
            // يمكن أن تكون arguments إما RouteEntity للتعديل أو Map للإنشاء الجديد
            final args = settings.arguments;
            
            RouteEntity? route;
            if (args is RouteEntity) {
              // حالة التعديل - تمرير RouteEntity مباشرة
              route = args;
            } else if (args is Map) {
              // حالة الإنشاء الجديد - لا نفعل شيء، فقط نمرر null
              // الـ Map سيتم معالجته داخل CreateRoutePage
              route = null;
            }
            
            return MaterialPageRoute(
              builder: (context) => CreateRoutePage(route: route),
              settings: settings,
            );
          }

          // Route: Active Trip
          if (settings.name == '/active-trip') {
            // دعم معاملات متعددة
            final args = settings.arguments;
            RouteEntity? route;
            
            if (args is Map<String, dynamic>) {
              route = args['route'] as RouteEntity?;
            } else if (args is RouteEntity) {
              route = args;
            }
            
            return MaterialPageRoute(
              builder: (context) => ActiveTripPage(routeToStart: route),
              settings: settings,
            );
          }

          // Route: Emergency (يحتاج userId)
          if (settings.name == '/emergency') {
            return MaterialPageRoute(
              builder: (context) {
                final userId = getUserId(context);
                if (userId == null) {
                  // إعادة توجيه للـ login إذا لم يكن مسجل دخول
                  AppLogger.warning('[PSGAApp] محاولة الوصول لـ /emergency بدون تسجيل دخول');
                  Future.microtask(() => Navigator.pushReplacementNamed(context, '/login'));
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                return EmergencyPage(userId: userId);
              },
              settings: settings,
            );
          }

          // Route: Alert Settings (يحتاج userId)
          if (settings.name == '/alert-settings') {
            return MaterialPageRoute(
              builder: (context) {
                final userId = getUserId(context);
                if (userId == null) {
                  AppLogger.warning('[PSGAApp] محاولة الوصول لـ /alert-settings بدون تسجيل دخول');
                  Future.microtask(() => Navigator.pushReplacementNamed(context, '/login'));
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                return AlertSettingsPage(userId: userId);
              },
              settings: settings,
            );
          }

          // Route: Trip Settings
          if (settings.name == '/trip-settings') {
            return MaterialPageRoute(
              builder: (context) => const TripSettingsPage(),
              settings: settings,
            );
          }

          // Route: Contacts (يحتاج userId - يمكن تمريره كـ argument أو جلبه من AuthBloc)
          if (settings.name == '/contacts') {
            return MaterialPageRoute(
              builder: (context) {
                // محاولة الحصول على userId من arguments أولاً
                String? userId = settings.arguments as String?;
                
                // إذا لم يُمرر، نحصل عليه من AuthBloc
                userId ??= getUserId(context);
                
                if (userId == null) {
                  AppLogger.warning('[PSGAApp] محاولة الوصول لـ /contacts بدون تسجيل دخول');
                  Future.microtask(() => Navigator.pushReplacementNamed(context, '/login'));
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                
                AppLogger.info('[PSGAApp] الانتقال لصفحة جهات الاتصال - userId: $userId');
                return ContactsPage(userId: userId);
              },
              settings: settings,
            );
          }

          // Route غير موجود
          AppLogger.warning('[PSGAApp] Route غير موجود: ${settings.name}');
          return null;
        },

        // معالجة Routes غير الموجودة
        onUnknownRoute: (settings) {
          AppLogger.error('[PSGAApp] Route غير معروف: ${settings.name}');
          return MaterialPageRoute(
            builder: (context) => Scaffold(
              appBar: AppBar(title: const Text('خطأ')),
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    const Text(
                      'الصفحة غير موجودة',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'المسار: ${settings.name}',
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => Navigator.pushReplacementNamed(context, '/home'),
                      child: const Text('العودة للرئيسية'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
            },
          );
        },
      ),
    );
  }
}
