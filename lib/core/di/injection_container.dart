import 'package:get_it/get_it.dart';
import '../../config/app_config.dart';
import '../../features/auth/data/datasources/auth_local_datasource.dart';
import '../../features/auth/data/datasources/auth_remote_datasource.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/usecases/get_current_user_usecase.dart';
import '../../features/auth/domain/usecases/login_usecase.dart';
import '../../features/auth/domain/usecases/logout_usecase.dart';
import '../../features/auth/domain/usecases/register_usecase.dart';
import '../../features/auth/domain/usecases/reset_password_usecase.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../services/storage/hive_service.dart';
import '../services/storage/local_storage_service.dart';
import '../services/sync/sync_service.dart';
import '../services/sync/sync_manager.dart';
import '../services/sync/conflict_resolver.dart';
import '../services/connectivity/connectivity_service.dart';
import '../../features/trips/data/datasources/route_local_datasource.dart';
import '../../features/trips/data/datasources/route_remote_datasource.dart';
import '../../features/trips/data/datasources/trip_local_datasource.dart';
import '../../features/trips/data/datasources/trip_remote_datasource.dart';
import '../../features/trips/data/repositories/route_repository_impl.dart';
import '../../features/trips/data/repositories/trip_repository_impl.dart';
import '../../features/trips/domain/repositories/route_repository.dart';
import '../../features/trips/domain/repositories/trip_repository.dart';
import '../../features/trips/domain/usecases/create_route_usecase.dart';
import '../../features/trips/domain/usecases/delete_route_usecase.dart';
import '../../features/trips/domain/usecases/get_user_routes_usecase.dart';
import '../../features/trips/domain/usecases/update_route_usecase.dart';
import '../../features/trips/domain/usecases/start_trip_usecase.dart';
import '../../features/trips/domain/usecases/end_trip_usecase.dart';
import '../../features/trips/domain/usecases/update_trip_location_usecase.dart';
import '../../features/trips/domain/usecases/get_trip_history_usecase.dart';
import '../../features/trips/presentation/bloc/route_bloc.dart';
import '../../features/trips/presentation/bloc/trip_bloc.dart';
import '../../features/alerts/data/datasources/alert_local_datasource.dart';
import '../../features/alerts/data/datasources/alert_remote_datasource.dart';
import '../../features/alerts/data/datasources/contact_local_datasource.dart' as contact_ds;
import '../../features/alerts/data/datasources/contact_remote_datasource.dart';
import '../../features/alerts/data/repositories/alert_repository_impl.dart';
import '../../features/alerts/data/repositories/contact_repository_impl.dart';
import '../../features/alerts/data/services/notification_service.dart';
import '../../features/alerts/data/services/fcm_service.dart';
import '../../features/alerts/data/services/sms_service.dart';
import '../../features/alerts/domain/repositories/alert_repository.dart';
import '../../features/alerts/domain/repositories/contact_repository.dart';
import '../../features/alerts/domain/usecases/trigger_alert_usecase.dart';
import '../../features/alerts/domain/usecases/acknowledge_alert_usecase.dart';
import '../../features/alerts/domain/usecases/cancel_alert_usecase.dart';
import '../../features/alerts/domain/usecases/escalate_alert_usecase.dart';
import '../../features/alerts/domain/usecases/send_sos_usecase.dart';
import '../../features/alerts/domain/usecases/get_alert_history_usecase.dart';
import '../../features/alerts/presentation/bloc/alert_bloc.dart';
import '../../features/alerts/presentation/bloc/contact_bloc.dart';
import '../utils/logger.dart';
import '../../features/maps/data/services/location_service.dart';
import '../../features/maps/data/services/geocoding_service.dart';
import '../../features/maps/data/services/deviation_detector.dart';
import '../../features/maps/presentation/bloc/map_bloc.dart';
import '../../features/maps/presentation/bloc/location_bloc.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// 📌 SERVICE LOCATOR (حاوية إدارة التبعيات)
/// ═══════════════════════════════════════════════════════════════════════════
///
/// الهدف من هذا الملف:
/// هذا الملف هو "مصنع البيانات" المركزي للتطبيق!
/// 
/// المسؤولية الرئيسية:
/// 1. تسجيل جميع الـ Objects (DataSources, Repositories, UseCases, BLoCs)
/// 2. توفير تلك الـ Objects لبقية التطبيق عند طلبها
/// 3. ضمان أن كل object ينشأ مرة واحدة فقط (Singleton)
/// 4. إدارة الاعتماديات والعلاقات بينها
///
/// لماذا نستخدم Service Locator؟
/// بدلاً من نقل الـ objects عبر Constructors (Dependency Hell)
/// نسجلها هنا، ثم نطلبها بـ: sl<ClassName>()
/// 
/// هذا يتبع مبدأ Clean Architecture:
/// ✅ فصل الاهتمامات: كل layer مستقل
/// ✅ سهولة الاختبار: يمكن استبدال الـ implementations بـ Mocks
/// ✅ المرونة: تبديل Firebase بـ Mock بسطر واحد!

