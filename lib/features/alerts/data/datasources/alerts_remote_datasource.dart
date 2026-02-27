import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:psga_app/core/errors/exceptions.dart';
import 'package:psga_app/core/utils/logger.dart';
import 'package:psga_app/features/alerts/data/models/alert_config_model.dart';
import 'package:psga_app/features/alerts/data/models/alert_model.dart';
import 'package:psga_app/features/alerts/data/models/contact_model.dart';
import 'package:psga_app/features/alerts/domain/entities/alert_config_entity.dart';
import 'package:psga_app/features/alerts/domain/entities/alert_entity.dart';

/// مصدر بيانات التنبيهات من Firestore
abstract class AlertsRemoteDataSource {
  Future<AlertModel> createAlert(AlertModel alert);
  Future<AlertModel> updateAlert(AlertModel alert);
  Future<AlertModel> getAlertById(String alertId);
  Future<List<AlertModel>> getActiveAlerts(String userId);
  Future<List<AlertModel>> getAlertHistory({
    required String userId,
    DateTime? startDate,
    DateTime? endDate,
    AlertType? type,
    AlertSeverity? severity,
    int? limit,
  });
  Future<void> deleteAlert(String alertId);
  
  Future<ContactModel> createContact(ContactModel contact);
  Future<ContactModel> updateContact(ContactModel contact);
  Future<void> deleteContact(String contactId);
  Future<List<ContactModel>> getContacts(String userId);
  
  Future<AlertConfigModel> getAlertConfig(String userId);
  Future<AlertConfigModel> updateAlertConfig(AlertConfigModel config);
}

/// تنفيذ مصدر بيانات التنبيهات
class AlertsRemoteDataSourceImpl implements AlertsRemoteDataSource {
  final firestore.FirebaseFirestore firebaseFirestore;

  AlertsRemoteDataSourceImpl({required this.firebaseFirestore});

  firestore.CollectionReference get _alertsCollection =>
      firebaseFirestore.collection('alerts');

  firestore.CollectionReference get _contactsCollection =>
      firebaseFirestore.collection('contacts');

  firestore.CollectionReference get _configsCollection =>
      firebaseFirestore.collection('alert_configs');

  @override
  Future<AlertModel> createAlert(AlertModel alert) async {
    try {
      AppLogger.info('[AlertsRemote] إنشاء تنبيه: ${alert.id}');
      await _alertsCollection.doc(alert.id).set(alert.toJson());
      AppLogger.success('[AlertsRemote] تم إنشاء التنبيه');
      return alert;
    } on firestore.FirebaseException catch (e) {
      AppLogger.error('[AlertsRemote] خطأ Firebase', e);
      throw ServerException(e.message ?? 'فشل إنشاء التنبيه');
    } catch (e, stackTrace) {
      AppLogger.error('[AlertsRemote] خطأ غير متوقع', e, stackTrace);
      throw ServerException('فشل إنشاء التنبيه');
    }
  }

  @override
  Future<AlertModel> updateAlert(AlertModel alert) async {
    try {
      AppLogger.info('[AlertsRemote] تحديث تنبيه: ${alert.id}');
      await _alertsCollection.doc(alert.id).update(alert.toJson());
      AppLogger.success('[AlertsRemote] تم تحديث التنبيه');
      return alert;
    } on firestore.FirebaseException catch (e) {
      AppLogger.error('[AlertsRemote] خطأ Firebase', e);
      throw ServerException(e.message ?? 'فشل تحديث التنبيه');
    } catch (e, stackTrace) {
      AppLogger.error('[AlertsRemote] خطأ غير متوقع', e, stackTrace);
      throw ServerException('فشل تحديث التنبيه');
    }
  }

  @override
  Future<AlertModel> getAlertById(String alertId) async {
    try {
      AppLogger.info('[AlertsRemote] جلب تنبيه: $alertId');
      final doc = await _alertsCollection.doc(alertId).get();
      
      if (!doc.exists) {
        throw ServerException('التنبيه غير موجود');
      }

      return AlertModel.fromJson({...doc.data() as Map<String, dynamic>, 'id': doc.id});
    } on firestore.FirebaseException catch (e) {
      AppLogger.error('[AlertsRemote] خطأ Firebase', e);
      throw ServerException(e.message ?? 'فشل جلب التنبيه');
    } catch (e, stackTrace) {
      AppLogger.error('[AlertsRemote] خطأ غير متوقع', e, stackTrace);
      throw ServerException('فشل جلب التنبيه');
    }
  }

