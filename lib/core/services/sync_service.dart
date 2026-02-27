import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:psga_app/core/constants/app_strings.dart';
import 'package:psga_app/core/services/connectivity_service.dart';
import 'package:psga_app/core/storage/hive_service.dart';
import 'package:psga_app/core/utils/logger.dart';

/// حالة المزامنة
enum SyncStatus {
  idle,      // خامل
  syncing,   // جاري المزامنة
  success,   // نجحت
  error,     // فشلت
  pending,   // معلقة
}

/// عملية مزامنة
class SyncOperation {
  final String id;
  final String entity;    // 'users', 'routes', etc.
  final String operation; // 'create', 'update', 'delete'
  final Map<String, dynamic> data;
  final DateTime timestamp;
  int retryCount;

  SyncOperation({
    required this.id,
    required this.entity,
    required this.operation,
    required this.data,
    required this.timestamp,
    this.retryCount = 0,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'entity': entity,
    'operation': operation,
    'data': data,
    'timestamp': timestamp.toIso8601String(),
    'retryCount': retryCount,
  };

  factory SyncOperation.fromJson(Map<String, dynamic> json) => SyncOperation(
    id: json['id'],
    entity: json['entity'],
    operation: json['operation'],
    data: Map<String, dynamic>.from(json['data']),
    timestamp: DateTime.parse(json['timestamp']),
    retryCount: json['retryCount'] ?? 0,
  );
}

/// خدمة المزامنة
class SyncService {
  static SyncService? _instance;
  static SyncService get instance => _instance ??= SyncService._();

  SyncService._();

  final HiveService _hiveService = HiveService.instance;
  final ConnectivityService _connectivityService = ConnectivityService.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final StreamController<SyncStatus> _statusController = StreamController<SyncStatus>.broadcast();
  SyncStatus _currentStatus = SyncStatus.idle;

  bool _isSyncing = false;
  Timer? _retryTimer;

  // ==================== Initialization ====================

  Future<void> init() async {
    try {
      AppLogger.info('[SyncService] جاري تهيئة خدمة المزامنة');

      // الاستماع لتغييرات الاتصال
      _connectivityService.onConnected(() {
        AppLogger.info('[SyncService] اتصل بالإنترنت - بدء المزامنة');
        syncAll();
      });

      AppLogger.success('[SyncService] تم تهيئة خدمة المزامنة');
    } catch (e) {
      AppLogger.error('[SyncService] فشل تهيئة خدمة المزامنة', e);
    }
  }

  // ==================== Queue Management ====================

  /// إضافة عملية للطابور
  Future<void> addToQueue(SyncOperation operation) async {
    try {
      AppLogger.info('[SyncService] إضافة عملية للطابور: ${operation.entity}/${operation.operation}');

      final queue = _getSyncQueue();
      queue[operation.id] = jsonEncode(operation.toJson());

      await _hiveService.put(AppStrings.syncQueueBox, 'queue', queue);

      AppLogger.success('[SyncService] تم إضافة العملية للطابور');

      // محاولة المزامنة إذا كان هناك اتصال
      if (_connectivityService.isConnected && !_isSyncing) {
        unawaited(syncAll());
      }
    } catch (e) {
      AppLogger.error('[SyncService] فشل إضافة العملية للطابور', e);
    }
  }

  /// الحصول على طابور المزامنة
  Map<String, dynamic> _getSyncQueue() {
    try {
      final queue = _hiveService.get<Map>(AppStrings.syncQueueBox, 'queue');
      return Map<String, dynamic>.from(queue ?? {});
    } catch (e) {
      AppLogger.error('[SyncService] فشل الحصول على الطابور', e);
      return {};
    }
  }

  /// عدد العمليات المعلقة
  int getPendingCount() {
    return _getSyncQueue().length;
  }

  // ==================== Sync Operations ====================