/// 🔗 المتغير العام: sl = Service Locator instance
/// هذا الـ object الوحيد الذي نحتاجه للوصول لكل شيء آخر
final sl = GetIt.instance;

/// 🚨 تعليم التهيئة: هل تمت التهيئة مسبقاً؟
/// نستخدمه لمنع التهيئة المزدوجة (تجنب الأخطاء والهدر)
bool _isInitialized = false;

/// ═══════════════════════════════════════════════════════════════════════════
/// 📌 initializeDependencies - تهيئة جميع التبعيات
/// ═══════════════════════════════════════════════════════════════════════════
/// 
/// نقطة الدخول الرئيسية للتهيئة!
/// تُستدعى مرة واحدة فقط من main.dart عند بدء التطبيق
/// 
/// معاملات الدالة:
/// [useFirebase] = هل نستخدم Firebase للبيانات البعيدة؟
///   - true  = استخدم Firebase (Real Database)
///   - false = استخدم Mock Data (للاختبار)
///
/// مراحل التهيئة:
/// 1️⃣ تسجيل خدمات Core (Logger, Hive, Connectivity)
///    → هذه الخدمات يحتاجها كل شيء آخر
/// 2️⃣ تسجيل Feature Auth (المصادقة)
///    → أول ميزة: تسجيل الدخول والمصادقة
/// 3️⃣ تسجيل Feature Trips (الرحلات والمسارات)
/// 4️⃣ تسجيل Feature Alerts (التنبيهات و SOS)
/// 5️⃣ تسجيل Feature Maps (الخرائط والموقع)

