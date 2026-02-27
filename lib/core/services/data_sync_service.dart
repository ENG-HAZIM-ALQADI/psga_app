import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:psga_app/core/services/connectivity_service.dart';
import 'package:psga_app/core/storage/hive_service.dart';
import 'package:psga_app/core/utils/logger.dart';
import 'package:psga_app/features/alerts/data/models/alert_model.dart';
import 'package:psga_app/features/alerts/data/models/contact_model.dart';
import 'package:psga_app/features/routes/data/models/route_model.dart';
import 'package:psga_app/features/trips/data/models/trip_model.dart';

/// خدمة جلب البيانات من السيرفر للمخزن المحلي (PULL)
/// تُستخدم عند:
/// - تسجيل الدخول لأول مرة
/// - فتح التطبيق على جهاز جديد
/// - المزامنة الدورية لضمان حداثة البيانات
class DataSyncService {
  static DataSyncService? _instance;
  static DataSyncService get instance => _instance ??= DataSyncService._();
  DataSyncService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final HiveService _hive = HiveService.instance;
  final ConnectivityService _connectivity = ConnectivityService.instance;

  bool _isSyncing = false;

  // ==================== الجلب الكامل عند تسجيل الدخول ====================

  /// جلب جميع بيانات المستخدم من السيرفر وحفظها محلياً
  /// يُستدعى عند تسجيل الدخول أو فتح التطبيق
  Future<void> pullAllUserData(String userId) async {
    if (_isSyncing) {
      AppLogger.warning('[DataSync] عملية جلب جارية بالفعل');
      return;
    }

    if (!_connectivity.isConnected) {
      AppLogger.warning('[DataSync] لا يوجد اتصال - تخطي الجلب');
      return;
    }

    _isSyncing = true;
    AppLogger.info('[DataSync] بدء جلب جميع بيانات المستخدم: $userId');

    try {
      // جلب جميع الكيانات بالتوازي
      await Future.wait([
        pullRoutes(userId),
        pullTrips(userId),
        pullContacts(userId),
        pullAlerts(userId),
      ]);
      AppLogger.success('[DataSync] اكتمل جلب جميع البيانات للمستخدم: $userId');
    } catch (e, stackTrace) {
      AppLogger.error('[DataSync] فشل جلب البيانات', e, stackTrace);
    } finally {
      _isSyncing = false;
    }
  }

  // ==================== جلب المسارات ====================

  Future<int> pullRoutes(String userId) async {
    try {
      AppLogger.info('[DataSync] جلب المسارات من السيرفر');
      final models = <RouteModel>[];

      // ✅ جلب من subcollection أولاً (المصدر الأساسي)
      try {
        final subcollSnap = await _firestore
            .collection('users')
            .doc(userId)
            .collection('routes')
            .orderBy('updatedAt', descending: true)
            .get();

        for (final doc in subcollSnap.docs) {
          final data = {...doc.data(), 'id': doc.id};
          models.add(RouteModel.fromJson(data));
        }
        AppLogger.info('[DataSync] وجد ${models.length} مسار في subcollection');
      } catch (e) {
        AppLogger.warning('[DataSync] فشل جلب routes من subcollection: $e');
      }

      // ✅ جلب من legacy collection وإضافة غير المكررة
      try {
        final legacySnap = await _firestore
            .collection('routes')
            .where('userId', isEqualTo: userId)
            .orderBy('updatedAt', descending: true)
            .get();

        for (final doc in legacySnap.docs) {
          if (!models.any((m) => m.id == doc.id)) {
            final data = {...doc.data(), 'id': doc.id};
            models.add(RouteModel.fromJson(data));
          }
        }
      } catch (e) {
        AppLogger.warning('[DataSync] فشل جلب routes من legacy: $e');
      }

      // ✅ حفظ في Hive
      for (final model in models) {
        await _hive.put<RouteModel>('routes', model.id, model);
      }

      // ✅ حفظ قائمة IDs للمستخدم
      final ids = models.map((m) => m.id).toList();
      await _hive.put('cache', 'user_routes_$userId', ids);

      AppLogger.success('[DataSync] تم حفظ ${models.length} مسار محلياً');
      return models.length;
    } catch (e, stackTrace) {
      AppLogger.error('[DataSync] فشل جلب المسارات', e, stackTrace);
      return 0;
    }
  }

  // ==================== جلب الرحلات ====================

