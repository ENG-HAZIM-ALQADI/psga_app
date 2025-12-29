import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'hive_boxes.dart';
import '../../../features/auth/data/models/user_model.dart';
import '../../../features/trips/data/models/route_model.dart';
import '../../../features/trips/data/models/trip_model.dart';
import '../../../features/alerts/data/models/alert_model.dart';
import '../../../features/alerts/data/models/contact_model.dart';
import '../../../features/alerts/data/models/alert_config_model.dart';

/// خدمة التخزين المحلي - Singleton
/// توفر دوال عامة ومتخصصة للتعامل مع Hive
class LocalStorageService {
  LocalStorageService._();

  static final LocalStorageService _instance = LocalStorageService._();
  static LocalStorageService get instance => _instance;

  // ════════════════════════════════════════════════════════════════
  // دوال عامة
  // ════════════════════════════════════════════════════════════════

  /// دالة مساعدة للحصول على box (أو فتحه إن لم يكن مفتوحاً)
  Box<T> _getOrOpenBox<T>(String boxName) {
    if (Hive.isBoxOpen(boxName)) {
      return Hive.box<T>(boxName);
    }
    throw Exception('❌ [Storage] الـ Box "$boxName" لم يتم فتحه - تأكد من تهيئة HiveService أولاً');
  }

  /// حفظ قيمة
  Future<void> save<T>(String boxName, String key, T value) async {
    try {
      final box = _getOrOpenBox<T>(boxName);
      await box.put(key, value);
      debugPrint('💾 [Storage] حفظ في $boxName: $key');
    } catch (e) {
      debugPrint('💾 [Storage] ❌ خطأ في الحفظ: $e');
      rethrow;
    }
  }

  /// قراءة قيمة
  Future<T?> get<T>(String boxName, String key) async {
    try {
      final box = _getOrOpenBox<T>(boxName);
      final value = box.get(key);
      debugPrint('📖 [Storage] قراءة من $boxName: $key');
      return value;
    } catch (e) {
      debugPrint('📖 [Storage] ❌ خطأ في القراءة: $e');
      return null;
    }
  }

  /// قراءة جميع القيم
  Future<List<T>> getAll<T>(String boxName) async {
    try {
      final box = _getOrOpenBox<T>(boxName);
      final values = box.values.toList();
      debugPrint('📖 [Storage] قراءة الكل من $boxName: ${values.length} عنصر');
      return values;
    } catch (e) {
      debugPrint('📖 [Storage] ❌ خطأ في قراءة الكل: $e');
      return [];
    }
  }

  /// حذف قيمة
  Future<void> delete(String boxName, String key) async {
    try {
      final box = _getOrOpenBox(boxName);
      await box.delete(key);
      debugPrint('🗑️ [Storage] حذف من $boxName: $key');
    } catch (e) {
      debugPrint('🗑️ [Storage] ❌ خطأ في الحذف: $e');
      rethrow;
    }
  }

  /// حذف جميع القيم
  Future<void> deleteAll(String boxName) async {
    try {
      final box = _getOrOpenBox(boxName);
      await box.clear();
      debugPrint('🗑️ [Storage] مسح $boxName بالكامل');
    } catch (e) {
      debugPrint('🗑️ [Storage] ❌ خطأ في المسح: $e');
      rethrow;
    }
  }

  /// هل المفتاح موجود؟
  Future<bool> exists(String boxName, String key) async {
    try {
      final box = _getOrOpenBox(boxName);
      final exists = box.containsKey(key);
      debugPrint(
          '🔍 [Storage] البحث في $boxName عن $key: ${exists ? "موجود" : "غير موجود"}');
      return exists;
    } catch (e) {
      debugPrint('🔍 [Storage] ❌ خطأ في البحث: $e');
      return false;
    }
  }

  /// عدد العناصر
  Future<int> count(String boxName) async {
    try {
      final box = _getOrOpenBox(boxName);
      final count = box.length;
      debugPrint('📊 [Storage] عدد العناصر في $boxName: $count');
      return count;
    } catch (e) {
      debugPrint('📊 [Storage] ❌ خطأ في العد: $e');
      return 0;
    }
  }

  // ════════════════════════════════════════════════════════════════
  // دوال متخصصة - Users
  // ════════════════════════════════════════════════════════════════