Future<void> initializeDependencies({bool useFirebase = false}) async {
  /// ✅ الخطوة الأمان: منع التهيئة المزدوجة
  /// إذا تم التهيئة مسبقاً، لا تفعل شيء ولا تهدر الموارد
  if (_isInitialized) {
    AppLogger.warning('[DI] Dependencies already initialized, skipping...', name: 'DI');
    return;
  }
  
  /// 📢 رسالة البداية: التهيئة جارية
  AppLogger.info('[DI] Initializing dependencies (useFirebase: $useFirebase)', name: 'DI');

  /// 1️⃣ تسجيل خدمات Core
  /// هذه الخدمات لا غنى عنها ويحتاجها كل جزء من التطبيق
  _registerCoreServices();

  /// 2️⃣ تسجيل ميزة المصادقة (Auth)
  /// 🔐 تسجيل الدخول والتسجيل والمصادقة
  /// اختيار ديناميكي: Firebase أم Mock؟
  if (useFirebase) {
    AppLogger.info('[DI] Registering Firebase Auth DataSource', name: 'DI');
    /// 🔗 registerLazySingleton:
    /// معناها: "ننشئ instance واحد فقط، عند أول طلب له (lazy)"
    /// <AuthRemoteDataSource> = نوع الـ object (Interface)
    /// () => FirebaseAuthRemoteDataSource() = كيفية الإنشاء (Implementation)
    sl.registerLazySingleton<AuthRemoteDataSource>(
      () => FirebaseAuthRemoteDataSource(),
    );
  } else {
    AppLogger.info('[DI] Registering Mock Auth DataSource', name: 'DI');
    /// في الاختبار: استخدم بيانات وهمية لا تحتاج Firebase
    sl.registerLazySingleton<AuthRemoteDataSource>(
      () => MockAuthRemoteDataSource(),
    );
  }

  /// تسجيل Local DataSource (Hive)
  /// يُستخدم دائماً (سواء Firebase أو Mock)
  /// 💾 لتخزين البيانات محلياً على الجهاز
  sl.registerLazySingleton<AuthLocalDataSource>(
    () => AuthLocalDataSource(),
  );

  /// تسجيل Repository Implementation
  /// 🔗 ربط الطلقة: AuthRepositoryImpl
  /// AuthRepositoryImpl يحتاج على:
  /// - remoteDataSource: sl() = اطلب من GetIt (سيعطيك الـ instance المسجل أعلاه)
  /// - localDataSource: sl() = اطلب من GetIt
  /// 
  /// تدفق البيانات:
  /// LoginPage → AuthBloc → LoginUseCase → AuthRepository
  /// → يختار: Remote (Firebase) أم Local (Hive) → يعيد النتيجة
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      remoteDataSource: sl(),   /// ❄️ Firebase أو Mock
      localDataSource: sl(),     /// 💾 Hive (التخزين المحلي)
    ),
  );

  /// تسجيل Use Cases
  /// 🎯 كل Use Case = حالة استخدام محددة
  /// 
  /// LoginUseCase:
  /// مسؤوليته: "تحقق من بيانات الدخول وسجل المستخدم دخول"
  /// يحتاج: AuthRepository (لطلب البيانات)
  sl.registerLazySingleton(() => LoginUseCase(sl()));          /// 🔐 تسجيل دخول
  sl.registerLazySingleton(() => RegisterUseCase(sl()));        /// 📝 تسجيل حساب جديد
  sl.registerLazySingleton(() => LogoutUseCase(sl()));          /// 🚪 تسجيل خروج
  sl.registerLazySingleton(() => ResetPasswordUseCase(sl()));   /// 🔑 إعادة تعيين كلمة المرور
  sl.registerLazySingleton(() => GetCurrentUserUseCase(sl()));  /// 👤 الحصول على بيانات المستخدم

  /// تسجيل BLoC
  /// 📊 إدارة حالة المصادقة
  /// registerFactory = "ننشئ instance جديد كل مرة"
  /// لماذا؟ لأن BLoCs تتغير مع دورة حياة الـ Widgets
  /// عندما نعود للشاشة، نريد BLoC جديد (Fresh State)
  sl.registerFactory(
    () => AuthBloc(
      loginUseCase: sl(),              /// ✅ هنا نطلب LoginUseCase من GetIt
      registerUseCase: sl(),
      logoutUseCase: sl(),
      resetPasswordUseCase: sl(),
      getCurrentUserUseCase: sl(),
    ),
  );

  /// 3️⃣ تسجيل ميزة الرحلات والمسارات (Trips & Routes)
  /// 🛣️ إنشاء المسارات والتنقل بها
  _registerTripsFeature(useFirebase: useFirebase);
  
  /// 4️⃣ تسجيل ميزة التنبيهات (Alerts)
  /// 🚨 نظام التنبيهات و SOS
  _registerAlertsFeature(useFirebase: useFirebase);
  
  /// 5️⃣ تسجيل ميزة الخرائط (Maps)
  /// 🗺️ الموقع الجغرافي والخرائط
  _registerMapsFeature();

  /// ✅ التهيئة اكتملت بنجاح!
  _isInitialized = true;
  AppLogger.success('[DI] Dependencies initialized successfully (Firebase: $useFirebase)', name: 'DI');
}

/// ═══════════════════════════════════════════════════════════════════════════
/// 🛣️ _registerTripsFeature - تسجيل ميزة الرحلات والمسارات
/// ═══════════════════════════════════════════════════════════════════════════
///
/// الهدف: تسجيل جميع Objects المتعلقة بـ Trips Feature
/// تشمل:
/// - Local DataSources (Hive): التخزين المحلي للمسارات والرحلات
/// - Remote DataSources (Firebase): البيانات السحابية
/// - Repositories: تنسيق بين Local و Remote
/// - UseCases: عمليات المسارات والرحلات
/// - BLoCs: إدارة حالة الرحلات

