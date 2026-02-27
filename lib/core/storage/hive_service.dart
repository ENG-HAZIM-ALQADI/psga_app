import 'package:hive_flutter/hive_flutter.dart';
import 'package:psga_app/core/constants/app_strings.dart';
import 'package:psga_app/core/storage/adapters/user_adapter.dart';
import 'package:psga_app/core/storage/adapters/location_adapter.dart';
import 'package:psga_app/core/storage/adapters/waypoint_adapter.dart';
import 'package:psga_app/core/storage/adapters/route_adapter.dart';
import 'package:psga_app/core/storage/adapters/trip_adapter.dart';
import 'package:psga_app/core/storage/adapters/deviation_adapter.dart';
import 'package:psga_app/core/storage/adapters/alert_adapter.dart';
import 'package:psga_app/core/storage/adapters/alert_config_adapter.dart';
import 'package:psga_app/core/storage/adapters/contact_adapter.dart';
import 'package:psga_app/core/storage/adapters/direction_adapter.dart';
import 'package:psga_app/core/storage/adapters/place_adapter.dart';
import 'package:psga_app/core/utils/logger.dart';
import 'package:psga_app/features/auth/data/models/user_model.dart';
import 'package:psga_app/features/routes/data/models/route_model.dart';
import 'package:psga_app/features/trips/data/models/trip_model.dart';
import 'package:psga_app/features/alerts/data/models/alert_model.dart';
import 'package:psga_app/features/alerts/data/models/contact_model.dart';

/// خدمة Hive الأساسية - إدارة مركزية للتخزين المحلي
class HiveService {
  static HiveService? _instance;
  static HiveService get instance => _instance ??= HiveService._();
  
  HiveService._();

  bool _isInitialized = false;

  /// تهيئة Hive وتسجيل جميع Adapters
  Future<void> init() async {
    if (_isInitialized) {
      AppLogger.warning('[HiveService] Hive مُهيأ بالفعل');
      return;
    }

    try {
      AppLogger.info('[HiveService] جاري تهيئة Hive');

      // تهيئة Hive
      await Hive.initFlutter();

      // تسجيل جميع Type Adapters
      await _registerAdapters();

      // فتح الـ Boxes الأساسية
      await _openBoxes();

      _isInitialized = true;
      AppLogger.success('[HiveService] تم تهيئة Hive بنجاح');
    } catch (e, stackTrace) {
      AppLogger.error('[HiveService] فشل تهيئة Hive', e, stackTrace);
      rethrow;
    }
  }

  /// تسجيل جميع Type Adapters
  Future<void> _registerAdapters() async {
    try {
      AppLogger.info('[HiveService] جاري تسجيل Type Adapters');

      // User Adapter (typeId: 0)
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(UserModelAdapter());
        AppLogger.info('[HiveService] تم تسجيل UserModelAdapter');
      }

      // Location Adapter (typeId: 1)
      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(LocationModelAdapter());
        AppLogger.info('[HiveService] تم تسجيل LocationModelAdapter');
      }

      // Waypoint Adapter (typeId: 2)
      if (!Hive.isAdapterRegistered(2)) {
        Hive.registerAdapter(WaypointModelAdapter());
        AppLogger.info('[HiveService] تم تسجيل WaypointModelAdapter');
      }

      // Route Adapter (typeId: 3)
      if (!Hive.isAdapterRegistered(3)) {
        Hive.registerAdapter(RouteModelAdapter());
        AppLogger.info('[HiveService] تم تسجيل RouteModelAdapter');
      }

      // Alert Adapter (typeId: 4)
      if (!Hive.isAdapterRegistered(4)) {
        Hive.registerAdapter(AlertModelAdapter());
        AppLogger.info('[HiveService] تم تسجيل AlertModelAdapter');
      }

      // Contact Adapter (typeId: 5)
      if (!Hive.isAdapterRegistered(5)) {
        Hive.registerAdapter(ContactModelAdapter());
        AppLogger.info('[HiveService] تم تسجيل ContactModelAdapter');
      }

      // Deviation Adapter (typeId: 6)
      if (!Hive.isAdapterRegistered(6)) {
        Hive.registerAdapter(DeviationAdapter());
        AppLogger.info('[HiveService] تم تسجيل DeviationAdapter');
      }