  /// مزامنة جميع العمليات المعلقة
  Future<void> syncAll() async {
    if (_isSyncing) {
      AppLogger.warning('[SyncService] المزامنة جارية بالفعل');
      return;
    }

    if (!_connectivityService.isConnected) {
      AppLogger.warning('[SyncService] لا يوجد اتصال - تأجيل المزامنة');
      _setStatus(SyncStatus.pending);
      return;
    }

    try {
      _isSyncing = true;
      _setStatus(SyncStatus.syncing);

      AppLogger.info('[SyncService] بدء مزامنة جميع العمليات');

      final queue = _getSyncQueue();

      if (queue.isEmpty) {
        AppLogger.info('[SyncService] لا توجد عمليات معلقة');
        _setStatus(SyncStatus.idle);
        _isSyncing = false;
        return;
      }

      AppLogger.info('[SyncService] ${queue.length} عملية معلقة');

      final List<String> successfulIds = [];
      final List<String> failedIds = [];

      for (final entry in queue.entries) {
        try {
          final operation = SyncOperation.fromJson(jsonDecode(entry.value));

          final success = await _syncOperation(operation);

          if (success) {
            successfulIds.add(entry.key);
          } else {
            failedIds.add(entry.key);
          }

          // توقف قصير بين العمليات
          await Future.delayed(const Duration(milliseconds: 100));
        } catch (e) {
          AppLogger.error('[SyncService] خطأ في معالجة عملية', e);
          failedIds.add(entry.key);
        }
      }

      // حذف العمليات الناجحة من الطابور
      if (successfulIds.isNotEmpty) {
        await _removeFromQueue(successfulIds);
        AppLogger.success('[SyncService] تمت مزامنة ${successfulIds.length} عملية');
      }

      if (failedIds.isNotEmpty) {
        AppLogger.warning('[SyncService] فشلت ${failedIds.length} عملية');
        _setStatus(SyncStatus.error);
        _scheduleRetry();
      } else {
        _setStatus(SyncStatus.success);
      }

    } catch (e, stackTrace) {
      AppLogger.error('[SyncService] خطأ في المزامنة', e, stackTrace);
      _setStatus(SyncStatus.error);
      _scheduleRetry();
    } finally {
      _isSyncing = false;
    }
  }

  /// مزامنة عملية واحدة
  Future<bool> _syncOperation(SyncOperation operation) async {
    try {
      AppLogger.info('[SyncService] مزامنة ${operation.entity}/${operation.operation}');

      switch (operation.entity) {
        case 'users':
          return await _syncUserOperation(operation);
        case 'routes':
          return await _syncRouteOperation(operation);
        case 'trips':
          return await _syncTripOperation(operation);
        case 'alerts':
          return await _syncAlertOperation(operation);
        case 'contacts':
          return await _syncContactOperation(operation);
        default:
          AppLogger.warning('[SyncService] نوع غير معروف: ${operation.entity}');
          return false;
      }
    } catch (e) {
      AppLogger.error('[SyncService] فشلت المزامنة لـ ${operation.entity}', e);

      // زيادة عداد المحاولات
      operation.retryCount++;

      // إذا فشلت أكثر من 5 مرات، نتجاهلها
      if (operation.retryCount > 5) {
        AppLogger.error('[SyncService] تم تجاوز الحد الأقصى للمحاولات');
        return true; // نعتبرها ناجحة لحذفها من الطابور
      }

      return false;
    }
  }

  /// مزامنة عملية مستخدم
  Future<bool> _syncUserOperation(SyncOperation operation) async {
    try {
      final docRef = _firestore.collection('users').doc(operation.data['id']);

      switch (operation.operation) {
        case 'create':
        case 'update':
          await docRef.set(operation.data, SetOptions(merge: true));
          break;
        case 'delete':
          await docRef.delete();
          break;
        default:
          return false;
      }

      AppLogger.success('[SyncService] تمت مزامنة المستخدم');
      return true;
    } catch (e) {
      AppLogger.error('[SyncService] فشلت مزامنة المستخدم', e);
      return false;
    }
  }