  /// حفظ المستخدم
  Future<void> saveUser(UserModel user) async {
    try {
      await save<UserModel>(HiveBoxes.users, 'current_user', user);
      debugPrint('💾 [Storage] حفظ المستخدم: ${user.email}');
    } catch (e) {
      debugPrint('💾 [Storage] ❌ خطأ في حفظ المستخدم: $e');
      rethrow;
    }
  }

  /// قراءة المستخدم الحالي
  Future<UserModel?> getUser() async {
    try {
      final user = await get<UserModel>(HiveBoxes.users, 'current_user');
      if (user != null) {
        debugPrint('📖 [Storage] قراءة المستخدم: ${user.email}');
      }
      return user;
    } catch (e) {
      debugPrint('📖 [Storage] ❌ خطأ في قراءة المستخدم: $e');
      return null;
    }
  }

  /// حذف المستخدم
  Future<void> clearUser() async {
    try {
      await delete(HiveBoxes.users, 'current_user');
      debugPrint('🗑️ [Storage] حذف المستخدم');
    } catch (e) {
      debugPrint('🗑️ [Storage] ❌ خطأ في حذف المستخدم: $e');
    }
  }

  // ════════════════════════════════════════════════════════════════
  // دوال متخصصة - Routes
  // ════════════════════════════════════════════════════════════════

  /// حفظ مسار واحد
  Future<void> saveRoute(RouteModel route) async {
    try {
      await save<RouteModel>(HiveBoxes.routes, route.id, route);
      debugPrint('💾 [Storage] حفظ المسار: ${route.name}');
    } catch (e) {
      debugPrint('💾 [Storage] ❌ خطأ في حفظ المسار: $e');
      rethrow;
    }
  }

  /// حذف مسار واحد
  Future<void> deleteRoute(String routeId) async {
    try {
      await delete(HiveBoxes.routes, routeId);
      debugPrint('🗑️ [Storage] حذف المسار: $routeId');
    } catch (e) {
      debugPrint('🗑️ [Storage] ❌ خطأ في حذف المسار: $e');
      rethrow;
    }
  }

  /// حفظ مسارات
  Future<void> saveRoutes(List<RouteModel> routes) async {
    try {
      final box = _getOrOpenBox<RouteModel>(HiveBoxes.routes);
      for (final route in routes) {
        await box.put(route.id, route);
      }
      debugPrint('💾 [Storage] حفظ ${routes.length} مسار');
    } catch (e) {
      debugPrint('💾 [Storage] ❌ خطأ في حفظ المسارات: $e');
      rethrow;
    }
  }

  /// قراءة جميع المسارات
  Future<List<RouteModel>> getRoutes() async {
    try {
      final routes = await getAll<RouteModel>(HiveBoxes.routes);
      debugPrint('📖 [Storage] قراءة ${routes.length} مسار');
      return routes;
    } catch (e) {
      debugPrint('📖 [Storage] ❌ خطأ في قراءة المسارات: $e');
      return [];
    }
  }

  /// قراءة مسار واحد
  Future<RouteModel?> getRoute(String routeId) async {
    try {
      final route = await get<RouteModel>(HiveBoxes.routes, routeId);
      if (route != null) {
        debugPrint('📖 [Storage] قراءة المسار: ${route.name}');
      }
      return route;
    } catch (e) {
      debugPrint('📖 [Storage] ❌ خطأ في قراءة المسار: $e');
      return null;
    }
  }

  // ════════════════════════════════════════════════════════════════
  // دوال متخصصة - Trips
  // ════════════════════════════════════════════════════════════════

  /// حفظ رحلة
  Future<void> saveTrip(TripModel trip) async {
    try {
      await save<TripModel>(HiveBoxes.trips, trip.id, trip);
      debugPrint('💾 [Storage] حفظ الرحلة: ${trip.routeName}');
    } catch (e) {
      debugPrint('💾 [Storage] ❌ خطأ في حفظ الرحلة: $e');
      rethrow;
    }
  }

  /// قراءة الرحلة النشطة
  Future<TripModel?> getActiveTrip() async {
    try {
      final trips = await getAll<TripModel>(HiveBoxes.trips);
      final activeTrip = trips.where((t) => t.isActive).firstOrNull;

      if (activeTrip != null) {
        debugPrint('📖 [Storage] قراءة الرحلة النشطة: ${activeTrip.routeName}');
      }
      return activeTrip;
    } catch (e) {
      debugPrint('📖 [Storage] ❌ خطأ في قراءة الرحلة النشطة: $e');
      return null;
    }
  }

