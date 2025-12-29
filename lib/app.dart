import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'config/routes.dart';
import 'config/themes.dart';
import 'core/di/injection_container.dart';
import 'core/utils/logger.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/trips/presentation/bloc/route_bloc.dart';
import 'features/trips/presentation/bloc/trip_bloc.dart';
import 'features/alerts/presentation/bloc/alert_bloc.dart';
import 'features/alerts/presentation/bloc/contact_bloc.dart';
import 'features/maps/presentation/bloc/map_bloc.dart';
import 'features/maps/presentation/bloc/location_bloc.dart';

import 'features/auth/presentation/bloc/auth_state.dart';
import 'features/trips/presentation/bloc/route_event.dart';
import 'features/trips/presentation/bloc/trip_event.dart';
import 'features/alerts/presentation/bloc/contact_event.dart';
import 'core/services/sync/sync_manager.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// 📌 PSGAApp - التطبيق الرئيسي
/// ═══════════════════════════════════════════════════════════════════════════
/// 
/// الهدف من هذا الملف:
/// هذا هو الـ Root Widget للتطبيق الكامل
/// مسؤوليته:
/// 1. إنشاء نسخة من جميع BLoCs من GetIt container
/// 2. توفير BLoCs لجميع Widgets عبر MultiBlocProvider
/// 3. إعداد المسارات (Routing) و الملاحة
/// 4. تحميل البيانات الأولية من Hive عند البدء
/// 5. إدارة اللغة والمظهر (Light/Dark theme)
/// 6. بناء المادة الأساسية (MaterialApp) للتطبيق
///
class PSGAApp extends StatefulWidget {
  const PSGAApp({super.key});

  @override
  State<PSGAApp> createState() => _PSGAAppState();
}

class _PSGAAppState extends State<PSGAApp> {
  /// 🌍 إعدادات اللغة: افتراضياً اللغة العربية
  Locale _locale = const Locale('ar');
  
  /// 🎨 إعدادات المظهر: افتراضياً اللايت موود
  ThemeMode _themeMode = ThemeMode.light;
  
  /// 🔗 BLoCs - نسخة واحدة من كل BLoC تُستخدم طوال التطبيق
  /// late final = ننشئها في initState، ثم لا نتغييرها أبداً
  late final AuthBloc _authBloc;
  late final RouteBloc _routeBloc;
  late final TripBloc _tripBloc;
  late final AlertBloc _alertBloc;
  late final ContactBloc _contactBloc;
  late final MapBloc _mapBloc;
  late final LocationBloc _locationBloc;
  
  /// 🗺️ المسار (Router): يحدد أي صفحة نعرض بناءً على الـ URL
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    AppLogger.info('[PSGAApp] Initializing app widget', name: 'PSGAApp');
    
    /// 📥 خطوة 1: استدعاء جميع BLoCs من GetIt container
    /// sl<ClassName>() = دالة البحث في Service Locator
    /// نستخدم نفس instances في كل مكان (Singleton pattern)
    _authBloc = sl<AuthBloc>();
    _routeBloc = sl<RouteBloc>();
    _tripBloc = sl<TripBloc>();
    _alertBloc = sl<AlertBloc>();
    _contactBloc = sl<ContactBloc>();
    _mapBloc = sl<MapBloc>();
    _locationBloc = sl<LocationBloc>();
    
    AppLogger.info('[PSGAApp] All BLoCs initialized', name: 'PSGAApp');
    
    /// 🗺️ خطوة 2: إنشاء GoRouter وتمرير AuthBloc
    /// الـ Router يتحقق من AuthBloc للتحكم في الملاحة:
    /// - إذا لم يسجل الدخول → عرض Login Page
    /// - إذا سجل دخول → عرض Home Page
    _router = createAppRouter(_authBloc);
    
