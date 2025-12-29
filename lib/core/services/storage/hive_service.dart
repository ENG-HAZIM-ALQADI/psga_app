import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../adapters/user_adapter.dart';
import '../../adapters/route_adapter.dart';
import '../../adapters/trip_adapter.dart';
import '../../adapters/waypoint_adapter.dart';
import '../../adapters/location_adapter.dart';
import '../../adapters/alert_adapter.dart';
import '../../adapters/contact_adapter.dart';
import '../../adapters/alert_config_adapter.dart';
import '../../adapters/deviation_adapter.dart';
import '../../adapters/sync_item_adapter.dart' as adapter;
import '../../../features/auth/data/models/user_model.dart';
import '../../../features/trips/data/models/route_model.dart';
import '../../../features/trips/data/models/trip_model.dart';
import '../../../features/alerts/data/models/alert_model.dart';
import '../../../features/alerts/data/models/contact_model.dart';
import '../../../features/alerts/data/models/alert_config_model.dart';
import '../../services/sync/sync_item.dart';
import 'hive_boxes.dart';

/// خدمة Hive - Singleton
/// تهيئة وإدارة قاعدة البيانات المحلية
class HiveService {
  HiveService._();

  static final HiveService _instance = HiveService._();
  static HiveService get instance => _instance;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  /// تهيئة Hive وتسجيل جميع الـ Adapters
  Future<void> init() async {
    if (_isInitialized) {
      debugPrint('💾 [Hive] Already initialized, skipping...');
      return;
    }

    try {
      debugPrint('💾 [Hive] جاري تهيئة التخزين المحلي...');

      // تهيئة Hive
      await Hive.initFlutter();
      debugPrint('💾 [Hive] ✅ تم تهيئة Hive');

      // تسجيل جميع الـ Type Adapters
      debugPrint('💾 [Hive] جاري تسجيل Type Adapters...');

      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(UserModelAdapter());
        debugPrint('💾 [Hive] ✅ UserModelAdapter (0)');
      }

      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(RouteModelAdapter());
        debugPrint('💾 [Hive] ✅ RouteModelAdapter (1)');
      }

      if (!Hive.isAdapterRegistered(2)) {
        Hive.registerAdapter(TripModelAdapter());
        debugPrint('💾 [Hive] ✅ TripModelAdapter (2)');
      }

      if (!Hive.isAdapterRegistered(3)) {
        Hive.registerAdapter(WaypointModelAdapter());
        debugPrint('💾 [Hive] ✅ WaypointModelAdapter (3)');
      }

      if (!Hive.isAdapterRegistered(4)) {
        Hive.registerAdapter(LocationModelAdapter());
        debugPrint('💾 [Hive] ✅ LocationModelAdapter (4)');
      }

      if (!Hive.isAdapterRegistered(5)) {
        Hive.registerAdapter(AlertModelAdapter());
        debugPrint('💾 [Hive] ✅ AlertModelAdapter (5)');
      }

      if (!Hive.isAdapterRegistered(6)) {
        Hive.registerAdapter(ContactModelAdapter());
        debugPrint('💾 [Hive] ✅ ContactModelAdapter (6)');
      }

      if (!Hive.isAdapterRegistered(7)) {
        Hive.registerAdapter(adapter.SyncItemAdapter());
        debugPrint('💾 [Hive] ✅ SyncItemAdapter (7)');
      }

      if (!Hive.isAdapterRegistered(8)) {
        Hive.registerAdapter(AlertConfigModelAdapter());
        debugPrint('💾 [Hive] ✅ AlertConfigModelAdapter (8)');
      }

      if (!Hive.isAdapterRegistered(9)) {
        Hive.registerAdapter(DeviationModelAdapter());
        debugPrint('💾 [Hive] ✅ DeviationModelAdapter (9)');
      }

      // فتح جميع الـ Boxes
      debugPrint('💾 [Hive] جاري فتح Boxes...');
      await _openAllBoxes();