      // AlertConfig Adapter (typeId: 7)
      if (!Hive.isAdapterRegistered(7)) {
        Hive.registerAdapter(AlertConfigModelAdapter());
        AppLogger.info('[HiveService] تم تسجيل AlertConfigModelAdapter');
      }

      // Trip Adapter (typeId: 8)
      if (!Hive.isAdapterRegistered(8)) {
        Hive.registerAdapter(TripModelAdapter());
        AppLogger.info('[HiveService] تم تسجيل TripModelAdapter');
      }

      // Direction Adapter (typeId: 20)
      if (!Hive.isAdapterRegistered(20)) {
        Hive.registerAdapter(DirectionAdapter());
        AppLogger.info('[HiveService] تم تسجيل DirectionAdapter');
      }

      // Place Adapter (typeId: 21)
      if (!Hive.isAdapterRegistered(21)) {
        Hive.registerAdapter(PlaceAdapter());
        AppLogger.info('[HiveService] تم تسجيل PlaceAdapter');
      }

      AppLogger.success('[HiveService] تم تسجيل جميع Type Adapters');
    } catch (e) {
      AppLogger.error('[HiveService] فشل تسجيل Type Adapters', e);
      rethrow;
    }
  }

  /// فتح الـ Boxes الأساسية
  Future<void> _openBoxes() async {
    try {
      AppLogger.info('[HiveService] جاري فتح Boxes');

      // User Box
      if (!Hive.isBoxOpen(AppStrings.userBox)) {
        await Hive.openBox<UserModel>(AppStrings.userBox);
        AppLogger.info('[HiveService] تم فتح ${AppStrings.userBox}');
      }

      // Routes Box
      if (!Hive.isBoxOpen('routes')) {
        await Hive.openBox<RouteModel>('routes');
        AppLogger.info('[HiveService] تم فتح routes');
      }

      // Trips Box
      if (!Hive.isBoxOpen('trips')) {
        await Hive.openBox<TripModel>('trips');
        AppLogger.info('[HiveService] تم فتح trips');
      }

      // Alerts Box
      if (!Hive.isBoxOpen('alerts')) {
        await Hive.openBox<AlertModel>('alerts');
        AppLogger.info('[HiveService] تم فتح alerts');
      }

      // Contacts Box
      if (!Hive.isBoxOpen('contacts')) {
        await Hive.openBox<ContactModel>('contacts');
        AppLogger.info('[HiveService] تم فتح contacts');
      }

      // Alert Configs Box (للإعدادات)
      if (!Hive.isBoxOpen('alert_configs')) {
        await Hive.openBox('alert_configs');
        AppLogger.info('[HiveService] تم فتح alert_configs');
      }

      // Settings Box
      if (!Hive.isBoxOpen(AppStrings.settingsBox)) {
        await Hive.openBox(AppStrings.settingsBox);
        AppLogger.info('[HiveService] تم فتح ${AppStrings.settingsBox}');
      }

      // Sync Queue Box
      if (!Hive.isBoxOpen(AppStrings.syncQueueBox)) {
        await Hive.openBox(AppStrings.syncQueueBox);
        AppLogger.info('[HiveService] تم فتح ${AppStrings.syncQueueBox}');
      }

      // Cache Box
      if (!Hive.isBoxOpen(AppStrings.cacheBox)) {
        await Hive.openBox(AppStrings.cacheBox);
        AppLogger.info('[HiveService] تم فتح ${AppStrings.cacheBox}');
      }
      
      // App Settings Box (لإعدادات الرحلات وغيرها)
      if (!Hive.isBoxOpen('app_settings')) {
        await Hive.openBox('app_settings');
        AppLogger.info('[HiveService] تم فتح app_settings');
      }

      AppLogger.success('[HiveService] تم فتح جميع Boxes');
    } catch (e) {
      AppLogger.error('[HiveService] فشل فتح Boxes', e);
      rethrow;
    }
  }

  /// الحصول على Box
  Box getBox(String boxName) {
    if (!Hive.isBoxOpen(boxName)) {
      throw Exception('Box "$boxName" غير مفتوح. استخدم openBox أولاً');
    }
    return Hive.box(boxName);
  }
  
  /// الحصول على Box بنوع محدد
  Box<T> getTypedBox<T>(String boxName) {
    if (!Hive.isBoxOpen(boxName)) {
      throw Exception('Box "$boxName" غير مفتوح. استخدم openBox أولاً');
    }
    return Hive.box<T>(boxName);
  }

  /// فتح Box جديد
  Future<Box<T>> openBox<T>(String boxName) async {
    try {
      if (Hive.isBoxOpen(boxName)) {
        AppLogger.info('[HiveService] Box "$boxName" مفتوح بالفعل');
        return Hive.box<T>(boxName);
      }

      AppLogger.info('[HiveService] جاري فتح Box "$boxName"');
      final box = await Hive.openBox<T>(boxName);
      AppLogger.success('[HiveService] تم فتح Box "$boxName"');
      return box;
    } catch (e) {
      AppLogger.error('[HiveService] فشل فتح Box "$boxName"', e);
      rethrow;
    }
  }

  /// إغلاق Box
  Future<void> closeBox(String boxName) async {
    try {
      if (!Hive.isBoxOpen(boxName)) {
        AppLogger.warning('[HiveService] Box "$boxName" غير مفتوح');
        return;
      }

      AppLogger.info('[HiveService] جاري إغلاق Box "$boxName"');
      await Hive.box(boxName).close();
      AppLogger.success('[HiveService] تم إغلاق Box "$boxName"');
    } catch (e) {
      AppLogger.error('[HiveService] فشل إغلاق Box "$boxName"', e);
      rethrow;
    }
  }

  /// حذف Box بالكامل
  Future<void> deleteBox(String boxName) async {
    try {
      AppLogger.info('[HiveService] جاري حذف Box "$boxName"');
      await Hive.deleteBoxFromDisk(boxName);
      AppLogger.success('[HiveService] تم حذف Box "$boxName"');
    } catch (e) {
      AppLogger.error('[HiveService] فشل حذف Box "$boxName"', e);
      rethrow;
    }
  }

  /// مسح محتويات Box
  Future<void> clearBox(String boxName) async {
    try {
      if (!Hive.isBoxOpen(boxName)) {
        AppLogger.warning('[HiveService] Box "$boxName" غير مفتوح');
        return;
      }

      AppLogger.info('[HiveService] جاري مسح Box "$boxName"');
      
      // محاولة الوصول كـ Box عادي أولاً
      try {
        await Hive.box(boxName).clear();
      } catch (e) {
        // إذا فشل، جرب typed box
        if (boxName == 'routes') {
          await Hive.box<RouteModel>(boxName).clear();
        } else if (boxName == 'trips') {
          await Hive.box<TripModel>(boxName).clear();
        } else if (boxName == 'alerts') {
          await Hive.box<AlertModel>(boxName).clear();
        } else if (boxName == 'contacts') {
          await Hive.box<ContactModel>(boxName).clear();
        } else if (boxName == AppStrings.userBox) {
          await Hive.box<UserModel>(boxName).clear();
        } else {
          rethrow;
        }
      }
      
      AppLogger.success('[HiveService] تم مسح Box "$boxName"');
    } catch (e) {
      AppLogger.error('[HiveService] فشل مسح Box "$boxName"', e);
      rethrow;
    }
  }

  // ==================== CRUD Operations ====================

  /// حفظ قيمة
  Future<void> put<T>(String boxName, String key, T value) async {
    try {
      AppLogger.info('[HiveService] حفظ "$key" في "$boxName"');
      
      // للـ boxes المحددة النوع (routes, trips, alerts, contacts, users)
      final isTypedBox = boxName == 'routes' || 
                        boxName == 'trips' || 
                        boxName == 'alerts' || 
                        boxName == 'contacts' ||
                        boxName == AppStrings.userBox;
      
      if (isTypedBox) {
        // استخدام getTypedBox لحفظ Models مباشرة
        final box = getTypedBox<T>(boxName);
        await box.put(key, value);
      } else {
        // للـ boxes العادية - استخدام Hive.box مباشرة
        if (!Hive.isBoxOpen(boxName)) {
          throw Exception('Box "$boxName" غير مفتوح');
        }
        final box = Hive.box(boxName);
        await box.put(key, value);
      }
      
      AppLogger.success('[HiveService] تم حفظ "$key" في "$boxName"');
    } catch (e, stackTrace) {
      AppLogger.error('[HiveService] فشل حفظ "$key" في "$boxName"', e, stackTrace);
      rethrow;
    }
  }

  /// الحصول على قيمة
  T? get<T>(String boxName, String key) {
    try {
      // للـ boxes المحددة النوع (routes, trips, alerts, contacts, users)
      final isTypedBox = boxName == 'routes' || 
                        boxName == 'trips' || 
                        boxName == 'alerts' || 
                        boxName == 'contacts' ||
                        boxName == AppStrings.userBox;
      
      final value = isTypedBox 
          ? getTypedBox<T>(boxName).get(key)
          : (Hive.isBoxOpen(boxName) ? Hive.box(boxName).get(key) : null);
          
      if (value != null) {
        AppLogger.info('[HiveService] تم العثور على "$key" في "$boxName"');
      } else {
        AppLogger.info('[HiveService] لم يتم العثور على "$key" في "$boxName"');
      }
      return value as T?;
    } catch (e, stackTrace) {
      AppLogger.error('[HiveService] فشل الحصول على "$key" من "$boxName"', e, stackTrace);
      return null;
    }
  }

  /// حذف قيمة
  Future<void> delete(String boxName, String key) async {
    try {
      // ✅ التحقق من أن Box مفتوح
      if (!Hive.isBoxOpen(boxName)) {
        throw Exception('Box "$boxName" غير مفتوح');
      }
      
      // ✅ استخدام BoxBase للوصول الديناميكي لأي نوع box
      final BoxBase box = Hive.box(boxName);
      await box.delete(key);
      AppLogger.info('[HiveService] تم حذف "$key" من "$boxName"');
    } catch (e) {
      // إذا فشل الوصول كـ Box عادي، نجرب كـ typed box
      try {
        if (boxName == 'routes') {
          final box = Hive.box<RouteModel>(boxName);
          await box.delete(key);
        } else if (boxName == 'trips') {
          final box = Hive.box<TripModel>(boxName);
          await box.delete(key);
        } else if (boxName == 'alerts') {
          final box = Hive.box<AlertModel>(boxName);
          await box.delete(key);
        } else if (boxName == 'contacts') {
          final box = Hive.box<ContactModel>(boxName);
          await box.delete(key);
        } else if (boxName == AppStrings.userBox) {
          final box = Hive.box<UserModel>(boxName);
          await box.delete(key);
        } else {
          AppLogger.error('[HiveService] فشل حذف "$key" من "$boxName"', e);
          rethrow;
        }
        AppLogger.info('[HiveService] تم حذف "$key" من "$boxName" (typed box)');
      } catch (e2) {
        AppLogger.error('[HiveService] فشل حذف "$key" من "$boxName"', e2);
        rethrow;
      }
    }
  }

  /// التحقق من وجود مفتاح
  bool containsKey(String boxName, String key) {
    try {
      if (!Hive.isBoxOpen(boxName)) {
        return false;
      }
      
      // محاولة الوصول كـ Box عادي أولاً
      try {
        final BoxBase box = Hive.box(boxName);
        return box.containsKey(key);
      } catch (e) {
        // إذا فشل، جرب typed box
        if (boxName == 'routes') {
          return Hive.box<RouteModel>(boxName).containsKey(key);
        } else if (boxName == 'trips') {
          return Hive.box<TripModel>(boxName).containsKey(key);
        } else if (boxName == 'alerts') {
          return Hive.box<AlertModel>(boxName).containsKey(key);
        } else if (boxName == 'contacts') {
          return Hive.box<ContactModel>(boxName).containsKey(key);
        } else if (boxName == AppStrings.userBox) {
          return Hive.box<UserModel>(boxName).containsKey(key);
        }
        return false;
      }
    } catch (e) {
      AppLogger.error('[HiveService] فشل التحقق من "$key" في "$boxName"', e);
      return false;
    }
  }

  /// الحصول على جميع القيم
  List<T> getAll<T>(String boxName) {
    try {
      final box = getTypedBox<T>(boxName);
      final values = box.values.toList();
      AppLogger.info('[HiveService] تم الحصول على ${values.length} عنصر من "$boxName"');
      return values;
    } catch (e) {
      AppLogger.error('[HiveService] فشل الحصول على القيم من "$boxName"', e);
      return [];
    }
  }

  /// الحصول على جميع المفاتيح
  List<dynamic> getKeys(String boxName) {
    try {
      if (!Hive.isBoxOpen(boxName)) {
        return [];
      }
      
      // محاولة الوصول كـ Box عادي أولاً
      try {
        final BoxBase box = Hive.box(boxName);
        return box.keys.toList();
      } catch (e) {
        // إذا فشل، جرب typed box
        if (boxName == 'routes') {
          return Hive.box<RouteModel>(boxName).keys.toList();
        } else if (boxName == 'trips') {
          return Hive.box<TripModel>(boxName).keys.toList();
        } else if (boxName == 'alerts') {
          return Hive.box<AlertModel>(boxName).keys.toList();
        } else if (boxName == 'contacts') {
          return Hive.box<ContactModel>(boxName).keys.toList();
        } else if (boxName == AppStrings.userBox) {
          return Hive.box<UserModel>(boxName).keys.toList();
        }
        return [];
      }
    } catch (e) {
      AppLogger.error('[HiveService] فشل الحصول على المفاتيح من "$boxName"', e);
      return [];
    }
  }

  /// عدد العناصر في Box
  int length(String boxName) {
    try {
      if (!Hive.isBoxOpen(boxName)) {
        return 0;
      }
      
      // محاولة الوصول كـ Box عادي أولاً
      try {
        final BoxBase box = Hive.box(boxName);
        return box.length;
      } catch (e) {
        // إذا فشل، جرب typed box
        if (boxName == 'routes') {
          return Hive.box<RouteModel>(boxName).length;
        } else if (boxName == 'trips') {
          return Hive.box<TripModel>(boxName).length;
        } else if (boxName == 'alerts') {
          return Hive.box<AlertModel>(boxName).length;
        } else if (boxName == 'contacts') {
          return Hive.box<ContactModel>(boxName).length;
        } else if (boxName == AppStrings.userBox) {
          return Hive.box<UserModel>(boxName).length;
        }
        return 0;
      }
    } catch (e) {
      AppLogger.error('[HiveService] فشل الحصول على عدد العناصر من "$boxName"', e);
      return 0;
    }
  }

  /// التحقق من فراغ Box
  bool isEmpty(String boxName) {
    try {
      if (!Hive.isBoxOpen(boxName)) {
        return true;
      }
      
      // محاولة الوصول كـ Box عادي أولاً
      try {
        final BoxBase box = Hive.box(boxName);
        return box.isEmpty;
      } catch (e) {
        // إذا فشل، جرب typed box
        if (boxName == 'routes') {
          return Hive.box<RouteModel>(boxName).isEmpty;
        } else if (boxName == 'trips') {
          return Hive.box<TripModel>(boxName).isEmpty;
        } else if (boxName == 'alerts') {
          return Hive.box<AlertModel>(boxName).isEmpty;
        } else if (boxName == 'contacts') {
          return Hive.box<ContactModel>(boxName).isEmpty;
        } else if (boxName == AppStrings.userBox) {
          return Hive.box<UserModel>(boxName).isEmpty;
        }
        return true;
      }
    } catch (e) {
      AppLogger.error('[HiveService] فشل التحقق من فراغ "$boxName"', e);
      return true;
    }
  }

  // ==================== Batch Operations ====================

  /// حفظ عدة قيم دفعة واحدة
  Future<void> putAll<T>(String boxName, Map<String, T> entries) async {
    try {
      final box = getTypedBox<T>(boxName);
      await box.putAll(entries);
      AppLogger.info('[HiveService] تم حفظ ${entries.length} عنصر في "$boxName"');
    } catch (e) {
      AppLogger.error('[HiveService] فشل حفظ العناصر في "$boxName"', e);
      rethrow;
    }
  }

  /// حذف عدة قيم دفعة واحدة
  Future<void> deleteAll(String boxName, List<String> keys) async {
    try {
      if (!Hive.isBoxOpen(boxName)) {
        throw Exception('Box "$boxName" غير مفتوح');
      }
      
      // محاولة الوصول كـ Box عادي أولاً
      try {
        final BoxBase box = Hive.box(boxName);
        await box.deleteAll(keys);
        AppLogger.info('[HiveService] تم حذف ${keys.length} عنصر من "$boxName"');
      } catch (e) {
        // إذا فشل، جرب typed box
        if (boxName == 'routes') {
          await Hive.box<RouteModel>(boxName).deleteAll(keys);
        } else if (boxName == 'trips') {
          await Hive.box<TripModel>(boxName).deleteAll(keys);
        } else if (boxName == 'alerts') {
          await Hive.box<AlertModel>(boxName).deleteAll(keys);
        } else if (boxName == 'contacts') {
          await Hive.box<ContactModel>(boxName).deleteAll(keys);
        } else if (boxName == AppStrings.userBox) {
          await Hive.box<UserModel>(boxName).deleteAll(keys);
        } else {
          rethrow;
        }
        AppLogger.info('[HiveService] تم حذف ${keys.length} عنصر من "$boxName" (typed box)');
      }
    } catch (e) {
      AppLogger.error('[HiveService] فشل حذف العناصر من "$boxName"', e);
      rethrow;
    }
  }

  // ==================== Utility Methods ====================

  /// إغلاق جميع Boxes
  Future<void> closeAllBoxes() async {
    try {
      AppLogger.info('[HiveService] جاري إغلاق جميع Boxes');
      await Hive.close();
      _isInitialized = false;
      AppLogger.success('[HiveService] تم إغلاق جميع Boxes');
    } catch (e) {
      AppLogger.error('[HiveService] فشل إغلاق جميع Boxes', e);
      rethrow;
    }
  }

  /// حذف جميع البيانات (للتطوير فقط)
  Future<void> deleteAllData() async {
    try {
      AppLogger.warning('[HiveService] جاري حذف جميع البيانات');
      await Hive.deleteFromDisk();
      _isInitialized = false;
      AppLogger.success('[HiveService] تم حذف جميع البيانات');
    } catch (e) {
      AppLogger.error('[HiveService] فشل حذف جميع البيانات', e);
      rethrow;
    }
  }

  /// الحصول على حجم Box بالبايتات
  int getBoxSize(String boxName) {
    try {
      if (!Hive.isBoxOpen(boxName)) {
        return 0;
      }
      
      // محاولة الوصول كـ Box عادي أولاً
      try {
        final BoxBase box = Hive.box(boxName);
        return box.length * 1024; // تقدير: كل عنصر ~1KB
      } catch (e) {
        // إذا فشل، جرب typed box
        int length = 0;
        if (boxName == 'routes') {
          length = Hive.box<RouteModel>(boxName).length;
        } else if (boxName == 'trips') {
          length = Hive.box<TripModel>(boxName).length;
        } else if (boxName == 'alerts') {
          length = Hive.box<AlertModel>(boxName).length;
        } else if (boxName == 'contacts') {
          length = Hive.box<ContactModel>(boxName).length;
        } else if (boxName == AppStrings.userBox) {
          length = Hive.box<UserModel>(boxName).length;
        }
        return length * 1024;
      }
    } catch (e) {
      AppLogger.error('[HiveService] فشل الحصول على حجم "$boxName"', e);
      return 0;
    }
  }

  /// معلومات عن جميع Boxes
  Map<String, dynamic> getBoxesInfo() {
    try {
      final openBoxes = <String>[];
      
      if (Hive.isBoxOpen(AppStrings.userBox)) openBoxes.add(AppStrings.userBox);
      if (Hive.isBoxOpen(AppStrings.settingsBox)) openBoxes.add(AppStrings.settingsBox);
      if (Hive.isBoxOpen(AppStrings.syncQueueBox)) openBoxes.add(AppStrings.syncQueueBox);
      if (Hive.isBoxOpen(AppStrings.cacheBox)) openBoxes.add(AppStrings.cacheBox);
      
      return {
        'openBoxes': openBoxes.length,
        'isInitialized': _isInitialized,
        'boxes': [
          {
            'name': AppStrings.userBox,
            'isOpen': Hive.isBoxOpen(AppStrings.userBox),
            'length': Hive.isBoxOpen(AppStrings.userBox)
                ? Hive.box(AppStrings.userBox).length
                : 0,
          },
          {
            'name': AppStrings.settingsBox,
            'isOpen': Hive.isBoxOpen(AppStrings.settingsBox),
            'length': Hive.isBoxOpen(AppStrings.settingsBox)
                ? Hive.box(AppStrings.settingsBox).length
                : 0,
          },
          {
            'name': AppStrings.syncQueueBox,
            'isOpen': Hive.isBoxOpen(AppStrings.syncQueueBox),
            'length': Hive.isBoxOpen(AppStrings.syncQueueBox)
                ? Hive.box(AppStrings.syncQueueBox).length
                : 0,
          },
        ],
      };
    } catch (e) {
      AppLogger.error('[HiveService] فشل الحصول على معلومات Boxes', e);
      return {};
    }
  }
}