void _registerTripsFeature({bool useFirebase = false}) {
  AppLogger.info('[DI] Registering Trips feature dependencies (useFirebase: $useFirebase)', name: 'DI');

  /// 📍 تسجيل Route Local DataSource
  /// القرار: Hive أم Mock؟ (يعتمد على AppConfig)
  /// 
  /// Hive = قاعدة بيانات محلية سريعة وآمنة
  /// Mock = بيانات وهمية للاختبار
  if (AppConfig.useMockStorage) {
    AppLogger.info('[DI] Registering Mock Route Local DataSource', name: 'DI');
    sl.registerLazySingleton<RouteLocalDataSource>(
      () => MockRouteLocalDataSource(),
    );
  } else {
    AppLogger.info('[DI] Registering Hive Route Local DataSource', name: 'DI');
    /// 💾 Hive: يحفظ المسارات على الجهاز
    /// مفيد عندما لا يكون هناك إنترنت!
    sl.registerLazySingleton<RouteLocalDataSource>(
      () => HiveRouteLocalDataSource(),
    );
  }
  
  /// 📍 تسجيل Route Remote DataSource
  /// اختيار: Firebase أم Mock؟
  if (useFirebase) {
    /// ☁️ Firebase: مزامنة المسارات من السحابة
    /// مفيد عند تسجيل الدخول من أجهزة متعددة!
    sl.registerLazySingleton<RouteRemoteDataSource>(
      () => FirebaseRouteRemoteDataSource(),
    );
  } else {
    /// 🧪 Mock: بيانات وهمية للاختبار والتطوير
    sl.registerLazySingleton<RouteRemoteDataSource>(
      () => MockRouteRemoteDataSource(),
    );
  }
  
  /// 📍 تسجيل Trip Local DataSource
  /// (Hive للرحلات النشطة)
  sl.registerLazySingleton<TripLocalDataSource>(
    () => MockTripLocalDataSource(),
  );
  
  /// 📍 تسجيل Trip Remote DataSource
  /// (Firebase للرحلات السحابية)
  if (useFirebase) {
    sl.registerLazySingleton<TripRemoteDataSource>(
      () => FirebaseTripRemoteDataSource(),
    );
  } else {
    sl.registerLazySingleton<TripRemoteDataSource>(
      () => MockTripRemoteDataSource(),
    );
  }

  /// 🔗 تسجيل RouteRepository Implementation
  /// 🎯 الدور: "اختر بين Hive و Firebase، واسأل أيهما أسرع/أحدث"
  /// 
  /// معنى ConflictResolver:
  /// إذا كانت البيانات المحلية و السحابية مختلفة → استخدم الأحدث!
  sl.registerLazySingleton<RouteRepository>(
    () => RouteRepositoryImpl(
      localDataSource: sl<RouteLocalDataSource>(),    /// 💾 Hive
      remoteDataSource: sl<RouteRemoteDataSource>(),   /// ☁️ Firebase
    ),
  );
  
  /// 🔗 تسجيل TripRepository Implementation
  /// إضافة: routeRepository
  /// لماذا؟ لأن الرحلة تحتاج معرفة المسار الأصلي!
  sl.registerLazySingleton<TripRepository>(
    () => TripRepositoryImpl(
      localDataSource: sl<TripLocalDataSource>(),
      remoteDataSource: sl<TripRemoteDataSource>(),
      routeRepository: sl<RouteRepository>(),  /// 🔄 ربط المسارات بالرحلات
    ),
  );

  /// 🎯 تسجيل Use Cases للمسارات
  /// كل Use Case = عملية محددة
  
  /// 📝 CreateRouteUseCase: "أنشئ مسار جديد"
  sl.registerLazySingleton(() => CreateRouteUseCase(sl<RouteRepository>()));
  
  /// 📖 GetUserRoutesUseCase: "احصل على جميع مسارات المستخدم"
  sl.registerLazySingleton(() => GetUserRoutesUseCase(sl<RouteRepository>()));
  
  /// ✏️ UpdateRouteUseCase: "حدّث اسم أو بيانات المسار"
  sl.registerLazySingleton(() => UpdateRouteUseCase(sl<RouteRepository>()));
  
  /// 🗑️ DeleteRouteUseCase: "احذف المسار"
  /// ملاحظة: يحتاج routeRepository و tripRepository
  /// لماذا؟ يجب التحقق من عدم وجود رحلات نشطة على المسار!
  sl.registerLazySingleton(() => DeleteRouteUseCase(
    routeRepository: sl<RouteRepository>(),
    tripRepository: sl<TripRepository>(),
  ));
  
  /// 🎯 تسجيل Use Cases للرحلات
  
  /// 🚗 StartTripUseCase: "ابدأ رحلة جديدة على مسار"
  sl.registerLazySingleton(() => StartTripUseCase(
    tripRepository: sl(),
    routeRepository: sl(),
  ));
  
  /// 🏁 EndTripUseCase: "أنهِ الرحلة الحالية"
  sl.registerLazySingleton(() => EndTripUseCase(sl()));
  
  /// 📍 UpdateTripLocationUseCase: "حدّث موقع الرحلة الحالي"
  /// (يستقبل تحديثات GPS كل ثانية)
  sl.registerLazySingleton(() => UpdateTripLocationUseCase(sl()));
  
  /// 📜 GetTripHistoryUseCase: "احصل على سجل كل الرحلات السابقة"
  sl.registerLazySingleton(() => GetTripHistoryUseCase(sl()));

  /// 📊 تسجيل RouteBloc
  /// إدارة حالة عرض المسارات
  /// registerFactory = instance جديد كل مرة
  sl.registerFactory(
    () => RouteBloc(
      createRouteUseCase: sl(),
      getUserRoutesUseCase: sl(),
      updateRouteUseCase: sl(),
      deleteRouteUseCase: sl(),
      routeRepository: sl(),
    ),
  );

  /// 📊 تسجيل TripBloc
  /// إدارة حالة الرحلات النشطة والسابقة
  sl.registerFactory(
    () => TripBloc(
      startTripUseCase: sl(),
      endTripUseCase: sl(),
      updateTripLocationUseCase: sl(),
      getTripHistoryUseCase: sl(),
      tripRepository: sl(),
    ),
  );

  AppLogger.success('[DI] Trips feature registered successfully', name: 'DI');
}