  /// مزامنة عملية مسار
  Future<bool> _syncRouteOperation(SyncOperation operation) async {
    try {
      // ✅ معالجة userId (قد يكون null في عمليات الحذف القديمة)
      final userId = operation.data['userId'] as String?;
      final routeId = operation.data['id'] as String;
      
      if (userId == null && operation.operation != 'delete') {
        AppLogger.error('[SyncService] userId مفقود للعملية: ${operation.operation}');
        return false;
      }

      switch (operation.operation) {
        case 'create':
        case 'update':
          if (userId == null) {
            AppLogger.error('[SyncService] userId مطلوب لـ create/update');
            return false;
          }
          
          // ✅ حفظ في subcollection: /users/{userId}/routes/{routeId}
          final subcollectionRef = _firestore
              .collection('users')
              .doc(userId)
              .collection('routes')
              .doc(routeId);

          // ✅ حفظ في legacy collection أيضاً: /routes/{routeId}
          final legacyRef = _firestore
              .collection('routes')
              .doc(routeId);
          
          // حفظ في كلا المسارين للتوافق
          await Future.wait([
            subcollectionRef.set(operation.data, SetOptions(merge: true)),
            legacyRef.set(operation.data, SetOptions(merge: true)),
          ]);
          
          AppLogger.success('[SyncService] تمت مزامنة المسار: ${operation.data['name']} (subcollection + legacy)');
          break;
          
        case 'delete':
          // ✅ حذف مع أو بدون userId
          final deleteFutures = <Future>[];
          
          // حذف من legacy collection دائماً
          deleteFutures.add(
            _firestore.collection('routes').doc(routeId).delete()
          );
          
          // حذف من subcollection إذا كان userId موجود
          if (userId != null) {
            deleteFutures.add(
              _firestore
                  .collection('users')
                  .doc(userId)
                  .collection('routes')
                  .doc(routeId)
                  .delete()
            );
            AppLogger.info('[SyncService] حذف من subcollection + legacy');
          } else {
            AppLogger.warning('[SyncService] حذف من legacy فقط (userId مفقود)');
          }
          
          await Future.wait(deleteFutures);
          AppLogger.success('[SyncService] تم حذف المسار من السيرفر');
          break;
          
        default:
          AppLogger.warning('[SyncService] عملية غير معروفة: ${operation.operation}');
          return false;
      }

      return true;
    } catch (e, stackTrace) {
      AppLogger.error('[SyncService] فشلت مزامنة المسار', e, stackTrace);
      return false;
    }
  }

  /// مزامنة عملية رحلة
  Future<bool> _syncTripOperation(SyncOperation operation) async {
    try {
      final userId = operation.data['userId'] as String;
      final tripId = operation.data['id'] as String;
      
      // ✅ حفظ في subcollection: /users/{userId}/trips/{tripId}
      final subcollectionRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('trips')
          .doc(tripId);
      
      // ✅ حفظ في legacy collection: /trips/{tripId}
      final legacyRef = _firestore
          .collection('trips')
          .doc(tripId);

      switch (operation.operation) {
        case 'create':
        case 'update':
        // حفظ بيانات الرحلة الأساسية
          final tripData = Map<String, dynamic>.from(operation.data);

          // إزالة location history من البيانات الأساسية
          final locationHistory = tripData.remove('locationHistory') as List?;

          // حفظ بيانات الرحلة في كلا المسارين
          await Future.wait([
            subcollectionRef.set(tripData, SetOptions(merge: true)),
            legacyRef.set(tripData, SetOptions(merge: true)),
          ]);

          // مزامنة Location History إذا وجد (في subcollection فقط)
          if (locationHistory != null && locationHistory.isNotEmpty) {
            final batch = _firestore.batch();
            final locationsRef = subcollectionRef.collection('locations');

            for (final location in locationHistory) {
              if (location is Map<String, dynamic>) {
                final locId = location['timestamp']?.toString() ??
                    DateTime.now().millisecondsSinceEpoch.toString();
                final locRef = locationsRef.doc(locId);
                batch.set(locRef, location, SetOptions(merge: true));
              }
            }

            await batch.commit();
            AppLogger.info('[SyncService] تمت مزامنة ${locationHistory.length} موقع');
          }

          AppLogger.success('[SyncService] تمت مزامنة الرحلة: $tripId (subcollection + legacy)');
          break;

        case 'delete':
        // حذف Location History أولاً (من subcollection فقط)
          final locationsSnapshot = await subcollectionRef.collection('locations').get();

          if (locationsSnapshot.docs.isNotEmpty) {
            final batch = _firestore.batch();
            for (final doc in locationsSnapshot.docs) {
              batch.delete(doc.reference);
            }
            await batch.commit();
            AppLogger.info('[SyncService] تم حذف ${locationsSnapshot.docs.length} موقع');
          }

          // ثم حذف الرحلة نفسها من كلا المسارين
          await Future.wait([
            subcollectionRef.delete(),
            legacyRef.delete(),
          ]);
          
          AppLogger.success('[SyncService] تم حذف الرحلة من السيرفر (subcollection + legacy)');
          break;

        default:
          AppLogger.warning('[SyncService] عملية غير معروفة: ${operation.operation}');
          return false;
      }

      return true;
    } catch (e, stackTrace) {
      AppLogger.error('[SyncService] فشلت مزامنة الرحلة', e, stackTrace);
      return false;
    }
  }

