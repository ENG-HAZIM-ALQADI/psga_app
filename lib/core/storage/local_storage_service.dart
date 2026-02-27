import 'package:psga_app/core/constants/app_strings.dart';
import 'package:psga_app/core/storage/hive_service.dart';
import 'package:psga_app/core/utils/logger.dart';
import 'package:psga_app/features/auth/data/models/user_model.dart';

/// خدمة التخزين المحلي الموحدة
class LocalStorageService {
  final HiveService _hiveService;

  LocalStorageService(this._hiveService);

  // ==================== User Storage ====================

  /// حفظ المستخدم
  Future<void> saveUser(UserModel user) async {
    try {
      AppLogger.info('[LocalStorage] حفظ المستخدم: ${user.id}');
      // ✅ استخدام getTypedBox للـ user_box
      final box = _hiveService.getTypedBox<UserModel>(AppStrings.userBox);
      await box.put('current_user', user);
      AppLogger.success('[LocalStorage] تم حفظ المستخدم');
    } catch (e) {
      AppLogger.error('[LocalStorage] فشل حفظ المستخدم', e);
      rethrow;
    }
  }

  /// الحصول على المستخدم
  UserModel? getUser() {
    try {
      // ✅ استخدام getTypedBox للـ user_box
      final box = _hiveService.getTypedBox<UserModel>(AppStrings.userBox);
      final user = box.get('current_user');
      if (user != null) {
        AppLogger.info('[LocalStorage] تم العثور على المستخدم: ${user.id}');
      } else {
        AppLogger.info('[LocalStorage] لا يوجد مستخدم محفوظ');
      }
      return user;
    } catch (e) {
      AppLogger.error('[LocalStorage] فشل الحصول على المستخدم', e);
      return null;
    }
  }

  /// حذف المستخدم
  Future<void> deleteUser() async {
    try {
      AppLogger.info('[LocalStorage] حذف المستخدم');
      // ✅ استخدام getTypedBox للـ user_box
      final box = _hiveService.getTypedBox<UserModel>(AppStrings.userBox);
      await box.delete('current_user');
      AppLogger.success('[LocalStorage] تم حذف المستخدم');
    } catch (e) {
      AppLogger.error('[LocalStorage] فشل حذف المستخدم', e);
      rethrow;
    }
  }

  /// هل يوجد مستخدم محفوظ؟
  bool hasUser() {
    try {
      // ✅ استخدام getTypedBox للـ user_box
      final box = _hiveService.getTypedBox<UserModel>(AppStrings.userBox);
      return box.containsKey('current_user');
    } catch (e) {
      AppLogger.error('[LocalStorage] فشل التحقق من وجود مستخدم', e);
      return false;
    }
  }

  // ==================== Settings Storage ====================

  /// حفظ إعداد
  Future<void> saveSetting(String key, dynamic value) async {
    try {
      await _hiveService.put(AppStrings.settingsBox, key, value);
      AppLogger.info('[LocalStorage] تم حفظ إعداد: $key');
    } catch (e) {
      AppLogger.error('[LocalStorage] فشل حفظ إعداد: $key', e);
      rethrow;
    }
  }

  /// الحصول على إعداد
  T? getSetting<T>(String key, {T? defaultValue}) {
    try {
      final value = _hiveService.get<T>(AppStrings.settingsBox, key);
      return value ?? defaultValue;
    } catch (e) {
      AppLogger.error('[LocalStorage] فشل الحصول على إعداد: $key', e);
      return defaultValue;
    }
  }

  /// حذف إعداد
  Future<void> deleteSetting(String key) async {
    try {
      await _hiveService.delete(AppStrings.settingsBox, key);
      AppLogger.info('[LocalStorage] تم حذف إعداد: $key');
    } catch (e) {
      AppLogger.error('[LocalStorage] فشل حذف إعداد: $key', e);
      rethrow;
    }
  }

  /// مسح جميع الإعدادات
  Future<void> clearSettings() async {
    try {
      await _hiveService.clearBox(AppStrings.settingsBox);
      AppLogger.success('[LocalStorage] تم مسح جميع الإعدادات');
    } catch (e) {
      AppLogger.error('[LocalStorage] فشل مسح الإعدادات', e);
      rethrow;
    }
  }

