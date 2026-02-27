import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';
import 'package:psga_app/core/errors/failures.dart';
import 'package:psga_app/core/repositories/base_offline_repository.dart';
import 'package:psga_app/core/storage/hive_service.dart';
import 'package:psga_app/core/services/connectivity_service.dart';
import 'package:psga_app/core/services/fcm_service.dart';
import 'package:psga_app/core/utils/logger.dart';
import 'package:psga_app/features/alerts/data/models/alert_model.dart';
import 'package:psga_app/features/alerts/data/models/contact_model.dart';
import 'package:psga_app/features/alerts/data/models/alert_config_model.dart';
import 'package:psga_app/features/alerts/domain/entities/alert_entity.dart';
import 'package:psga_app/features/alerts/domain/entities/contact_entity.dart';
import 'package:psga_app/features/alerts/domain/entities/alert_config_entity.dart';
import 'package:psga_app/features/alerts/domain/repositories/alerts_repository.dart';
import 'package:psga_app/features/alerts/data/datasources/alerts_remote_datasource.dart';
import 'package:psga_app/features/routes/domain/entities/location.dart';

/// تنفيذ مستودع التنبيهات
/// 
/// **ملاحظة مهمة:** هذا الملف يحتوي على 3 مسؤوليات:
/// 1. إدارة التنبيهات (Alerts Management)
/// 2. إدارة جهات الاتصال (Contacts Management)  
/// 3. إدارة الإعدادات (Alert Config Management)
/// 
/// **سبب الدمج:** تاريخياً، تم دمج هذه المسؤوليات في repository واحد
/// 
/// **خطة مستقبلية:** تقسيم إلى 3 repositories منفصلة:
/// - `AlertsOnlyRepository` - للتنبيهات فقط
/// - `ContactsOnlyRepository` - لجهات الاتصال فقط
/// - `AlertConfigRepository` - للإعدادات فقط
/// 
/// **التنظيم الحالي:** الملف منظم في أقسام واضحة مع تعليقات
/// 
/// **Features:**
/// - ✅ Offline-first architecture (Hive + Firebase)
/// - ✅ Automatic sync when online
/// - ✅ Comprehensive logging
/// - ✅ Error handling
class AlertsRepositoryImpl
    extends BaseOfflineRepository<AlertEntity, AlertModel>
    implements AlertsRepository {

  final FirebaseFirestore _firestore;
  late final AlertsRemoteDataSource _remoteDataSource;

  // استخدام services من الـ singletons مباشرة
  final HiveService _hive = HiveService.instance;
  final ConnectivityService _connectivity = ConnectivityService.instance;
  final FCMService _fcm = FCMService.instance;

  AlertsRepositoryImpl({
    required FirebaseFirestore firestore,
    AlertsRemoteDataSource? remoteDataSource,
  }) : _firestore = firestore {
    _remoteDataSource = remoteDataSource ?? AlertsRemoteDataSourceImpl(firebaseFirestore: firestore);
  }

  // ==================== BaseOfflineRepository Implementation ====================

  @override
  String get boxName => 'alerts';

  @override
  String get collectionName => 'alerts';

  @override
  AlertModel toModel(AlertEntity entity) => AlertModel.fromEntity(entity);

  @override
  AlertEntity toEntity(AlertModel model) => model.toEntity();

  @override
  Map<String, dynamic> toJson(AlertModel model) => model.toJson();

  @override
  AlertModel fromJson(Map<String, dynamic> json) => AlertModel.fromJson(json);

  @override
  String getId(AlertEntity entity) => entity.id;

  @override
  Future<Either<Failure, AlertEntity?>> fetchFromServer(String id) async {
    try {
      // ⚠️ TODO: يجب معرفة userId لجلب من المسار الصحيح
      // حاليًا نبحث في collection عام (legacy)
      final doc = await _firestore.collection('alerts').doc(id).get();

      if (!doc.exists) return const Right(null);

      final model = AlertModel.fromJson(doc.data()!);
      await saveLocal(model.toEntity());

      return Right(model.toEntity());
    } catch (e, stackTrace) {
      AppLogger.error('[AlertsRepository] فشل جلب التنبيه', e, stackTrace);
      return Left(ServerFailure('فشل جلب التنبيه: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<AlertEntity>>> fetchAllFromServer() async {
    try {
      final snapshot = await _firestore.collection('alerts').get();

      final entities = snapshot.docs
          .map((doc) => AlertModel.fromJson(doc.data()).toEntity())
          .toList();

      await saveAllLocal(entities);

      return Right(entities);
    } catch (e, stackTrace) {
      AppLogger.error('[AlertsRepository] فشل جلب التنبيهات', e, stackTrace);
      return Left(ServerFailure('فشل جلب التنبيهات: ${e.toString()}'));
    }
  }

  // ==================== Alert Management ====================

  @override
  Future<Either<Failure, AlertEntity>> triggerAlert({
    required String userId,
    required AlertType type,
    required String title,
    required String message,
    AlertSeverity? severity,
    String? tripId,
    Location? location,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      AppLogger.info('[AlertsRepository] إطلاق تنبيه: $title');

      final alert = AlertEntity(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: userId,
        type: type,
        title: title,
        message: message,
        severity: severity ?? AlertSeverity.medium,
        status: AlertStatus.triggered,
        triggeredAt: DateTime.now(),
        tripId: tripId,
        location: location,
        metadata: metadata,
      );

      // ✅ حفظ محليًا
      await saveLocal(alert);

      // ✅ حفظ في Firestore في المسار الصحيح
      if (_connectivity.isConnected) {
        try {
          final alertData = AlertModel.fromEntity(alert).toJson();

          await _firestore
              .collection('users')
              .doc(userId)
              .collection('alerts')
              .doc(alert.id)
              .set(alertData);

          AppLogger.success('[AlertsRepository] تم حفظ التنبيه في Firestore');
          AppLogger.info('[AlertsRepository] Cloud Function ستتولى إرسال الإشعارات');
        } catch (e) {
          AppLogger.error('[AlertsRepository] فشل حفظ التنبيه في Firestore', e);
          // نستمر - التنبيه محفوظ محليًا وسيتم مزامنته لاحقًا
        }
      }

      return Right(alert);
    } catch (e, stackTrace) {
      AppLogger.error('[AlertsRepository] فشل إطلاق التنبيه', e, stackTrace);
      return Left(ServerFailure('فشل إطلاق التنبيه: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, AlertEntity>> acknowledgeAlert({
    required String alertId,
    required String userId,
  }) async {
    try {
      final alertResult = await get(alertId);

      return alertResult.fold(
            (failure) => Left(failure),
            (alert) async {
          if (alert == null) {
            return const Left(NotFoundFailure('التنبيه غير موجود'));
          }

          final updatedAlert = alert.copyWith(
            status: AlertStatus.acknowledged,
            acknowledgedAt: DateTime.now(),
            acknowledgedBy: userId,
          );

          return update(updatedAlert);
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('[AlertsRepository] فشل الإقرار بالتنبيه', e, stackTrace);
      return Left(ServerFailure('فشل الإقرار: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, AlertEntity>> resolveAlert({
    required String alertId,
    String? note,
  }) async {
    try {
      final alertResult = await get(alertId);

      return alertResult.fold(
            (failure) => Left(failure),
            (alert) async {
          if (alert == null) {
            return const Left(NotFoundFailure('التنبيه غير موجود'));
          }

          final updatedAlert = alert.copyWith(
            status: AlertStatus.resolved,
            resolvedAt: DateTime.now(),
            metadata: {
              ...?alert.metadata,
              if (note != null) 'resolution_note': note,
            },
          );

          return update(updatedAlert);
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('[AlertsRepository] فشل حل التنبيه', e, stackTrace);
      return Left(ServerFailure('فشل الحل: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, AlertEntity>> escalateAlert({
    required String alertId,
    AlertSeverity? newSeverity,
  }) async {
    try {
      final alertResult = await get(alertId);

      return alertResult.fold(
            (failure) => Left(failure),
            (alert) async {
          if (alert == null) {
            return const Left(NotFoundFailure('التنبيه غير موجود'));
          }

          final updatedAlert = alert.copyWith(
            severity: newSeverity ?? AlertSeverity.critical,
            status: AlertStatus.escalated,
            isEscalated: true,
            escalationLevel: alert.escalationLevel + 1,
          );

          return update(updatedAlert);
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('[AlertsRepository] فشل تصعيد التنبيه', e, stackTrace);
      return Left(ServerFailure('فشل التصعيد: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, AlertEntity>> ignoreAlert(String alertId) async {
    try {
      final alertResult = await get(alertId);

      return alertResult.fold(
            (failure) => Left(failure),
            (alert) async {
          if (alert == null) {
            return const Left(NotFoundFailure('التنبيه غير موجود'));
          }

          final updatedAlert = alert.copyWith(
            status: AlertStatus.ignored,
          );

          return update(updatedAlert);
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('[AlertsRepository] فشل تجاهل التنبيه', e, stackTrace);
      return Left(ServerFailure('فشل التجاهل: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, AlertEntity>> sendSOS({
    required String userId,
    required Location location,
    String? message,
  }) async {
    try {
      AppLogger.start('[AlertsRepository] إرسال SOS فوري');

      // 1. إنشاء Alert
      final alert = AlertEntity(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: userId,
        type: AlertType.sos,
        title: 'إشارة استغاثة SOS',
        message: message ?? 'تم إرسال إشارة استغاثة',
        severity: AlertSeverity.critical,
        status: AlertStatus.triggered,
        triggeredAt: DateTime.now(),
        location: location,
        metadata: const {'is_sos': true},
      );

      // 2. حفظ محليًا
      await saveLocal(alert);

      // 3. استدعاء Cloud Function للإرسال الفوري
      if (_connectivity.isConnected) {
        try {
          AppLogger.info('[AlertsRepository] استدعاء Cloud Function للـ SOS');

          final result = await _fcm.sendSOSAlert(
            title: alert.title,
            message: alert.message,
            location: {
              'latitude': location.latitude,
              'longitude': location.longitude,
              'timestamp': location.timestamp.toIso8601String(),
            },
          );

          if (result['success'] == true) {
            AppLogger.success(
              '[AlertsRepository] تم إرسال SOS: ${result['notificationsSent']} إشعار',
            );
          } else {
            AppLogger.error(
              '[AlertsRepository] فشل إرسال SOS',
              result['error'] ?? 'Unknown error',
            );
          }

          // 4. حفظ في Firestore أيضًا (للسجل)
          final alertData = AlertModel.fromEntity(alert).toJson();
          await _firestore
              .collection('users')
              .doc(userId)
              .collection('alerts')
              .doc(alert.id)
              .set(alertData);

        } catch (e) {
          AppLogger.error('[AlertsRepository] خطأ في إرسال SOS', e);
          // نستمر - التنبيه محفوظ محليًا
        }
      } else {
        AppLogger.warning('[AlertsRepository] لا يوجد اتصال - SOS محفوظ محليًا فقط');
      }

      return Right(alert);
    } catch (e, stackTrace) {
      AppLogger.error('[AlertsRepository] فشل إرسال SOS', e, stackTrace);
      return Left(ServerFailure('فشل إرسال SOS: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<AlertEntity>>> getActiveAlerts(String userId) async {
    try {
      final allResult = await getAllLocal();

      return allResult.fold(
        (failure) async {
          // فشل المحلي، جرب السيرفر
          if (!_connectivity.isConnected) {
            return Left(failure);
          }
          
          final serverResult = await _fetchUserAlertsFromServer(userId);
          return serverResult.fold(
            (failure) => Left(failure),
            (alerts) {
              final active = alerts
                  .where((alert) => alert.status == AlertStatus.triggered)
                  .toList();
              return Right(active);
            },
          );
        },
        (alerts) async {
          final active = alerts
              .where((alert) =>
          alert.userId == userId &&
              alert.status == AlertStatus.triggered)
              .toList();

          // ✅ إذا كان المخزن فارغاً وكان متصلاً، جلب من السيرفر
          if (active.isEmpty && _connectivity.isConnected) {
            AppLogger.info('[AlertsRepository] المخزن المحلي فارغ - جلب من السيرفر');
            final serverResult = await _fetchUserAlertsFromServer(userId);
            return serverResult.fold(
              (failure) => Right(active), // إرجاع القائمة الفارغة
              (alerts) {
                final serverActive = alerts
                    .where((alert) => alert.status == AlertStatus.triggered)
                    .toList();
                return Right(serverActive);
              },
            );
          }

          return Right(active);
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('[AlertsRepository] فشل جلب التنبيهات النشطة', e, stackTrace);
      return Left(ServerFailure('فشل الجلب: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<AlertEntity>>> getAlertHistory({
    required String userId,
    DateTime? startDate,
    DateTime? endDate,
    AlertType? type,
    AlertSeverity? severity,
    int? limit,
  }) async {
    try {
      final allResult = await getAllLocal();

      return allResult.fold(
            (failure) => Left(failure),
            (alerts) {
          var filtered = alerts.where((alert) => alert.userId == userId);

          if (startDate != null) {
            filtered = filtered.where((a) => a.triggeredAt.isAfter(startDate));
          }

          if (endDate != null) {
            filtered = filtered.where((a) => a.triggeredAt.isBefore(endDate));
          }

          if (type != null) {
            filtered = filtered.where((a) => a.type == type);
          }

          if (severity != null) {
            filtered = filtered.where((a) => a.severity == severity);
          }

          var result = filtered.toList()
            ..sort((a, b) => b.triggeredAt.compareTo(a.triggeredAt));

          if (limit != null && result.length > limit) {
            result = result.take(limit).toList();
          }

          return Right(result);
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('[AlertsRepository] فشل جلب سجل التنبيهات', e, stackTrace);
      return Left(ServerFailure('فشل الجلب: ${e.toString()}'));
    }
  }

  /// جلب تنبيهات المستخدم من السيرفر (من كلا المسارين)
  Future<Either<Failure, List<AlertEntity>>> _fetchUserAlertsFromServer(String userId) async {
    try {
      AppLogger.info('[AlertsRepository] جلب تنبيهات $userId من Firestore');
      
      final allEntities = <AlertEntity>[];
      
      // 1. جلب من subcollection: /users/{userId}/alerts
      try {
        final subcollectionSnapshot = await _firestore
            .collection('users')
            .doc(userId)
            .collection('alerts')
            .get();
        
        if (subcollectionSnapshot.docs.isNotEmpty) {
          AppLogger.info('[AlertsRepository] وُجد ${subcollectionSnapshot.docs.length} تنبيه في subcollection');
          
          final subcollectionModels = subcollectionSnapshot.docs
              .map((doc) => AlertModel.fromJson(doc.data()))
              .toList();
          
          allEntities.addAll(subcollectionModels.map((m) => m.toEntity()));
        }
      } catch (e) {
        AppLogger.warning('[AlertsRepository] فشل جلب من subcollection: $e');
      }
      
      // 2. جلب من legacy collection: /alerts
      try {
        final legacySnapshot = await _firestore
            .collection('alerts')
            .where('userId', isEqualTo: userId)
            .get();
        
        if (legacySnapshot.docs.isNotEmpty) {
          AppLogger.info('[AlertsRepository] وُجد ${legacySnapshot.docs.length} تنبيه في legacy collection');
          
          final legacyModels = legacySnapshot.docs
              .map((doc) => AlertModel.fromJson(doc.data()))
              .toList();
          
          // تجنب التكرار
          for (final entity in legacyModels.map((m) => m.toEntity())) {
            if (!allEntities.any((e) => e.id == entity.id)) {
              allEntities.add(entity);
            }
          }
        }
      } catch (e) {
        AppLogger.warning('[AlertsRepository] فشل جلب من legacy collection: $e');
      }
      
      if (allEntities.isEmpty) {
        AppLogger.info('[AlertsRepository] لا توجد تنبيهات للمستخدم $userId');
        return const Right([]);
      }
      
      // حفظ جميع التنبيهات محلياً
      await saveAllLocal(allEntities);
      
      AppLogger.success('[AlertsRepository] تم جلب ${allEntities.length} تنبيه من السيرفر');
      return Right(allEntities);
    } catch (e, stackTrace) {
      AppLogger.error('[AlertsRepository] فشل جلب من السيرفر', e, stackTrace);
      return Left(ServerFailure('فشل الجلب من السيرفر: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, AlertEntity>> getAlertById(String alertId) async {
    final result = await get(alertId);
    return result.fold(
          (failure) => Left(failure),
          (alert) => alert != null
          ? Right(alert)
          : const Left(NotFoundFailure('التنبيه غير موجود')),
    );
  }

  @override
  Future<Either<Failure, void>> deleteAlert(String alertId) async {
    return delete(alertId);
  }

  // ==================== Contact Management ====================

  @override
  Future<Either<Failure, ContactEntity>> addContact(ContactEntity contact) async {
    try {
      final model = ContactModel.fromEntity(contact);
      await _hive.put<ContactModel>('contacts', contact.id, model);

      // مزامنة مع السيرفر في المسار الصحيح
      if (_connectivity.isConnected) {
        await _firestore
            .collection('users')
            .doc(contact.userId)
            .collection('contacts')
            .doc(contact.id)
            .set(model.toJson());
      }

      return Right(contact);
    } catch (e, stackTrace) {
      AppLogger.error('[AlertsRepository] فشل إضافة جهة الاتصال', e, stackTrace);
      return Left(ServerFailure('فشل الإضافة: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, ContactEntity>> updateContact(ContactEntity contact) async {
    try {
      final model = ContactModel.fromEntity(contact);
      await _hive.put<ContactModel>('contacts', contact.id, model);

      // مزامنة مع السيرفر
      if (_connectivity.isConnected) {
        await _firestore
            .collection('users')
            .doc(contact.userId)
            .collection('contacts')
            .doc(contact.id)
            .update(model.toJson());
      }

      return Right(contact);
    } catch (e, stackTrace) {
      AppLogger.error('[AlertsRepository] فشل تحديث جهة الاتصال', e, stackTrace);
      return Left(ServerFailure('فشل التحديث: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteContact(String contactId) async {
    try {
      await _hive.delete('contacts', contactId);

      // مزامنة مع السيرفر
      // ⚠️ TODO: نحتاج userId هنا

      return const Right(null);
    } catch (e, stackTrace) {
      AppLogger.error('[AlertsRepository] فشل حذف جهة الاتصال', e, stackTrace);
      return Left(ServerFailure('فشل الحذف: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<ContactEntity>>> getContacts(String userId) async {
    try {
      // ✅ 1. جلب من Hive المحلي أولاً
      final contacts = _hive.getAll<ContactModel>('contacts');
      final userContacts = contacts
          .where((c) => c.userId == userId)
          .map((m) => m.toEntity())
          .toList();

      AppLogger.info('[AlertsRepository] جهات الاتصال المحلية: ${userContacts.length}');

      // ✅ 2. إذا كانت فارغة وكان متصلاً، جلب من السيرفر
      if (userContacts.isEmpty && _connectivity.isConnected) {
        AppLogger.info('[AlertsRepository] جلب جهات الاتصال من السيرفر');
        try {
          final remoteModels = await _remoteDataSource.getContacts(userId);
          for (final model in remoteModels) {
            await _hive.put<ContactModel>('contacts', model.id, model);
          }
          final entities = remoteModels.map((m) => m.toEntity()).toList();
          AppLogger.success('[AlertsRepository] تم جلب ${entities.length} جهة اتصال من السيرفر');
          return Right(entities);
        } catch (e) {
          AppLogger.warning('[AlertsRepository] فشل جلب جهات الاتصال من السيرفر: $e');
        }
      }

      // ✅ 3. تحديث في الخلفية إذا كانت موجودة محلياً
      if (userContacts.isNotEmpty && _connectivity.isConnected) {
        Future.microtask(() async { // ignore: unawaited_futures
          try {
            final remoteModels = await _remoteDataSource.getContacts(userId);
            for (final model in remoteModels) {
              await _hive.put<ContactModel>('contacts', model.id, model);
            }
          } catch (e) {
            AppLogger.warning('[AlertsRepository] فشل تحديث جهات الاتصال في الخلفية: \$e');
          }
        });
      }

      return Right(userContacts);
    } catch (e, stackTrace) {
      AppLogger.error('[AlertsRepository] فشل جلب جهات الاتصال', e, stackTrace);
      return Left(CacheFailure('فشل الجلب: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<ContactEntity>>> getEmergencyContacts(String userId) async {
    try {
      final contacts = _hive.getAll<ContactModel>('contacts');

      final emergencyContacts = contacts
          .where((c) => c.userId == userId && c.type == ContactType.emergency)
          .map((m) => m.toEntity())
          .toList();

      return Right(emergencyContacts);
    } catch (e, stackTrace) {
      AppLogger.error('[AlertsRepository] فشل جلب جهات طوارئ', e, stackTrace);
      return Left(CacheFailure('فشل الجلب: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, ContactEntity>> setPrimaryContact({
    required String contactId,
    required String userId,
  }) async {
    try {
      // إزالة primary من جميع جهات الاتصال الأخرى
      final contacts = _hive.getAll<ContactModel>('contacts');
      for (final contact in contacts) {
        if (contact.userId == userId && contact.isPrimary) {
          final updated = contact.copyWith(isPrimary: false);
          await _hive.put<ContactModel>('contacts', contact.id, updated);
        }
      }

      // تعيين الجهة الجديدة كأساسية
      final contact = _hive.get<ContactModel>('contacts', contactId);
      if (contact == null) {
        return const Left(NotFoundFailure('جهة الاتصال غير موجودة'));
      }

      final updated = contact.copyWith(isPrimary: true);
      await _hive.put<ContactModel>('contacts', contactId, updated);

      return Right(updated);
    } catch (e, stackTrace) {
      AppLogger.error('[AlertsRepository] فشل تعيين جهة أساسية', e, stackTrace);
      return Left(ServerFailure('فشل التعيين: ${e.toString()}'));
    }
  }

  // ==================== Alert Config Management ====================

  @override
  Future<Either<Failure, AlertConfigEntity>> getAlertConfig(String userId) async {
    try {
      // محاولة الحصول من Hive أولاً
      final config = _hive.get<AlertConfigModel>('alert_configs', userId);

      if (config != null) {
        AppLogger.info('[AlertsRepository] تم جلب الإعدادات من التخزين المحلي');
        return Right(config.toEntity());
      }

      // جلب من السيرفر إذا كان متصل
      if (_connectivity.isConnected) {
        AppLogger.info('[AlertsRepository] محاولة جلب الإعدادات من Firebase');
        final doc = await _firestore
            .collection('users')
            .doc(userId)
            .collection('alert_configs')
            .doc('config')
            .get();

        if (doc.exists) {
          final model = AlertConfigModel.fromJson(doc.data()!);
          await _hive.put('alert_configs', userId, model);
          AppLogger.success('[AlertsRepository] تم جلب الإعدادات من Firebase وحفظها محلياً');
          return Right(model.toEntity());
        }
      }

      // إذا لم توجد إعدادات، إنشاء إعدادات افتراضية
      AppLogger.info('[AlertsRepository] لم توجد إعدادات، جاري إنشاء إعدادات افتراضية للمستخدم: $userId');
      
      final defaultConfig = AlertConfigModel.createDefault(userId);
      
      // حفظ الإعدادات الافتراضية محلياً
      await _hive.put('alert_configs', userId, defaultConfig);
      AppLogger.info('[AlertsRepository] تم حفظ الإعدادات الافتراضية محلياً');
      
      // مزامنة مع Firebase إذا كان متصل
      if (_connectivity.isConnected) {
        try {
          await _firestore
              .collection('users')
              .doc(userId)
              .collection('alert_configs')
              .doc('config')
              .set(defaultConfig.toJson());
          AppLogger.success('[AlertsRepository] تم مزامنة الإعدادات الافتراضية مع Firebase');
        } catch (e) {
          AppLogger.warning('[AlertsRepository] فشلت المزامنة مع Firebase: $e (ستتم لاحقاً)');
        }
      }
      
      return Right(defaultConfig.toEntity());
    } catch (e, stackTrace) {
      AppLogger.error('[AlertsRepository] فشل جلب الإعدادات', e, stackTrace);
      return Left(ServerFailure('فشل الجلب: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, AlertConfigEntity>> updateAlertConfig(AlertConfigEntity config) async {
    try {
      final model = AlertConfigModel.fromEntity(config);
      await _hive.put('alert_configs', config.userId, model);

      // مزامنة مع السيرفر
      if (_connectivity.isConnected) {
        await _firestore
            .collection('users')
            .doc(config.userId)
            .collection('alert_configs')
            .doc('config')
            .set(model.toJson());
      }

      return Right(config);
    } catch (e, stackTrace) {
      AppLogger.error('[AlertsRepository] فشل تحديث الإعدادات', e, stackTrace);
      return Left(ServerFailure('فشل التحديث: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, AlertConfigEntity>> updateAlertTypeConfig({
    required String userId,
    required AlertTypeConfig typeConfig,
  }) async {
    try {
      final configResult = await getAlertConfig(userId);

      return configResult.fold(
            (failure) => Left(failure),
            (config) async {
          final updatedConfigs = List<AlertTypeConfig>.from(config.typeConfigs);
          final index = updatedConfigs.indexWhere((c) => c.type == typeConfig.type);

          if (index >= 0) {
            updatedConfigs[index] = typeConfig;
          } else {
            updatedConfigs.add(typeConfig);
          }

          final updatedConfig = config.copyWith(
            typeConfigs: updatedConfigs,
          );

          return updateAlertConfig(updatedConfig);
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('[AlertsRepository] فشل تحديث إعدادات النوع', e, stackTrace);
      return Left(ServerFailure('فشل التحديث: ${e.toString()}'));
    }
  }
}