  /// مزامنة عملية تنبيه
  ///
  /// ملاحظة مهمة: عند حفظ التنبيه في Firestore،
  /// Cloud Function ستكتشفه تلقائياً وترسل الإشعارات لجميع جهات الاتصال
  Future<bool> _syncAlertOperation(SyncOperation operation) async {
    try {
      final userId = operation.data['userId'] as String;
      final alertId = operation.data['id'] as String;
      
      // ✅ حفظ في subcollection: /users/{userId}/alerts/{alertId}
      final subcollectionRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('alerts')
          .doc(alertId);
      
      // ✅ حفظ في legacy collection: /alerts/{alertId}
      final legacyRef = _firestore
          .collection('alerts')
          .doc(alertId);

      switch (operation.operation) {
        case 'create':
        case 'update':
        // حفظ التنبيه في Firestore (كلا المسارين)
        // Cloud Function سترسل الإشعارات تلقائياً
          await Future.wait([
            subcollectionRef.set(operation.data, SetOptions(merge: true)),
            legacyRef.set(operation.data, SetOptions(merge: true)),
          ]);

          AppLogger.success('[SyncService] تمت مزامنة التنبيه: ${operation.data['title']} (subcollection + legacy)');
          AppLogger.info('[SyncService] Cloud Function ستتولى إرسال الإشعارات تلقائياً');
          break;

        case 'delete':
          // حذف من كلا المسارين
          await Future.wait([
            subcollectionRef.delete(),
            legacyRef.delete(),
          ]);
          
          AppLogger.success('[SyncService] تم حذف التنبيه من السيرفر (subcollection + legacy)');
          break;

        default:
          AppLogger.warning('[SyncService] عملية غير معروفة: ${operation.operation}');
          return false;
      }

      return true;
    } catch (e, stackTrace) {
      AppLogger.error('[SyncService] فشلت مزامنة التنبيه', e, stackTrace);
      return false;
    }
  }

