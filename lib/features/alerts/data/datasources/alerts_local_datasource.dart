import 'package:psga_app/core/errors/exceptions.dart';
import 'package:psga_app/core/storage/hive_service.dart';
import 'package:psga_app/core/utils/logger.dart';
import 'package:psga_app/features/alerts/data/models/alert_config_model.dart';
import 'package:psga_app/features/alerts/data/models/alert_model.dart';
import 'package:psga_app/features/alerts/data/models/contact_model.dart';

/// مصدر بيانات التنبيهات من Hive
abstract class AlertsLocalDataSource {
  Future<void> cacheAlert(AlertModel alert);
  Future<AlertModel?> getCachedAlert(String alertId);
  Future<List<AlertModel>> getCachedActiveAlerts(String userId);
  Future<List<AlertModel>> getCachedAlertHistory(String userId);
  Future<void> deleteAlert(String alertId);
  
  Future<void> cacheContact(ContactModel contact);
  Future<List<ContactModel>> getCachedContacts(String userId);
  Future<void> deleteContact(String contactId);
  
  Future<void> cacheAlertConfig(AlertConfigModel config);
  Future<AlertConfigModel?> getCachedAlertConfig(String userId);
}

/// تنفيذ مصدر بيانات التنبيهات
class AlertsLocalDataSourceImpl implements AlertsLocalDataSource {
  final HiveService hiveService;
  
  // استخدام نفس أسماء الـ boxes المفتوحة في HiveService
  static const String _alertsBox = 'alerts';
  static const String _contactsBox = 'contacts';
  // Box للإعدادات يجب فتحه في HiveService أو استخدام settings box
  static const String _configsBox = 'alert_configs';

  AlertsLocalDataSourceImpl({required this.hiveService});

  @override
  Future<void> cacheAlert(AlertModel alert) async {
    try {
      AppLogger.info('[AlertsLocal] حفظ تنبيه: ${alert.id}');
      // حفظ Model مباشرة في Typed Box
      await hiveService.put<AlertModel>(_alertsBox, alert.id, alert);
      AppLogger.success('[AlertsLocal] تم حفظ التنبيه');
    } catch (e, stackTrace) {
      AppLogger.error('[AlertsLocal] خطأ في الحفظ', e, stackTrace);
      throw CacheException('فشل حفظ التنبيه');
    }
  }

  @override
  Future<AlertModel?> getCachedAlert(String alertId) async {
    try {
      AppLogger.info('[AlertsLocal] جلب تنبيه: $alertId');
      // جلب Model مباشرة من Typed Box
      final alert = hiveService.get<AlertModel>(_alertsBox, alertId);
      return alert;
    } catch (e, stackTrace) {
      AppLogger.error('[AlertsLocal] خطأ في الجلب', e, stackTrace);
      throw CacheException('فشل جلب التنبيه');
    }
  }

  @override
  Future<List<AlertModel>> getCachedActiveAlerts(String userId) async {
    try {
      AppLogger.info('[AlertsLocal] جلب التنبيهات النشطة');
      
      // جلب جميع التنبيهات من Typed Box
      final allAlerts = hiveService.getAll<AlertModel>(_alertsBox);
      if (allAlerts.isEmpty) return [];

      // فلترة التنبيهات النشطة للمستخدم
      final alerts = allAlerts
          .where((alert) => alert.userId == userId && alert.isActive)
          .toList();

      alerts.sort((a, b) => b.triggeredAt.compareTo(a.triggeredAt));
      return alerts;
    } catch (e, stackTrace) {
      AppLogger.error('[AlertsLocal] خطأ في جلب التنبيهات', e, stackTrace);
      throw CacheException('فشل جلب التنبيهات');
    }
  }