  // ==================== Routes Storage ====================

  /// حفظ مسار
  Future<void> saveRoute(dynamic route) async {
    try {
      final id = route.id as String;
      AppLogger.info('[LocalStorage] حفظ المسار: $id');
      await _hiveService.put('routes', id, route);
      AppLogger.success('[LocalStorage] تم حفظ المسار');
    } catch (e) {
      AppLogger.error('[LocalStorage] فشل حفظ المسار', e);
      rethrow;
    }
  }

  /// الحصول على مسار
  dynamic getRoute(String id) {
    try {
      final route = _hiveService.get('routes', id);
      if (route != null) {
        AppLogger.info('[LocalStorage] تم العثور على المسار: $id');
      } else {
        AppLogger.info('[LocalStorage] المسار غير موجود: $id');
      }
      return route;
    } catch (e) {
      AppLogger.error('[LocalStorage] فشل الحصول على المسار', e);
      return null;
    }
  }

  /// الحصول على جميع المسارات
  List<dynamic> getAllRoutes() {
    try {
      final routes = _hiveService.getAll('routes');
      AppLogger.info('[LocalStorage] تم الحصول على ${routes.length} مسار');
      return routes;
    } catch (e) {
      AppLogger.error('[LocalStorage] فشل الحصول على المسارات', e);
      return [];
    }
  }

  /// حذف مسار
  Future<void> deleteRoute(String id) async {
    try {
      await _hiveService.delete('routes', id);
      AppLogger.success('[LocalStorage] تم حذف المسار: $id');
    } catch (e) {
      AppLogger.error('[LocalStorage] فشل حذف المسار', e);
      rethrow;
    }
  }

  /// مسح جميع المسارات
  Future<void> clearRoutes() async {
    try {
      await _hiveService.clearBox('routes');
      AppLogger.success('[LocalStorage] تم مسح جميع المسارات');
    } catch (e) {
      AppLogger.error('[LocalStorage] فشل مسح المسارات', e);
      rethrow;
    }
  }

  // ==================== Trips Storage ====================

  /// حفظ رحلة
  Future<void> saveTrip(dynamic trip) async {
    try {
      final id = trip.id as String;
      AppLogger.info('[LocalStorage] حفظ الرحلة: $id');
      await _hiveService.put('trips', id, trip);
      AppLogger.success('[LocalStorage] تم حفظ الرحلة');
    } catch (e) {
      AppLogger.error('[LocalStorage] فشل حفظ الرحلة', e);
      rethrow;
    }
  }

  /// الحصول على رحلة
  dynamic getTrip(String id) {
    try {
      final trip = _hiveService.get('trips', id);
      if (trip != null) {
        AppLogger.info('[LocalStorage] تم العثور على الرحلة: $id');
      } else {
        AppLogger.info('[LocalStorage] الرحلة غير موجودة: $id');
      }
      return trip;
    } catch (e) {
      AppLogger.error('[LocalStorage] فشل الحصول على الرحلة', e);
      return null;
    }
  }

  /// الحصول على جميع الرحلات
  List<dynamic> getAllTrips() {
    try {
      final trips = _hiveService.getAll('trips');
      AppLogger.info('[LocalStorage] تم الحصول على ${trips.length} رحلة');
      return trips;
    } catch (e) {
      AppLogger.error('[LocalStorage] فشل الحصول على الرحلات', e);
      return [];
    }
  }

  /// حذف رحلة
  Future<void> deleteTrip(String id) async {
    try {
      await _hiveService.delete('trips', id);
      AppLogger.success('[LocalStorage] تم حذف الرحلة: $id');
    } catch (e) {
      AppLogger.error('[LocalStorage] فشل حذف الرحلة', e);
      rethrow;
    }
  }

  /// مسح جميع الرحلات
  Future<void> clearTrips() async {
    try {
      await _hiveService.clearBox('trips');
      AppLogger.success('[LocalStorage] تم مسح جميع الرحلات');
    } catch (e) {
      AppLogger.error('[LocalStorage] فشل مسح الرحلات', e);
      rethrow;
    }
  }

  // ==================== Alerts Storage ====================