/// ═══════════════════════════════════════════════════════════════════════════
/// 🚨 _registerAlertsFeature - تسجيل ميزة التنبيهات
/// ═══════════════════════════════════════════════════════════════════════════
///
/// الهدف: تسجيل جميع Objects المتعلقة بـ Alerts Feature
/// تشمل:
/// - Alert DataSources و Repositories
/// - Contact DataSources و Repositories (جهات الاتصال الطوارئ)
/// - خدمات: FCM (إشعارات), SMS, Notifications
/// - UseCases: SendSOS, TriggerAlert, إلخ
/// - BLoCs: AlertBloc, ContactBloc

void _registerAlertsFeature({bool useFirebase = false}) {
  AppLogger.info('[DI] Registering Alerts feature dependencies (useFirebase: $useFirebase)', name: 'DI');

  /// 🚨 تسجيل Alert Local DataSource
  /// (تخزين التنبيهات محلياً)
  sl.registerLazySingleton<AlertLocalDataSource>(
    () => MockAlertLocalDataSource(),
  );
  
  /// 🚨 تسجيل Alert Remote DataSource
  /// اختيار: Firebase أم Mock؟
  if (useFirebase) {
    /// ☁️ Firebase: حفظ التنبيهات في السحابة
    /// (رسائل الطوارئ مهمة وتحتاج نسخة احتياطية!)
    sl.registerLazySingleton<AlertRemoteDataSource>(
      () => FirebaseAlertRemoteDataSource(),
    );
  } else {
    sl.registerLazySingleton<AlertRemoteDataSource>(
      () => MockAlertRemoteDataSource(),
    );
  }
  
  /// 👥 تسجيل Contact Local DataSource
  /// (تخزين جهات الاتصال الطوارئ محلياً)
  /// ملاحظة: استخدام 'as contact_ds' لتجنب تضارب الأسماء
  /// (في الأعلى استخدمنا 'import ... as contact_ds')
  if (AppConfig.useMockStorage) {
    AppLogger.info('[DI] Registering Mock Contact Local DataSource', name: 'DI');
    sl.registerLazySingleton<contact_ds.ContactLocalDataSource>(
      () => contact_ds.MockContactLocalDataSource(),
    );
  } else {
    AppLogger.info('[DI] Registering Hive Contact Local DataSource', name: 'DI');
    /// 💾 Hive: تخزين آمن وسريع للأرقام الهاتفية
    sl.registerLazySingleton<contact_ds.ContactLocalDataSource>(
      () => contact_ds.HiveContactLocalDataSource(),
    );
  }
  
  /// 👥 تسجيل Contact Remote DataSource
  /// (مزامنة جهات الاتصال مع السحابة)
  if (useFirebase) {
    /// ☁️ Firebase: احفظ جهات الاتصال في السحابة
    /// (حتى لو فقدت الهاتف، جهاتك محفوظة!)
    sl.registerLazySingleton<ContactRemoteDataSource>(
      () => FirebaseContactRemoteDataSource(),
    );
  } else {
    sl.registerLazySingleton<ContactRemoteDataSource>(
      () => MockContactRemoteDataSource(),
    );
  }

  /// 🔗 تسجيل AlertRepository Implementation
  /// مسؤولياته:
  /// 1. اختيار بين Local و Remote
  /// 2. تحديد ما إذا كنا نستخدم Mock أم Real
  /// 3. معالجة التضارب بين البيانات
  sl.registerLazySingleton<AlertRepository>(
    () => AlertRepositoryImpl(
      localDataSource: sl<AlertLocalDataSource>(),
      remoteDataSource: sl<AlertRemoteDataSource>(),
      useMock: !useFirebase,  /// true إذا لم نستخدم Firebase
    ),
  );
  
  /// 🔗 تسجيل ContactRepository Implementation
  /// (نفس فكرة AlertRepository)
  sl.registerLazySingleton<ContactRepository>(
    () => ContactRepositoryImpl(
      localDataSource: sl<contact_ds.ContactLocalDataSource>(),
      remoteDataSource: sl<ContactRemoteDataSource>(),
      useMock: !useFirebase,
    ),
  );

  /// 📞 تسجيل خدمات التنبيهات
  
  /// 🔔 NotificationService
  /// الدور: إظهار إشعارات على الشاشة
  /// (مثل Toast messages)
  sl.registerLazySingleton(() => NotificationService());
  
  /// 🔥 FCMService
  /// الدور: Firebase Cloud Messaging
  /// استقبال إشعارات الخادم حتى لو كان التطبيق مغلقاً!
  /// useMock: إذا لم نستخدم Firebase، استخدم بيانات وهمية
  sl.registerLazySingleton(() => FCMService(useMock: !useFirebase));
  
  /// 💬 SMSService
  /// الدور: إرسال رسائل نصية للطوارئ
  /// (رسائل قصيرة عبر Twilio أو خدمة مشابهة)
  sl.registerLazySingleton(() => SMSService());

  /// 🎯 تسجيل Use Cases للتنبيهات
  
  /// 🚨 TriggerAlertUseCase: "اطلق تنبيه عام"
  sl.registerLazySingleton(() => TriggerAlertUseCase(sl()));
  
  /// ✅ AcknowledgeAlertUseCase: "اقبل التنبيه (تم الإجابة)"
  sl.registerLazySingleton(() => AcknowledgeAlertUseCase(sl()));
  
  /// ❌ CancelAlertUseCase: "إلغاء التنبيه"
  sl.registerLazySingleton(() => CancelAlertUseCase(sl()));
  
  /// 📢 EscalateAlertUseCase: "رفع مستوى التنبيه (إرسال لعدد أكثر من جهات الاتصال)"
  /// يحتاج: alertRepository و contactRepository
  /// لماذا؟ لأنه يحتاج قائمة جهات الاتصال!
  sl.registerLazySingleton(() => EscalateAlertUseCase(
    alertRepository: sl(),
    contactRepository: sl(),
  ));
  
  /// 🆘 SendSOSUseCase: "إرسال نداء استغاثة فوري"
  /// حالة طوارئ قصوى: إرسال للجميع فوراً!
  sl.registerLazySingleton(() => SendSOSUseCase(
    alertRepository: sl(),
    contactRepository: sl(),
  ));
  
  /// 📜 GetAlertHistoryUseCase: "احصل على سجل التنبيهات السابقة"
  sl.registerLazySingleton(() => GetAlertHistoryUseCase(sl()));

  /// 📊 تسجيل AlertBloc
  /// إدارة حالة التنبيهات والـ SOS
  /// معامل: هذا BLoC يحتاج الكثير من الـ Objects!
  sl.registerFactory(
    () => AlertBloc(
      alertRepository: sl(),           /// قاعدة بيانات التنبيهات
      contactRepository: sl(),         /// قاعدة بيانات جهات الاتصال
      triggerAlertUseCase: sl(),       /// إطلاق تنبيه
      acknowledgeAlertUseCase: sl(),   /// قبول التنبيه
      cancelAlertUseCase: sl(),        /// إلغاء التنبيه
      escalateAlertUseCase: sl(),      /// رفع مستوى التنبيه
      sendSOSUseCase: sl(),            /// نداء استغاثة
      getAlertHistoryUseCase: sl(),    /// سجل التنبيهات
      notificationService: sl(),       /// إظهار إشعارات
      fcmService: sl(),                /// Firebase messaging
      smsService: sl(),                /// إرسال SMS
    ),
  );

  /// 📊 تسجيل ContactBloc
  /// إدارة جهات الاتصال (إضافة، حذف، تحديث)
  sl.registerFactory(
    () => ContactBloc(contactRepository: sl()),
  );

  AppLogger.success('[DI] Alerts feature registered successfully', name: 'DI');
}

