import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:psga_app/app.dart';
import 'package:psga_app/core/config/env_config.dart';
import 'package:psga_app/core/services/connectivity_service.dart';
import 'package:psga_app/core/services/fcm_service.dart';
import 'package:psga_app/core/services/notification_service.dart';
import 'package:psga_app/core/services/sync_manager.dart';
import 'package:psga_app/core/services/sync_service.dart';
import 'package:psga_app/core/services/ml_analysis_service.dart';
import 'package:psga_app/core/storage/hive_service.dart';
import 'package:psga_app/core/storage/local_storage_service.dart';
import 'package:psga_app/core/utils/logger.dart';
import 'package:psga_app/injection_container.dart' as di;

void main() async {
  // التأكد من تهيئة Flutter
  WidgetsFlutterBinding.ensureInitialized();

  AppLogger.start('تطبيق PSGA');

  try {
    // تثبيت اتجاه الشاشة (عمودي فقط)
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    AppLogger.info('[Main] تم تثبيت اتجاه الشاشة');

    // تهيئة Firebase
    await Firebase.initializeApp();
    AppLogger.success('[Main] تم تهيئة Firebase');

    // تحميل إعدادات البيئة (.env)
    await EnvConfig.load();
    AppLogger.success('[Main] تم تحميل إعدادات البيئة');

    // تهيئة Hive
    final hiveService = HiveService.instance;
    await hiveService.init();
    AppLogger.success('[Main] تم تهيئة Hive');

    // تهيئة Connectivity Service
    final connectivityService = ConnectivityService.instance;
    await connectivityService.init();
    AppLogger.success('[Main] تم تهيئة Connectivity Service');

    // تهيئة Sync Service
    final syncService = SyncService.instance;
    await syncService.init();
    AppLogger.success('[Main] تم تهيئة Sync Service');

    // تهيئة Dependency Injection
    await di.setupDependencyInjection();
    AppLogger.success('[Main] تم تهيئة Dependency Injection');

    // تهيئة Sync Manager
    final syncManager = SyncManager.instance;
    final localStorage = di.sl<LocalStorageService>();
    await syncManager.init(localStorage);
    AppLogger.success('[Main] تم تهيئة Sync Manager');

    // ✨ تهيئة ML Analysis Service
    try {
      final mlService = MLAnalysisService.instance;
      // تعيين عنوان الخادم من متغيرات البيئة أو استخدام القيمة الافتراضية
      final mlServerUrl = EnvConfig.mlServerUrl;
      mlService.setBaseUrl(mlServerUrl);
      
      // فحص اتصال الخادم (اختياري - لا نوقف التطبيق إذا فشل)
      final isHealthy = await mlService.checkHealth();
      if (isHealthy) {
        AppLogger.success('[Main] تم الاتصال بخادم ML بنجاح');
      } else {
        AppLogger.warning('[Main] خادم ML غير متاح - سيتم المحاولة لاحقاً');
      }
    } catch (e) {
      AppLogger.warning('[Main] فشل تهيئة ML Service (سيتم المحاولة لاحقاً)', e);
      // لا نوقف التطبيق - ML Service اختياري
    }

    // ✨ تهيئة FCM (اختياري - للحصول على Token مبكراً)
    try {
      final fcmService = FCMService.instance;
      await fcmService.initialize();
      AppLogger.success('[Main] تم تهيئة FCM Service');

      if (fcmService.fcmToken != null) {
        AppLogger.info('[Main] FCM Token: ${fcmService.fcmToken!.substring(0, 20)}...');
      }
    } catch (e) {
      AppLogger.warning('[Main] فشل تهيئة FCM (سيتم المحاولة لاحقاً)', e);
      // لا نوقف التطبيق - FCM اختياري
    }

    // ✨ تهيئة الإشعارات المحلية (اختياري)
    try {
      final notificationService = NotificationService.instance;
      await notificationService.initialize();
      AppLogger.success('[Main] تم تهيئة Notification Service');
    } catch (e) {
      AppLogger.warning('[Main] فشل تهيئة الإشعارات', e);
      // لا نوقف التطبيق
    }

    AppLogger.success('[Main] تم تهيئة التطبيق بنجاح');

    // تشغيل التطبيق
    runApp(const PSGAApp());
  } catch (e, stackTrace) {
    AppLogger.error('[Main] فشل في تهيئة التطبيق', e, stackTrace);

    // في حالة الفشل، عرض شاشة خطأ
    runApp(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 80,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'فشل في تهيئة التطبيق',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    e.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      // إعادة تشغيل التطبيق
                      SystemNavigator.pop();
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('إعادة المحاولة'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}