  /// حفظ تنبيه
  Future<void> saveAlert(dynamic alert) async {
    try {
      final id = alert.id as String;
      AppLogger.info('[LocalStorage] حفظ التنبيه: $id');
      await _hiveService.put('alerts', id, alert);
      AppLogger.success('[LocalStorage] تم حفظ التنبيه');
    } catch (e) {
      AppLogger.error('[LocalStorage] فشل حفظ التنبيه', e);
      rethrow;
    }
  }

  /// الحصول على تنبيه
  dynamic getAlert(String id) {
    try {
      final alert = _hiveService.get('alerts', id);
      if (alert != null) {
        AppLogger.info('[LocalStorage] تم العثور على التنبيه: $id');
      } else {
        AppLogger.info('[LocalStorage] التنبيه غير موجود: $id');
      }
      return alert;
    } catch (e) {
      AppLogger.error('[LocalStorage] فشل الحصول على التنبيه', e);
      return null;
    }
  }

  /// الحصول على جميع التنبيهات
  List<dynamic> getAllAlerts() {
    try {
      final alerts = _hiveService.getAll('alerts');
      AppLogger.info('[LocalStorage] تم الحصول على ${alerts.length} تنبيه');
      return alerts;
    } catch (e) {
      AppLogger.error('[LocalStorage] فشل الحصول على التنبيهات', e);
      return [];
    }
  }

  /// حذف تنبيه
  Future<void> deleteAlert(String id) async {
    try {
      await _hiveService.delete('alerts', id);
      AppLogger.success('[LocalStorage] تم حذف التنبيه: $id');
    } catch (e) {
      AppLogger.error('[LocalStorage] فشل حذف التنبيه', e);
      rethrow;
    }
  }

  /// مسح جميع التنبيهات
  Future<void> clearAlerts() async {
    try {
      await _hiveService.clearBox('alerts');
      AppLogger.success('[LocalStorage] تم مسح جميع التنبيهات');
    } catch (e) {
      AppLogger.error('[LocalStorage] فشل مسح التنبيهات', e);
      rethrow;
    }
  }

  // ==================== Contacts Storage ====================

  /// حفظ جهة اتصال
  Future<void> saveContact(dynamic contact) async {
    try {
      final id = contact.id as String;
      AppLogger.info('[LocalStorage] حفظ جهة الاتصال: $id');
      await _hiveService.put('contacts', id, contact);
      AppLogger.success('[LocalStorage] تم حفظ جهة الاتصال');
    } catch (e) {
      AppLogger.error('[LocalStorage] فشل حفظ جهة الاتصال', e);
      rethrow;
    }
  }

  /// الحصول على جهة اتصال
  dynamic getContact(String id) {
    try {
      final contact = _hiveService.get('contacts', id);
      if (contact != null) {
        AppLogger.info('[LocalStorage] تم العثور على جهة الاتصال: $id');
      } else {
        AppLogger.info('[LocalStorage] جهة الاتصال غير موجودة: $id');
      }
      return contact;
    } catch (e) {
      AppLogger.error('[LocalStorage] فشل الحصول على جهة الاتصال', e);
      return null;
    }
  }

  /// الحصول على جميع جهات الاتصال
  List<dynamic> getAllContacts() {
    try {
      final contacts = _hiveService.getAll('contacts');
      AppLogger.info('[LocalStorage] تم الحصول على ${contacts.length} جهة اتصال');
      return contacts;
    } catch (e) {
      AppLogger.error('[LocalStorage] فشل الحصول على جهات الاتصال', e);
      return [];
    }
  }

  /// حذف جهة اتصال
  Future<void> deleteContact(String id) async {
    try {
      await _hiveService.delete('contacts', id);
      AppLogger.success('[LocalStorage] تم حذف جهة الاتصال: $id');
    } catch (e) {
      AppLogger.error('[LocalStorage] فشل حذف جهة الاتصال', e);
      rethrow;
    }
  }

  /// مسح جميع جهات الاتصال
  Future<void> clearContacts() async {
    try {
      await _hiveService.clearBox('contacts');
      AppLogger.success('[LocalStorage] تم مسح جميع جهات الاتصال');
    } catch (e) {
      AppLogger.error('[LocalStorage] فشل مسح جهات الاتصال', e);
      rethrow;
    }
  }