/// ═══════════════════════════════════════════════════════════════════════════
/// 🔧 _registerCoreServices - تسجيل خدمات Core
/// ═══════════════════════════════════════════════════════════════════════════
///
/// الهدف: تسجيل الخدمات الأساسية التي يحتاجها التطبيق كله
/// هذه تُسجل أولاً لأن كل شيء يعتمد عليها!
///
/// الخدمات:
/// 1. HiveService: قاعدة البيانات المحلية
/// 2. LocalStorageService: تخزين البيانات
/// 3. ConnectivityService: مراقبة الإنترنت
/// 4. SyncService & SyncManager: مزامنة البيانات الذكية
/// 5. ConflictResolver: معالجة التضارب بين Local و Remote

void _registerCoreServices() {
  AppLogger.info('[DI] Registering Core services', name: 'DI');

  /// 💾 HiveService: Singleton
  /// Hive = قاعدة بيانات محلية سريعة جداً
  /// Singleton معناه: نفس instance في كل مكان
  /// لا نريد عدة copies من قاعدة البيانات!
  sl.registerLazySingleton<HiveService>(() => HiveService.instance);
  
  /// 📦 LocalStorageService: Singleton
  /// Wrapper حول Hive لتسهيل الاستخدام
  /// (تخزين بيانات مثل: آخر موقع، آخر رحلة، إلخ)
  sl.registerLazySingleton<LocalStorageService>(() => LocalStorageService.instance);
  
  /// 📡 ConnectivityService: Singleton
  /// الدور: مراقبة حالة الإنترنت
  /// هل الجهاز متصل بـ WiFi؟ بـ 4G؟ معطوع؟
  /// مهم جداً للمزامنة الذكية!
  sl.registerLazySingleton<ConnectivityService>(() => ConnectivityService.instance);
  
  /// 🔄 SyncService: Singleton
  /// الدور: مزامنة البيانات بين Local و Remote
  /// "إذا كان هناك إنترنت، تأكد أن البيانات محدثة"
  sl.registerLazySingleton<SyncService>(() => SyncService.instance);
  
  /// 🔄 SyncManager: Singleton
  /// الدور: إدارة عملية المزامنة برمتها
  /// متى نزامن؟ كيف نزامن؟ هل حدث صراع؟
  sl.registerLazySingleton<SyncManager>(() => SyncManager.instance);
  
  /// ⚔️ ConflictResolver: Singleton
  /// الدور: حل الصراعات بين البيانات
  /// سيناريو: بيانات محلية + بيانات سحابية مختلفة
  /// "أيهما أحدث؟ أيهما أصح؟"
  /// ConflictResolver يقرر!
  sl.registerLazySingleton<ConflictResolver>(() => ConflictResolver.instance);

  AppLogger.success('[DI] Core services registered successfully', name: 'DI');
}