  @override
  Future<List<AlertModel>> getCachedAlertHistory(String userId) async {
    try {
      AppLogger.info('[AlertsLocal] جلب سجل التنبيهات');
      
      // جلب جميع التنبيهات من Typed Box
      final allAlerts = hiveService.getAll<AlertModel>(_alertsBox);
      if (allAlerts.isEmpty) return [];

      // فلترة تنبيهات المستخدم
      final alerts = allAlerts
          .where((alert) => alert.userId == userId)
          .toList();

      alerts.sort((a, b) => b.triggeredAt.compareTo(a.triggeredAt));
      return alerts;
    } catch (e, stackTrace) {
      AppLogger.error('[AlertsLocal] خطأ في جلب السجل', e, stackTrace);
      throw CacheException('فشل جلب السجل');
    }
  }

  @override
  Future<void> deleteAlert(String alertId) async {
    try {
      AppLogger.info('[AlertsLocal] حذف تنبيه: $alertId');
      await hiveService.delete(_alertsBox, alertId);
      AppLogger.success('[AlertsLocal] تم حذف التنبيه');
    } catch (e, stackTrace) {
      AppLogger.error('[AlertsLocal] خطأ في الحذف', e, stackTrace);
      throw CacheException('فشل حذف التنبيه');
    }
  }

  @override
  Future<void> cacheContact(ContactModel contact) async {
    try {
      AppLogger.info('[AlertsLocal] حفظ جهة اتصال: ${contact.id}');
      // حفظ Model مباشرة في Typed Box
      await hiveService.put<ContactModel>(_contactsBox, contact.id, contact);
      AppLogger.success('[AlertsLocal] تم حفظ جهة الاتصال');
    } catch (e, stackTrace) {
      AppLogger.error('[AlertsLocal] خطأ في الحفظ', e, stackTrace);
      throw CacheException('فشل حفظ جهة الاتصال');
    }
  }

  @override
  Future<List<ContactModel>> getCachedContacts(String userId) async {
    try {
      AppLogger.info('[AlertsLocal] جلب جهات الاتصال');
      
      // جلب جميع جهات الاتصال من Typed Box
      final allContacts = hiveService.getAll<ContactModel>(_contactsBox);
      if (allContacts.isEmpty) return [];

      // فلترة جهات اتصال المستخدم
      final contacts = allContacts
          .where((contact) => contact.userId == userId)
          .toList();

      contacts.sort((a, b) => a.priority.compareTo(b.priority));
      return contacts;
    } catch (e, stackTrace) {
      AppLogger.error('[AlertsLocal] خطأ في جلب جهات الاتصال', e, stackTrace);
      throw CacheException('فشل جلب جهات الاتصال');
    }
  }

  @override
  Future<void> deleteContact(String contactId) async {
    try {
      AppLogger.info('[AlertsLocal] حذف جهة اتصال: $contactId');
      await hiveService.delete(_contactsBox, contactId);
      AppLogger.success('[AlertsLocal] تم حذف جهة الاتصال');
    } catch (e, stackTrace) {
      AppLogger.error('[AlertsLocal] خطأ في الحذف', e, stackTrace);
      throw CacheException('فشل حذف جهة الاتصال');
    }
  }

  @override
  Future<void> cacheAlertConfig(AlertConfigModel config) async {
    try {
      AppLogger.info('[AlertsLocal] حفظ إعدادات التنبيهات');
      await hiveService.put(_configsBox, config.userId, config.toJson());
      AppLogger.success('[AlertsLocal] تم حفظ الإعدادات');
    } catch (e, stackTrace) {
      AppLogger.error('[AlertsLocal] خطأ في الحفظ', e, stackTrace);
      throw CacheException('فشل حفظ الإعدادات');
    }
  }

  @override
  Future<AlertConfigModel?> getCachedAlertConfig(String userId) async {
    try {
      AppLogger.info('[AlertsLocal] جلب إعدادات التنبيهات');
      final data = hiveService.get(_configsBox, userId);
      
      if (data == null) return null;
      
      return AlertConfigModel.fromJson(Map<String, dynamic>.from(data as Map));
    } catch (e, stackTrace) {
      AppLogger.error('[AlertsLocal] خطأ في الجلب', e, stackTrace);
      throw CacheException('فشل جلب الإعدادات');
    }
  }
}