    /// 📥 خطوة 3: تحميل البيانات الأولية من Hive
    _loadSettings();
  }

  /// 📥 تحميل البيانات الأولية عند بدء التطبيق
  Future<void> _loadSettings() async {
    AppLogger.info('[PSGAApp] Loading app settings', name: 'PSGAApp');
    
    AppLogger.info('[PSGAApp] 📥 تحميل البيانات الأولية من Hive', name: 'PSGAApp');
    
    /// ⏱️ تأخير 100 ميلي ثانية:
    /// لماذا؟ لأن الـ Widget لم يكتمل بناؤه بعد (context issues)
    /// ننتظر حتى يكتمل البناء، ثم نحمل البيانات بأمان
    Future.delayed(const Duration(milliseconds: 100), () async {
      /// 🔍 خطوة 1: الحصول على ID المستخدم
      /// نتحقق: هل المستخدم سجل دخول؟
      /// - إذا نعم: استخدم من AuthBloc
      /// - إذا لا: ابحث في Hive عن ID محفوظ سابقاً
      final userId = _authBloc.state is AuthSuccess 
          ? (_authBloc.state as AuthSuccess).user.id 
          : await sl<SyncManager>().getCurrentUserId();

      if (userId != null) {
        AppLogger.info('[PSGAApp] 🔄 تحميل البيانات للمستخدم: $userId', name: 'PSGAApp');
        
        /// 📥 خطوة 2: تحميل المسارات
        /// نأمر RouteBloc بـ: "جهز المسارات المحفوظة للمستخدم"
        /// .add() = إرسال حدث (Event) للـ BLoC
        AppLogger.info('[PSGAApp] 🔄 تحميل المسارات من التخزين المحلي...', name: 'PSGAApp');
        _routeBloc.add(LoadRoutes(userId));
        
        /// 📥 خطوة 3: تحميل الرحلات
        /// LoadTripHistory = جهز سجل جميع الرحلات
        /// LoadActiveTrip = جهز الرحلة النشطة حالياً
        AppLogger.info('[PSGAApp] 🔄 تحميل الرحلات من التخزين المحلي...', name: 'PSGAApp');
        _tripBloc.add(LoadTripHistory(userId: userId));
        _tripBloc.add(LoadActiveTrip(userId));
        
        /// 📥 خطوة 4: تحميل جهات الاتصال (Emergency Contacts)
        AppLogger.info('[PSGAApp] 🔄 تحميل جهات الاتصال من التخزين المحلي...', name: 'PSGAApp');
        _contactBloc.add(LoadContactsEvent(userId));
        
        AppLogger.success('[PSGAApp] ✅ اكتملت عملية التحميل الأولي', name: 'PSGAApp');
      } else {
        /// لا يوجد مستخدم مسجل دخول، تخطي التحميل
        AppLogger.warning('[PSGAApp] ⚠️ لم يتم العثور على مستخدم مسجل - تخطي التحميل الأولي', name: 'PSGAApp');
      }
    });
    
    AppLogger.success('[PSGAApp] Settings loaded successfully', name: 'PSGAApp');
  }

  /// 🌍 تغيير اللغة ديناميكياً
  /// setState() = أخبر Flutter بإعادة بناء الـ Widget
  void setLocale(Locale locale) {
    AppLogger.info('[PSGAApp] Changing locale to: ${locale.languageCode}', name: 'PSGAApp');
    setState(() {
      _locale = locale;
    });
  }

  /// 🎨 تغيير المظهر (Light/Dark) ديناميكياً
  void setThemeMode(ThemeMode themeMode) {
    AppLogger.info('[PSGAApp] Changing theme mode to: $themeMode', name: 'PSGAApp');
    setState(() {
      _themeMode = themeMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    AppLogger.info('[PSGAApp] Building app widget', name: 'PSGAApp');
    
    /// 🔗 MultiBlocProvider: توفير جميع BLoCs لكل الـ Widgets
    /// .value() = استخدام نسخة موجودة (بدل إنشاء نسخة جديدة)
    /// كل Widget يمكنه الوصول لـ BLoC بـ: context.read<BLocName>()
    return MultiBlocProvider(
      providers: [
        /// 🔐 AuthBloc: يدير تسجيل الدخول والمصادقة
        BlocProvider<AuthBloc>.value(
          value: _authBloc,
        ),
        /// 🛣️ RouteBloc: يدير المسارات المحفوظة
        BlocProvider<RouteBloc>.value(
          value: _routeBloc,
        ),
        /// 🚗 TripBloc: يدير الرحلات النشطة والسابقة
        BlocProvider<TripBloc>.value(
          value: _tripBloc,
        ),
        /// 🚨 AlertBloc: يدير التنبيهات و SOS
        BlocProvider<AlertBloc>.value(
          value: _alertBloc,
        ),
        /// 📱 ContactBloc: يدير جهات الاتصال الطوارئ
        BlocProvider<ContactBloc>.value(
          value: _contactBloc,
        ),
        /// 🗺️ MapBloc: يدير حالة الخريطة
        BlocProvider<MapBloc>.value(
          value: _mapBloc,
        ),
        /// 📍 LocationBloc: يدير تحديث الموقع الجغرافي
        BlocProvider<LocationBloc>.value(
          value: _locationBloc,
        ),
      ],
      /// 🚀 التطبيق الرئيسي
      /// MaterialApp.router = استخدام GoRouter للملاحة (بدل Navigation)
      child: MaterialApp.router(
        title: 'Personal Security Guard',
        debugShowCheckedModeBanner: false,  /// إخفاء شريط "Debug" الحمراء
        
        /// 🎨 المظاهر (Themes)
        theme: AppThemes.lightTheme,         /// موضوع اللايت
        darkTheme: AppThemes.darkTheme,       /// موضوع الدارك
        themeMode: _themeMode,                /// اختيار المظهر الحالي
        
        /// 🌍 الترجمة والمحليات
        locale: _locale,                      /// اللغة الحالية
        supportedLocales: const [
          Locale('ar'),  /// العربية
          Locale('en'),  /// الإنجليزية
        ],
        localizationsDelegates: const [
          /// توفير ترجمات Flutter الافتراضية
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        
        /// 🗺️ الملاحة (Routing)
        /// routerConfig = تمرير GoRouter configuration
        routerConfig: _router,
        
        /// 📖 Directionality: تحديد اتجاه النصوص
        /// RTL (من اليمين لليسار) للعربية
        /// LTR (من اليسار لليمين) للإنجليزية
        builder: (context, child) {
          return Directionality(
            textDirection: _locale.languageCode == 'ar' 
                ? TextDirection.rtl 
                : TextDirection.ltr,
            child: child ?? const SizedBox.shrink(),
          );
        },
      ),
    );
  }
}