  Future<int> pullTrips(String userId) async {
    try {
      AppLogger.info('[DataSync] جلب الرحلات من السيرفر');
      final models = <TripModel>[];

      // ✅ جلب من subcollection
      try {
        final subcollSnap = await _firestore
            .collection('users')
            .doc(userId)
            .collection('trips')
            .orderBy('startTime', descending: true)
            .limit(50) // آخر 50 رحلة
            .get();

        for (final doc in subcollSnap.docs) {
          final data = {...doc.data(), 'id': doc.id};
          models.add(TripModel.fromJson(data));
        }
        AppLogger.info('[DataSync] وجد ${models.length} رحلة في subcollection');
      } catch (e) {
        AppLogger.warning('[DataSync] فشل جلب trips من subcollection: $e');
      }

      // ✅ جلب من legacy collection
      try {
        final legacySnap = await _firestore
            .collection('trips')
            .where('userId', isEqualTo: userId)
            .orderBy('startTime', descending: true)
            .limit(50)
            .get();

        for (final doc in legacySnap.docs) {
          if (!models.any((m) => m.id == doc.id)) {
            final data = {...doc.data(), 'id': doc.id};
            models.add(TripModel.fromJson(data));
          }
        }
      } catch (e) {
        AppLogger.warning('[DataSync] فشل جلب trips من legacy: $e');
      }

      // ✅ حفظ في Hive
      for (final model in models) {
        await _hive.put<TripModel>('trips', model.id, model);
      }

      AppLogger.success('[DataSync] تم حفظ ${models.length} رحلة محلياً');
      return models.length;
    } catch (e, stackTrace) {
      AppLogger.error('[DataSync] فشل جلب الرحلات', e, stackTrace);
      return 0;
    }
  }

  // ==================== جلب جهات الاتصال ====================

  Future<int> pullContacts(String userId) async {
    try {
      AppLogger.info('[DataSync] جلب جهات الاتصال من السيرفر');
      final models = <ContactModel>[];

      // ✅ جلب من subcollection
      try {
        final subcollSnap = await _firestore
            .collection('users')
            .doc(userId)
            .collection('contacts')
            .orderBy('priority')
            .get();

        for (final doc in subcollSnap.docs) {
          final data = {...doc.data(), 'id': doc.id};
          models.add(ContactModel.fromJson(data));
        }
      } catch (e) {
        AppLogger.warning('[DataSync] فشل جلب contacts من subcollection: $e');
      }

      // ✅ جلب من legacy collection
      try {
        final legacySnap = await _firestore
            .collection('contacts')
            .where('userId', isEqualTo: userId)
            .orderBy('priority')
            .get();

        for (final doc in legacySnap.docs) {
          if (!models.any((m) => m.id == doc.id)) {
            final data = {...doc.data(), 'id': doc.id};
            models.add(ContactModel.fromJson(data));
          }
        }
      } catch (e) {
        AppLogger.warning('[DataSync] فشل جلب contacts من legacy: $e');
      }

      // ✅ حفظ في Hive
      for (final model in models) {
        await _hive.put<ContactModel>('contacts', model.id, model);
      }

      AppLogger.success('[DataSync] تم حفظ ${models.length} جهة اتصال محلياً');
      return models.length;
    } catch (e, stackTrace) {
      AppLogger.error('[DataSync] فشل جلب جهات الاتصال', e, stackTrace);
      return 0;
    }
  }

  // ==================== جلب التنبيهات ====================

  Future<int> pullAlerts(String userId) async {
    try {
      AppLogger.info('[DataSync] جلب التنبيهات من السيرفر');
      final models = <AlertModel>[];

      // ✅ جلب من subcollection
      try {
        final subcollSnap = await _firestore
            .collection('users')
            .doc(userId)
            .collection('alerts')
            .orderBy('createdAt', descending: true)
            .limit(100)
            .get();

        for (final doc in subcollSnap.docs) {
          final data = {...doc.data(), 'id': doc.id};
          models.add(AlertModel.fromJson(data));
        }
      } catch (e) {
        AppLogger.warning('[DataSync] فشل جلب alerts من subcollection: $e');
      }

      // ✅ جلب من legacy collection
      try {
        final legacySnap = await _firestore
            .collection('alerts')
            .where('userId', isEqualTo: userId)
            .orderBy('createdAt', descending: true)
            .limit(100)
            .get();

        for (final doc in legacySnap.docs) {
          if (!models.any((m) => m.id == doc.id)) {
            final data = {...doc.data(), 'id': doc.id};
            models.add(AlertModel.fromJson(data));
          }
        }
      } catch (e) {
        AppLogger.warning('[DataSync] فشل جلب alerts من legacy: $e');
      }

      // ✅ حفظ في Hive
      for (final model in models) {
        await _hive.put<AlertModel>('alerts', model.id, model);
      }

      AppLogger.success('[DataSync] تم حفظ ${models.length} تنبيه محلياً');
      return models.length;
    } catch (e, stackTrace) {
      AppLogger.error('[DataSync] فشل جلب التنبيهات', e, stackTrace);
      return 0;
    }
  }
}