  /// قراءة سجل الرحلات
  Future<List<TripModel>> getTripHistory() async {
    try {
      final trips = await getAll<TripModel>(HiveBoxes.trips);
      // ترتيب حسب وقت البدء (الأحدث أولاً)
      trips.sort((a, b) => b.startTime.compareTo(a.startTime));
      debugPrint('📖 [Storage] قراءة ${trips.length} رحلة');
      return trips;
    } catch (e) {
      debugPrint('📖 [Storage] ❌ خطأ في قراءة سجل الرحلات: $e');
      return [];
    }
  }

  // ════════════════════════════════════════════════════════════════
  // دوال متخصصة - Alerts
  // ════════════════════════════════════════════════════════════════

  /// حفظ تنبيه
  Future<void> saveAlert(AlertModel alert) async {
    try {
      await save<AlertModel>(HiveBoxes.alerts, alert.id, alert);
      debugPrint('💾 [Storage] حفظ التنبيه: ${alert.type.name}');
    } catch (e) {
      debugPrint('💾 [Storage] ❌ خطأ في حفظ التنبيه: $e');
      rethrow;
    }
  }

  /// قراءة سجل التنبيهات
  Future<List<AlertModel>> getAlertHistory() async {
    try {
      final alerts = await getAll<AlertModel>(HiveBoxes.alerts);
      // ترتيب حسب وقت الإنشاء (الأحدث أولاً)
      alerts.sort((a, b) => b.triggeredAt.compareTo(a.triggeredAt));
      debugPrint('📖 [Storage] قراءة ${alerts.length} تنبيه');
      return alerts;
    } catch (e) {
      debugPrint('📖 [Storage] ❌ خطأ في قراءة سجل التنبيهات: $e');
      return [];
    }
  }

  // ════════════════════════════════════════════════════════════════
  // دوال متخصصة - Contacts
  // ════════════════════════════════════════════════════════════════

  /// حفظ جهة اتصال
  Future<void> saveContact(ContactModel contact) async {
    try {
      await save<ContactModel>(HiveBoxes.contacts, contact.id, contact);
      debugPrint('💾 [Storage] حفظ جهة الاتصال: ${contact.name}');
    } catch (e) {
      debugPrint('💾 [Storage] ❌ خطأ في حفظ جهة الاتصال: $e');
      rethrow;
    }
  }

  /// قراءة جميع جهات الاتصال
  Future<List<ContactModel>> getContacts() async {
    try {
      final contacts = await getAll<ContactModel>(HiveBoxes.contacts);
      // ترتيب حسب الأولوية
      contacts.sort((a, b) => b.priority.compareTo(a.priority));
      debugPrint('📖 [Storage] قراءة ${contacts.length} جهة اتصال');
      return contacts;
    } catch (e) {
      debugPrint('📖 [Storage] ❌ خطأ في قراءة جهات الاتصال: $e');
      return [];
    }
  }

  // ════════════════════════════════════════════════════════════════
  // دوال متخصصة - Alert Config
  // ════════════════════════════════════════════════════════════════

  /// حفظ إعدادات التنبيهات
  Future<void> saveAlertConfig(AlertConfigModel config) async {
    try {
      await save<AlertConfigModel>(
          HiveBoxes.alertConfigs, config.userId, config);
      debugPrint('💾 [Storage] حفظ إعدادات التنبيهات');
    } catch (e) {
      debugPrint('💾 [Storage] ❌ خطأ في حفظ إعدادات التنبيهات: $e');
      rethrow;
    }
  }

  /// قراءة إعدادات التنبيهات
  Future<AlertConfigModel?> getAlertConfig(String userId) async {
    try {
      final config =
          await get<AlertConfigModel>(HiveBoxes.alertConfigs, userId);
      if (config != null) {
        debugPrint('📖 [Storage] قراءة إعدادات التنبيهات');
      }
      return config;
    } catch (e) {
      debugPrint('📖 [Storage] ❌ خطأ في قراءة إعدادات التنبيهات: $e');
      return null;
    }
  }
}
