import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'app.dart';
import 'config/app_config.dart';
import 'core/di/injection_container.dart';
import 'core/services/storage/hive_service.dart';
import 'core/services/sync/sync_manager.dart';
import 'core/services/sync/sync_service.dart';
import 'core/services/connectivity/connectivity_service.dart';
import 'core/utils/logger.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// 📌 ملف main.dart - نقطة البداية الرئيسية للتطبيق
/// ═══════════════════════════════════════════════════════════════════════════
/// 
/// الهدف من هذا الملف:
/// هذا الملف هو أول ملف يتم تنفيذه عند بدء التطبيق. مسؤوليته:
/// 1️⃣ تهيئة بيئة Flutter والنظام
/// 2️⃣ إعداد التخزين المحلي (Hive) للعمل offline-first
/// 3️⃣ التحقق من الاتصال بالإنترنت
/// 4️⃣ تهيئة Firebase (إذا كان مفعلاً)
/// 5️⃣ حقن جميع التبعيات (Dependency Injection) قبل بدء التطبيق
/// 6️⃣ إعداد نظام المزامنة الذكي
/// 7️⃣ بدء تشغيل التطبيق
/// 
/// تدفق البيانات:
/// main() → تهيئة الخدمات → حقن التبعيات → PSGAApp() → Home Page
///
void main() async {
  AppLogger.info('[main.dart] Starting PSGA application', name: 'main');
  
  /// 🔹 التهيئة الأساسية لـ Flutter
  /// WidgetsFlutterBinding: تأكد من أن جميع خدمات Flutter جاهزة قبل تنفيذ أي async code
  /// هذا ضروري لأن البرنامج يستخدم async في main()
  WidgetsFlutterBinding.ensureInitialized();
  AppLogger.success('[main.dart] Flutter bindings initialized', name: 'main');

  AppLogger.info('[main.dart] Setting system UI overlay style', name: 'main');
  /// 🎨 إعدادات النظام (System UI)
  /// استخدمنا Brightness.light للـ statusBar لأن الخلفية شفافة
  /// استخدمنا Brightness.dark للـ navigation bar لأنه أبيض
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  AppLogger.info('[main.dart] Setting preferred orientations', name: 'main');
  /// 📱 قفل اتجاه الشاشة
  /// حددنا الوضع العمودي فقط (portrait)
  /// await = انتظر حتى يتم تنفيذ الأمر
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  AppLogger.success('[main.dart] Preferred orientations set', name: 'main');

  AppLogger.info('[main.dart] Initializing Hive local storage', name: 'main');
  /// 💾 تهيئة Hive (قاعدة البيانات المحلية)
  /// Hive هي قاعدة بيانات محلية سريعة جداً على الجهاز
  /// نستخدمها لتخزين البيانات بدون إنترنت (Offline-First)
  /// HiveService.instance = نسخة واحدة فقط من الخدمة (Singleton)
  /// await = انتظر حتى تنتهي عملية التهيئة قبل المتابعة
  try {
    await HiveService.instance.init();
    AppLogger.success('[main.dart] Hive initialized successfully', name: 'main');
  } catch (e) {
    /// إذا فشلت الـ Hive، سجل الخطأ لكن لا تحقف التطبيق (try-catch)
    AppLogger.error('[main.dart] Failed to initialize Hive: $e', name: 'main');
  }

  AppLogger.info('[main.dart] Initializing Connectivity Service', name: 'main');
  /// 📡 تهيئة خدمة الاتصال
  /// هذه الخدمة تراقب هل الجهاز متصل بالإنترنت أم لا
  /// نستخدمها لقرار: هل نحفظ في السحابة (Firebase) أم محلياً (Hive)؟
  /// await = انتظر حتى تتهيأ الخدمة
  try {
    await ConnectivityService.instance.init();
    AppLogger.success('[main.dart] Connectivity Service initialized', name: 'main');
  } catch (e) {
    AppLogger.error('[main.dart] Failed to initialize Connectivity: $e', name: 'main');
  }

  bool useFirebaseAuth = false;
  
  /// 🔥 تهيئة Firebase (اختياري)
  /// نتحقق من إعدادات التطبيق:
  /// 1. إذا كان enableFirebase = true و useMockAuth = false
  ///    → استخدم Firebase الحقيقي للمصادقة والبيانات
  /// 2. إذا كان useMockAuth = true
  ///    → استخدم بيانات مزيفة (للاختبار والتطوير)
  /// 3. إذا كان enableFirebase = false
  ///    → لا تهيئ Firebase على الإطلاق
  if (AppConfig.enableFirebase && !AppConfig.useMockAuth) {
    try {
      AppLogger.info('[main.dart] Initializing Firebase...', name: 'main');
      /// await Firebase.initializeApp():
      /// اتصل بخادم Google وهيئ Firebase
      /// هذا يحتاج وقت لذلك نستخدم await
      await Firebase.initializeApp();
      useFirebaseAuth = true;
      AppLogger.success('[main.dart] Firebase initialized successfully', name: 'main');
    } catch (e) {
      /// إذا فشل Firebase (مثلاً لا توجد إنترنت أو إعدادات خاطئة)
      /// سننتقل تلقائياً لـ Mock Auth للتطوير المحلي
      AppLogger.error('[main.dart] Failed to initialize Firebase: $e', name: 'main');
      AppLogger.warning('[main.dart] Falling back to Mock authentication', name: 'main');
      AppLogger.warning('[main.dart] For Firebase setup, see Steps_Firebase.md', name: 'main');
      useFirebaseAuth = false;
    }
  } else if (AppConfig.useMockAuth) {
    /// وضع التطوير: استخدم بيانات مزيفة
    AppLogger.info('[main.dart] Using Mock authentication mode (development)', name: 'main');
  } else {
    /// تم تعطيل Firebase من الإعدادات
    AppLogger.info('[main.dart] Firebase disabled in config', name: 'main');
  }

  AppLogger.info('[main.dart] Initializing dependencies', name: 'main');
  /// 🔗 حقن التبعيات (Dependency Injection)
  /// هذه خطوة حساسة جداً:
  /// - ننشئ جميع الـ Classes والـ BLoCs والـ Repositories
  /// - نسجلها في GetIt container (sl = service locator)
  /// - بعد هذا، أي Widget يحتاج Class معين يستطيع استدعاء: sl<ClassName>()
  /// - useFirebase يحدد: هل نستخدم Firebase أم Mock؟
  /// - await = انتظر حتى ينتهي التسجيل (قد يأخذ وقتاً)
  await initializeDependencies(useFirebase: useFirebaseAuth);
  AppLogger.success('[main.dart] Dependencies initialized', name: 'main');

  /// 🔄 إعداد نظام المزامنة الذكي
  /// SyncManager: يدير مزامنة البيانات بين Hive (محلي) و Firebase (سحابي)
  /// setSyncFunction: نخبره "استخدم هذه الدالة للمزامنة"
  /// هذا يسمح بـ offline-first: حفظ محلياً أولاً، ثم مزامنة عند الاتصال
  AppLogger.info('[main.dart] 🔄 Setting up Sync Manager...', name: 'main');
  SyncManager.instance.setSyncFunction(SyncService.instance.syncToFirestore);
  
  AppLogger.success('[main.dart] All initializations complete, launching app', name: 'main');
  AppLogger.info('[main.dart] Auth Mode: ${useFirebaseAuth ? "Firebase" : "Mock"}', name: 'main');
  
  /// 🚀 تشغيل التطبيق الرئيسي
  /// runApp() تبدأ البرنامج وتعرض PSGAApp widget
  /// كل شيء تم تحضيره أعلاه، الآن نبني الـ UI
  runApp(const PSGAApp());

  /// 📤 بدء المزامنة التلقائية (بتأخير 2 ثانية)
  /// لماذا التأخير؟
  /// - نريد التأكد من أن جميع BLoCs جاهزة قبل بدء المزامنة
  /// - إذا بدأنا فوراً، قد لا تكون BLoCs في الذاكرة بعد
  /// Future.delayed = انتظر مدة زمنية، ثم نفذ الكود
  /// اختبار: jika useFirebaseAuth = false (Mock mode)، لا تبدأ المزامنة
  if (useFirebaseAuth) {
    Future.delayed(const Duration(seconds: 2), () {
      AppLogger.info('[main.dart] 🔄 بدء المزامنة التلقائية المتأخرة...', name: 'main');
      SyncManager.instance.startAutoSync();
    });
  }
}