  // ==================== Cache Storage ====================

  /// حفظ في Cache مع مدة صلاحية
  Future<void> cacheData(String key, dynamic data, {Duration? ttl}) async {
    try {
      final cacheEntry = {
        'data': data,
        'timestamp': DateTime.now().toIso8601String(),
        'ttl': ttl?.inSeconds,
      };
      
      await _hiveService.put(AppStrings.cacheBox, key, cacheEntry);
      AppLogger.info('[LocalStorage] تم تخزين في Cache: $key');
    } catch (e) {
      AppLogger.error('[LocalStorage] فشل التخزين في Cache: $key', e);
      rethrow;
    }
  }

  /// الحصول من Cache
  T? getCachedData<T>(String key) {
    try {
      final cacheEntry = _hiveService.get<Map>(AppStrings.cacheBox, key);
      if (cacheEntry == null) return null;

      // التحقق من مدة الصلاحية
      final timestamp = DateTime.parse(cacheEntry['timestamp']);
      final ttl = cacheEntry['ttl'] as int?;

      if (ttl != null) {
        final expiryTime = timestamp.add(Duration(seconds: ttl));
        if (DateTime.now().isAfter(expiryTime)) {
          AppLogger.info('[LocalStorage] Cache منتهي الصلاحية: $key');
          deleteCachedData(key); // حذف Cache المنتهي
          return null;
        }
      }

      return cacheEntry['data'] as T?;
    } catch (e) {
      AppLogger.error('[LocalStorage] فشل الحصول من Cache: $key', e);
      return null;
    }
  }

  /// حذف من Cache
  Future<void> deleteCachedData(String key) async {
    try {
      await _hiveService.delete(AppStrings.cacheBox, key);
      AppLogger.info('[LocalStorage] تم حذف من Cache: $key');
    } catch (e) {
      AppLogger.error('[LocalStorage] فشل حذف من Cache: $key', e);
    }
  }

  /// مسح جميع Cache
  Future<void> clearCache() async {
    try {
      await _hiveService.clearBox(AppStrings.cacheBox);
      AppLogger.success('[LocalStorage] تم مسح جميع Cache');
    } catch (e) {
      AppLogger.error('[LocalStorage] فشل مسح Cache', e);
      rethrow;
    }
  }

  // ==================== Utility ====================

  /// حجم البيانات المخزنة (تقريبي)
  Map<String, int> getStorageSize() {
    return {
      'userBox': _hiveService.getBoxSize(AppStrings.userBox),
      'settingsBox': _hiveService.getBoxSize(AppStrings.settingsBox),
      'cacheBox': _hiveService.getBoxSize(AppStrings.cacheBox),
      'syncQueueBox': _hiveService.getBoxSize(AppStrings.syncQueueBox),
      'routesBox': _hiveService.getBoxSize('routes'),
      'tripsBox': _hiveService.getBoxSize('trips'),
      'alertsBox': _hiveService.getBoxSize('alerts'),
      'contactsBox': _hiveService.getBoxSize('contacts'),
    };
  }

  /// عدد العناصر في كل Box
  Map<String, int> getStorageCount() {
    return {
      'users': _hiveService.length(AppStrings.userBox),
      'settings': _hiveService.length(AppStrings.settingsBox),
      'cache': _hiveService.length(AppStrings.cacheBox),
      'syncQueue': _hiveService.length(AppStrings.syncQueueBox),
      'routes': _hiveService.length('routes'),
      'trips': _hiveService.length('trips'),
      'alerts': _hiveService.length('alerts'),
      'contacts': _hiveService.length('contacts'),
    };
  }

  /// مسح جميع البيانات المحلية
  Future<void> clearAllData() async {
    try {
      AppLogger.warning('[LocalStorage] مسح جميع البيانات المحلية');
      
      await deleteUser();
      await clearSettings();
      await clearCache();
      await clearRoutes();
      await clearTrips();
      await clearAlerts();
      await clearContacts();
      await _hiveService.clearBox(AppStrings.syncQueueBox);
      
      AppLogger.success('[LocalStorage] تم مسح جميع البيانات');
    } catch (e) {
      AppLogger.error('[LocalStorage] فشل مسح جميع البيانات', e);
      rethrow;
    }
  }
}