      _isInitialized = true;
      debugPrint('💾 [Hive] ✅ اكتملت تهيئة التخزين المحلي بنجاح');
      debugPrint('💾 [Hive] Total Boxes: ${HiveBoxes.allBoxNames.length}');

    } catch (e, stackTrace) {
      debugPrint('💾 [Hive] ❌ فشل في تهيئة Hive: $e');
      debugPrint('💾 [Hive] Stack: $stackTrace');
      rethrow;
    }
  }

  /// فتح جميع الـ Boxes المطلوبة
  Future<void> _openAllBoxes() async {
    try {
      // دالة مساعدة لفتح Box مع معالجة أخطاء type casting
      Future<void> openBoxSafely<T>(String boxName, {bool isTyped = true}) async {
        try {
          if (!Hive.isBoxOpen(boxName)) {
            try {
              if (isTyped) {
                if (boxName == HiveBoxes.users) {
                  await Hive.openBox<UserModel>(boxName);
                } else if (boxName == HiveBoxes.routes) {
                  await Hive.openBox<RouteModel>(boxName);
                } else if (boxName == HiveBoxes.trips) {
                  await Hive.openBox<TripModel>(boxName);
                } else if (boxName == HiveBoxes.alerts) {
                  await Hive.openBox<AlertModel>(boxName);
                } else if (boxName == HiveBoxes.contacts) {
                  await Hive.openBox<ContactModel>(boxName);
                } else if (boxName == HiveBoxes.syncQueue) {
                  await Hive.openBox<SyncItem>(boxName);
                } else if (boxName == HiveBoxes.alertConfigs) {
                  await Hive.openBox<AlertConfigModel>(boxName);
                } else {
                  await Hive.openBox(boxName);
                }
              } else {
                await Hive.openBox(boxName);
              }
              debugPrint('💾 [Hive] ✅ Opened: $boxName');
            } catch (e) {
              // خطأ في الفتح (قد يكون بسبب تعارض الـ lock أو بيانات تالفة)
              debugPrint('💾 [Hive] ⚠️ خطأ في فتح $boxName: ${e.toString()}');
              
              // محاولة مسح الـ Box التالف وإعادة فتحه
              try {
                debugPrint('💾 [Hive] 🧹 محاولة مسح البيانات التالفة من $boxName...');
                await Hive.deleteBoxFromDisk(boxName);
                
                if (isTyped) {
                  if (boxName == HiveBoxes.users) {
                    await Hive.openBox<UserModel>(boxName);
                  } else if (boxName == HiveBoxes.routes) {
                    await Hive.openBox<RouteModel>(boxName);
                  } else if (boxName == HiveBoxes.trips) {
                    await Hive.openBox<TripModel>(boxName);
                  } else if (boxName == HiveBoxes.alerts) {
                    await Hive.openBox<AlertModel>(boxName);
                  } else if (boxName == HiveBoxes.contacts) {
                    await Hive.openBox<ContactModel>(boxName);
                  } else if (boxName == HiveBoxes.syncQueue) {
                    await Hive.openBox<SyncItem>(boxName);
                  } else if (boxName == HiveBoxes.alertConfigs) {
                    await Hive.openBox<AlertConfigModel>(boxName);
                  } else {
                    await Hive.openBox(boxName);
                  }
                } else {
                  await Hive.openBox(boxName);
                }
                debugPrint('💾 [Hive] ✅ تم فتح $boxName بنجاح بعد المسح');
              } catch (retryError) {
                debugPrint('💾 [Hive] ❌ فشل نهائي في فتح $boxName بعد محاولة المسح: $retryError');
                rethrow;
              }
            }
          }
        } catch (e) {
          debugPrint('💾 [Hive] ❌ خطأ غير متوقع في فتح $boxName: $e');
          rethrow;
        }
      }

      // فتح جميع الـ Boxes
      await openBoxSafely<UserModel>(HiveBoxes.users);
      await openBoxSafely<RouteModel>(HiveBoxes.routes);
      await openBoxSafely<TripModel>(HiveBoxes.trips);
      await openBoxSafely<AlertModel>(HiveBoxes.alerts);
      await openBoxSafely<ContactModel>(HiveBoxes.contacts);
      await openBoxSafely<SyncItem>(HiveBoxes.syncQueue);
      await openBoxSafely<AlertConfigModel>(HiveBoxes.alertConfigs);
      await openBoxSafely(HiveBoxes.settings, isTyped: false);
      await openBoxSafely(HiveBoxes.cache, isTyped: false);
      
      debugPrint('💾 [Hive] ✅ تم فتح جميع الـ Boxes بنجاح');
    } catch (e) {
      debugPrint('💾 [Hive] ❌ خطأ حرج في فتح Boxes: $e');
      rethrow;
    }
  }

  /// مسح جميع البيانات (عند تسجيل الخروج)
  Future<void> clearAll() async {
    try {
      debugPrint('💾 [Hive] جاري مسح جميع البيانات...');

      for (final boxName in HiveBoxes.allBoxNames) {
        if (Hive.isBoxOpen(boxName)) {
          final box = Hive.box(boxName);
          await box.clear();
          debugPrint('💾 [Hive] ✅ Cleared: $boxName');
        }
      }

      debugPrint('💾 [Hive] ✅ تم مسح جميع البيانات');
    } catch (e) {
      debugPrint('💾 [Hive] ❌ خطأ في مسح البيانات: $e');
      rethrow;
    }
  }

  /// إغلاق جميع الـ Boxes
  Future<void> close() async {
    try {
      debugPrint('💾 [Hive] جاري إغلاق جميع الـ Boxes...');

      for (final boxName in HiveBoxes.allBoxNames) {
        if (Hive.isBoxOpen(boxName)) {
          await Hive.box(boxName).close();
          debugPrint('💾 [Hive] ✅ Closed: $boxName');
        }
      }

      _isInitialized = false;
      debugPrint('💾 [Hive] ✅ تم إغلاق جميع الـ Boxes');
    } catch (e) {
      debugPrint('💾 [Hive] ❌ خطأ في الإغلاق: $e');
      rethrow;
    }
  }

  /// الحصول على معلومات حول التخزين
  Map<String, dynamic> getStorageInfo() {
    final info = <String, dynamic>{};

    for (final boxName in HiveBoxes.allBoxNames) {
      if (Hive.isBoxOpen(boxName)) {
        final box = Hive.box(boxName);
        info[boxName] = {
          'length': box.length,
          'isEmpty': box.isEmpty,
          'isOpen': box.isOpen,
        };
      } else {
        info[boxName] = {
          'isOpen': false,
        };
      }
    }

    return info;
  }

  /// طباعة معلومات التخزين
  void printStorageInfo() {
    debugPrint('💾 [Hive] ═══════════════════════════════════');
    debugPrint('💾 [Hive] Storage Information:');

    final info = getStorageInfo();
    info.forEach((boxName, data) {
      if (data['isOpen'] == true) {
        debugPrint('💾 [Hive] $boxName: ${data['length']} items');
      } else {
        debugPrint('💾 [Hive] $boxName: CLOSED');
      }
    });

    debugPrint('💾 [Hive] ═══════════════════════════════════');
  }
}