/// ═══════════════════════════════════════════════════════════════════════════
/// 🗺️ _registerMapsFeature - تسجيل ميزة الخرائط
/// ═══════════════════════════════════════════════════════════════════════════
///
/// الهدف: تسجيل جميع Objects المتعلقة بـ Maps Feature
/// تشمل:
/// - LocationService: الحصول على GPS والموقع الحالي
/// - GeocodingService: تحويل الإحداثيات لأسماء أماكن
/// - DeviationDetector: الكشف عن الانحراف عن المسار
/// - MapBloc و LocationBloc: إدارة حالة الخرائط والموقع

void _registerMapsFeature() {
  AppLogger.info('[DI] Registering Maps feature dependencies', name: 'DI');

  /// 📍 تسجيل خدمات الخرائط
  
  /// 🧭 LocationService: Singleton
  /// الدور: الحصول على الموقع الجغرافي الحالي من GPS
  /// (تحديثات الموقع كل ثانية أو أقل)
  /// مهم جداً لـ:
  /// - عرض موقع المستخدم على الخريطة
  /// - كشف الانحراف عن المسار
  /// - تتبع الرحلة في الوقت الفعلي
  sl.registerLazySingleton<LocationService>(() => LocationService());
  
  /// 🔍 GeocodingService: Singleton
  /// الدور: تحويل الإحداثيات (Latitude, Longitude)
  /// إلى أسماء أماكن (مثل: "شارع الملك فهد، الرياض")
  /// استخدامات:
  /// - عرض عنوان بشري بدل أرقام
  /// - البحث عن الأماكن بالاسم
  sl.registerLazySingleton<GeocodingService>(() => GeocodingService());
  
  /// ⚠️ DeviationDetector: Singleton
  /// الدور: كشف الانحراف عن المسار المخطط
  /// "هل السائق سار في المسار الصحيح؟"
  /// إذا انحرف 100 متر عن المسار → تنبيه!
  sl.registerLazySingleton<DeviationDetector>(() => DeviationDetector());

  /// 📊 تسجيل BLoCs للخرائط
  
  /// 🗺️ MapBloc: Factory
  /// إدارة حالة عرض الخريطة
  /// (موضع الخريطة، المسار المرسوم، المواقع المهمة)
  sl.registerFactory(
    () => MapBloc(
      locationService: sl<LocationService>(),        /// 🧭 الموقع الحالي
      geocodingService: sl<GeocodingService>(),       /// 🔍 تحويل إحداثيات
      deviationDetector: sl<DeviationDetector>(),     /// ⚠️ كشف الانحراف
    ),
  );

  /// 📍 LocationBloc: Factory
  /// إدارة حالة الموقع الحالي
  /// (تحديثات GPS المستمرة)
  sl.registerFactory(
    () => LocationBloc(
      locationService: sl<LocationService>(),        /// 🧭 الموقع الحالي
      geocodingService: sl<GeocodingService>(),       /// 🔍 تحويل إحداثيات
    ),
  );

  AppLogger.success('[DI] Maps feature registered successfully', name: 'DI');
}

/// ═══════════════════════════════════════════════════════════════════════════
/// 🔄 resetDependencies - إعادة تعيين جميع التبعيات
/// ═══════════════════════════════════════════════════════════════════════════
///
/// الهدف: مسح جميع Objects من GetIt
/// متى نستخدمها؟
/// - في الاختبارات: قبل كل test
/// - عند الخروج: تنظيف الموارد
/// - عند تغيير الإعدادات: Firebase On/Off
///
/// بعد هذه الدالة:
/// _isInitialized = false
/// → يمكن استدعاء initializeDependencies مرة أخرى

Future<void> resetDependencies() async {
  AppLogger.info('[DI] Resetting dependencies', name: 'DI');
  
  /// 🗑️ حذف جميع الـ Objects من GetIt
  /// هذا يحرر الذاكرة والموارد
  await sl.reset();
  
  /// 🔄 إعادة تعيين الـ flag
  /// حتى يمكن تهيئة Dependencies مرة أخرى
  _isInitialized = false;
  
  AppLogger.success('[DI] Dependencies reset successfully', name: 'DI');
}