  /// مزامنة عملية جهة اتصال
  Future<bool> _syncContactOperation(SyncOperation operation) async {
    try {
      // التعامل الآمن مع البيانات - قد تكون null
      final userId = operation.data['userId'] as String?;
      final contactId = operation.data['id'] as String?;
      
      // التحقق من وجود contactId على الأقل
      if (contactId == null || contactId.isEmpty) {
        AppLogger.error('[SyncService] contactId مفقود في عملية ${operation.operation}');
        return false;
      }
      
      switch (operation.operation) {
        case 'create':
        case 'update':
          // للإضافة والتحديث، نحتاج userId
          if (userId == null || userId.isEmpty) {
            AppLogger.error('[SyncService] userId مفقود في عملية ${operation.operation}');
            return false;
          }
          
          // ✅ حفظ في subcollection: /users/{userId}/contacts/{contactId}
          final subcollectionRef = _firestore
              .collection('users')
              .doc(userId)
              .collection('contacts')
              .doc(contactId);
          
          // ✅ حفظ في legacy collection: /contacts/{contactId}
          final legacyRef = _firestore
              .collection('contacts')
              .doc(contactId);

          // حفظ في كلا المسارين
          await Future.wait([
            subcollectionRef.set(operation.data, SetOptions(merge: true)),
            legacyRef.set(operation.data, SetOptions(merge: true)),
          ]);
          
          AppLogger.success('[SyncService] تمت مزامنة جهة الاتصال: ${operation.data['name']} (subcollection + legacy)');
          break;

        case 'delete':
          // للحذف، userId اختياري - نحذف من legacy على الأقل
          
          // ✅ حذف من legacy collection دائماً
          final legacyRef = _firestore
              .collection('contacts')
              .doc(contactId);
          
          final deleteTasks = <Future>[legacyRef.delete()];
          
          // ✅ إذا كان userId موجوداً، احذف من subcollection أيضاً
          if (userId != null && userId.isNotEmpty) {
            final subcollectionRef = _firestore
                .collection('users')
                .doc(userId)
                .collection('contacts')
                .doc(contactId);
            deleteTasks.add(subcollectionRef.delete());
          }
          
          // تنفيذ جميع عمليات الحذف
          await Future.wait(deleteTasks);
          
          if (userId != null && userId.isNotEmpty) {
            AppLogger.success('[SyncService] تم حذف جهة الاتصال: $contactId (subcollection + legacy)');
          } else {
            AppLogger.success('[SyncService] تم حذف جهة الاتصال: $contactId (legacy فقط)');
          }
          
          AppLogger.success('[SyncService] تم حذف جهة الاتصال من السيرفر (subcollection + legacy)');
          break;

        default:
          AppLogger.warning('[SyncService] عملية غير معروفة: ${operation.operation}');
          return false;
      }

      return true;
    } catch (e, stackTrace) {
      AppLogger.error('[SyncService] فشلت مزامنة جهة الاتصال', e, stackTrace);
      return false;
    }
  }

  /// حذف عمليات من الطابور
  Future<void> _removeFromQueue(List<String> ids) async {
    try {
      final queue = _getSyncQueue();
      for (final id in ids) {
        queue.remove(id);
      }
      await _hiveService.put(AppStrings.syncQueueBox, 'queue', queue);
    } catch (e) {
      AppLogger.error('[SyncService] فشل حذف من الطابور', e);
    }
  }

  /// جدولة إعادة المحاولة
  void _scheduleRetry() {
    _retryTimer?.cancel();

    // Exponential backoff: 10s, 30s, 60s, 120s, 300s
    const retryIntervals = [10, 30, 60, 120, 300];
    final retryIndex = (_getSyncQueue().length ~/ 5).clamp(0, retryIntervals.length - 1);
    final retryDelay = Duration(seconds: retryIntervals[retryIndex]);

    AppLogger.info('[SyncService] إعادة المحاولة بعد ${retryDelay.inSeconds} ثانية');

    _retryTimer = Timer(retryDelay, () {
      if (_connectivityService.isConnected) {
        syncAll();
      }
    });
  }

  // ==================== Status Management ====================

  void _setStatus(SyncStatus status) {
    _currentStatus = status;
    _statusController.add(status);
    AppLogger.info('[SyncService] حالة المزامنة: $status');
  }

  SyncStatus get currentStatus => _currentStatus;
  Stream<SyncStatus> get statusStream => _statusController.stream;

  // ==================== Cleanup ====================

  Future<void> dispose() async {
    _retryTimer?.cancel();
    await _statusController.close();
    AppLogger.info('[SyncService] تم إيقاف خدمة المزامنة');
  }

  // ==================== Utility ====================

  Map<String, dynamic> getInfo() {
    return {
      'currentStatus': _currentStatus.toString(),
      'isSyncing': _isSyncing,
      'pendingCount': getPendingCount(),
      'isConnected': _connectivityService.isConnected,
    };
  }
}