  @override
  Future<List<AlertModel>> getActiveAlerts(String userId) async {
    try {
      AppLogger.info('[AlertsRemote] جلب التنبيهات النشطة');
      final snapshot = await _alertsCollection
          .where('userId', isEqualTo: userId)
          .where('status', whereIn: ['pending', 'escalated'])
          .orderBy('triggeredAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => AlertModel.fromJson({...doc.data() as Map<String, dynamic>, 'id': doc.id}))
          .toList();
    } on firestore.FirebaseException catch (e) {
      AppLogger.error('[AlertsRemote] خطأ Firebase', e);
      throw ServerException(e.message ?? 'فشل جلب التنبيهات');
    } catch (e, stackTrace) {
      AppLogger.error('[AlertsRemote] خطأ غير متوقع', e, stackTrace);
      throw ServerException('فشل جلب التنبيهات');
    }
  }

  @override
  Future<List<AlertModel>> getAlertHistory({
    required String userId,
    DateTime? startDate,
    DateTime? endDate,
    AlertType? type,
    AlertSeverity? severity,
    int? limit,
  }) async {
    try {
      AppLogger.info('[AlertsRemote] جلب سجل التنبيهات');
      
      var query = _alertsCollection
          .where('userId', isEqualTo: userId)
          .orderBy('triggeredAt', descending: true);

      if (startDate != null) {
        query = query.where('triggeredAt', isGreaterThanOrEqualTo: startDate.toIso8601String());
      }

      if (endDate != null) {
        query = query.where('triggeredAt', isLessThanOrEqualTo: endDate.toIso8601String());
      }

      if (type != null) {
        query = query.where('type', isEqualTo: type.toString().split('.').last);
      }

      if (severity != null) {
        query = query.where('severity', isEqualTo: severity.toString().split('.').last);
      }

      if (limit != null) {
        query = query.limit(limit);
      }

      final snapshot = await query.get();
      
      return snapshot.docs
          .map((doc) => AlertModel.fromJson({...doc.data() as Map<String, dynamic>, 'id': doc.id}))
          .toList();
    } on firestore.FirebaseException catch (e) {
      AppLogger.error('[AlertsRemote] خطأ Firebase', e);
      throw ServerException(e.message ?? 'فشل جلب السجل');
    } catch (e, stackTrace) {
      AppLogger.error('[AlertsRemote] خطأ غير متوقع', e, stackTrace);
      throw ServerException('فشل جلب السجل');
    }
  }

  @override
  Future<void> deleteAlert(String alertId) async {
    try {
      AppLogger.info('[AlertsRemote] حذف تنبيه: $alertId');
      await _alertsCollection.doc(alertId).delete();
      AppLogger.success('[AlertsRemote] تم حذف التنبيه');
    } on firestore.FirebaseException catch (e) {
      AppLogger.error('[AlertsRemote] خطأ Firebase', e);
      throw ServerException(e.message ?? 'فشل حذف التنبيه');
    } catch (e, stackTrace) {
      AppLogger.error('[AlertsRemote] خطأ غير متوقع', e, stackTrace);
      throw ServerException('فشل حذف التنبيه');
    }
  }

  @override
  Future<ContactModel> createContact(ContactModel contact) async {
    try {
      AppLogger.info('[AlertsRemote] إنشاء جهة اتصال: ${contact.id}');
      await _contactsCollection.doc(contact.id).set(contact.toJson());
      AppLogger.success('[AlertsRemote] تم إنشاء جهة الاتصال');
      return contact;
    } on firestore.FirebaseException catch (e) {
      AppLogger.error('[AlertsRemote] خطأ Firebase', e);
      throw ServerException(e.message ?? 'فشل إنشاء جهة الاتصال');
    } catch (e, stackTrace) {
      AppLogger.error('[AlertsRemote] خطأ غير متوقع', e, stackTrace);
      throw ServerException('فشل إنشاء جهة الاتصال');
    }
  }

  @override
  Future<ContactModel> updateContact(ContactModel contact) async {
    try {
      AppLogger.info('[AlertsRemote] تحديث جهة اتصال: ${contact.id}');
      await _contactsCollection.doc(contact.id).update(contact.toJson());
      AppLogger.success('[AlertsRemote] تم تحديث جهة الاتصال');
      return contact;
    } on firestore.FirebaseException catch (e) {
      AppLogger.error('[AlertsRemote] خطأ Firebase', e);
      throw ServerException(e.message ?? 'فشل تحديث جهة الاتصال');
    } catch (e, stackTrace) {
      AppLogger.error('[AlertsRemote] خطأ غير متوقع', e, stackTrace);
      throw ServerException('فشل تحديث جهة الاتصال');
    }
  }

  @override
  Future<void> deleteContact(String contactId) async {
    try {
      AppLogger.info('[AlertsRemote] حذف جهة اتصال: $contactId');
      await _contactsCollection.doc(contactId).delete();
      AppLogger.success('[AlertsRemote] تم حذف جهة الاتصال');
    } on firestore.FirebaseException catch (e) {
      AppLogger.error('[AlertsRemote] خطأ Firebase', e);
      throw ServerException(e.message ?? 'فشل حذف جهة الاتصال');
    } catch (e, stackTrace) {
      AppLogger.error('[AlertsRemote] خطأ غير متوقع', e, stackTrace);
      throw ServerException('فشل حذف جهة الاتصال');
    }
  }

  @override
  Future<List<ContactModel>> getContacts(String userId) async {
    try {
      AppLogger.info('[AlertsRemote] جلب جهات الاتصال');
      final snapshot = await _contactsCollection
          .where('userId', isEqualTo: userId)
          .orderBy('priority')
          .get();

      return snapshot.docs
          .map((doc) => ContactModel.fromJson({...doc.data() as Map<String, dynamic>, 'id': doc.id}))
          .toList();
    } on firestore.FirebaseException catch (e) {
      AppLogger.error('[AlertsRemote] خطأ Firebase', e);
      throw ServerException(e.message ?? 'فشل جلب جهات الاتصال');
    } catch (e, stackTrace) {
      AppLogger.error('[AlertsRemote] خطأ غير متوقع', e, stackTrace);
      throw ServerException('فشل جلب جهات الاتصال');
    }
  }

  @override
  Future<AlertConfigModel> getAlertConfig(String userId) async {
    try {
      AppLogger.info('[AlertsRemote] جلب إعدادات التنبيهات');
      final doc = await _configsCollection.doc(userId).get();
      
      if (!doc.exists) {
        // إنشاء إعدادات افتراضية
        final defaultConfig = AlertConfigModel.fromEntity(
          AlertConfigEntity.defaultConfig(userId),
        );
        await _configsCollection.doc(userId).set(defaultConfig.toJson());
        return defaultConfig;
      }

      return AlertConfigModel.fromJson({...doc.data() as Map<String, dynamic>, 'id': doc.id});
    } on firestore.FirebaseException catch (e) {
      AppLogger.error('[AlertsRemote] خطأ Firebase', e);
      throw ServerException(e.message ?? 'فشل جلب الإعدادات');
    } catch (e, stackTrace) {
      AppLogger.error('[AlertsRemote] خطأ غير متوقع', e, stackTrace);
      throw ServerException('فشل جلب الإعدادات');
    }
  }

  @override
  Future<AlertConfigModel> updateAlertConfig(AlertConfigModel config) async {
    try {
      AppLogger.info('[AlertsRemote] تحديث إعدادات التنبيهات');
      await _configsCollection.doc(config.userId).set(config.toJson());
      AppLogger.success('[AlertsRemote] تم تحديث الإعدادات');
      return config;
    } on firestore.FirebaseException catch (e) {
      AppLogger.error('[AlertsRemote] خطأ Firebase', e);
      throw ServerException(e.message ?? 'فشل تحديث الإعدادات');
    } catch (e, stackTrace) {
      AppLogger.error('[AlertsRemote] خطأ غير متوقع', e, stackTrace);
      throw ServerException('فشل تحديث الإعدادات');
    }
  }
}
