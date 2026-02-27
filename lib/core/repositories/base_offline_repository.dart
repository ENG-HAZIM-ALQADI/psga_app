import 'package:dartz/dartz.dart';
import 'package:psga_app/core/errors/failures.dart';
import 'package:psga_app/core/services/connectivity_service.dart';
import 'package:psga_app/core/services/sync_service.dart';
import 'package:psga_app/core/storage/hive_service.dart';
import 'package:psga_app/core/utils/logger.dart';

/// Base Repository للنمط Offline-First
/// 
/// يوفر الوظائف الأساسية:
/// - حفظ محلي أولاً
/// - إضافة للـ sync queue
/// - مزامنة مع السيرفر
/// - حل التعارضات
abstract class BaseOfflineRepository<TEntity, TModel> {
  /// اسم الـ Box في Hive
  String get boxName;
  
  /// اسم Collection في Firestore
  String get collectionName;
  
  /// Services (كـ getters - يمكن للـ subclasses الوصول لها)
  HiveService get hiveService => HiveService.instance;
  SyncService get syncService => SyncService.instance;
  ConnectivityService get connectivityService => ConnectivityService.instance;



  // ==================== Abstract Methods ====================
  
  /// تحويل Entity إلى Model
  TModel toModel(TEntity entity);
  
  /// تحويل Model إلى Entity
  TEntity toEntity(TModel model);
  
  /// تحويل Model إلى JSON
  Map<String, dynamic> toJson(TModel model);
  
  /// تحويل JSON إلى Model
  TModel fromJson(Map<String, dynamic> json);
  
  /// الحصول على ID من Entity
  String getId(TEntity entity);

  // ==================== Local Operations ====================

  /// حفظ محلياً
  Future<Either<Failure, void>> saveLocal(TEntity entity) async {
    try {
      final model = toModel(entity);
      final id = getId(entity);
      
      await hiveService.put<TModel>(boxName, id, model);
      AppLogger.info('[$boxName] تم حفظ $id محلياً');
      
      return const Right(null);
    } catch (e, stackTrace) {
      AppLogger.error('[$boxName] فشل الحفظ المحلي', e, stackTrace);
      return Left(CacheFailure('فشل الحفظ المحلي: ${e.toString()}'));
    }
  }

  /// الحصول من المخزن المحلي
  Future<Either<Failure, TEntity?>> getLocal(String id) async {
    try {
      final model = hiveService.get<TModel>(boxName, id);
      
      if (model == null) {
        AppLogger.info('[$boxName] لم يتم العثور على $id محلياً');
        return const Right(null);
      }
      
      final entity = toEntity(model);
      AppLogger.info('[$boxName] تم جلب $id محلياً');
      
      return Right(entity);
    } catch (e, stackTrace) {
      AppLogger.error('[$boxName] فشل الجلب المحلي', e, stackTrace);
      return Left(CacheFailure('فشل الجلب المحلي: ${e.toString()}'));
    }
  }

  /// الحصول على جميع العناصر المحلية
  Future<Either<Failure, List<TEntity>>> getAllLocal() async {
    try {
      final models = hiveService.getAll<TModel>(boxName);
      final entities = models.map((model) => toEntity(model)).toList();
      
      AppLogger.info('[$boxName] تم جلب ${entities.length} عنصر محلياً');
      
      return Right(entities);
    } catch (e, stackTrace) {
      AppLogger.error('[$boxName] فشل جلب جميع العناصر', e, stackTrace);
      return Left(CacheFailure('فشل الجلب: ${e.toString()}'));
    }
  }

  /// حذف محلياً
  Future<Either<Failure, void>> deleteLocal(String id) async {
    try {
      await hiveService.delete(boxName, id);
      AppLogger.info('[$boxName] تم حذف $id محلياً');
      
      return const Right(null);
    } catch (e, stackTrace) {
      AppLogger.error('[$boxName] فشل الحذف المحلي', e, stackTrace);
      return Left(CacheFailure('فشل الحذف: ${e.toString()}'));
    }
  }

  /// حفظ متعدد محلياً
  Future<Either<Failure, void>> saveAllLocal(List<TEntity> entities) async {
    try {
      final entries = <String, TModel>{};
      
      for (final entity in entities) {
        final model = toModel(entity);
        final id = getId(entity);
        entries[id] = model;
      }
      
      await hiveService.putAll<TModel>(boxName, entries);
      AppLogger.info('[$boxName] تم حفظ ${entries.length} عنصر محلياً');
      
      return const Right(null);
    } catch (e, stackTrace) {
      AppLogger.error('[$boxName] فشل الحفظ المتعدد', e, stackTrace);
      return Left(CacheFailure('فشل الحفظ: ${e.toString()}'));
    }
  }

  /// مسح جميع البيانات المحلية
  Future<Either<Failure, void>> clearLocal() async {
    try {
      await hiveService.clearBox(boxName);
      AppLogger.info('[$boxName] تم مسح جميع البيانات المحلية');
      
      return const Right(null);
    } catch (e, stackTrace) {
      AppLogger.error('[$boxName] فشل مسح البيانات', e, stackTrace);
      return Left(CacheFailure('فشل المسح: ${e.toString()}'));
    }
  }

  // ==================== Sync Operations ====================

  /// حفظ مع مزامنة (Offline-First)
  Future<Either<Failure, TEntity>> save(TEntity entity) async {
    try {
      // 1. حفظ محلياً أولاً
      final localResult = await saveLocal(entity);
      if (localResult.isLeft()) {
        return localResult.fold(
          (failure) => Left(failure),
          (_) => Right(entity),
        );
      }

      // 2. إضافة للـ sync queue
      final id = getId(entity);
      final model = toModel(entity);
      final operation = SyncOperation(
        id: '${collectionName}_create_$id',
        entity: collectionName,
        operation: 'create',
        data: toJson(model),
        timestamp: DateTime.now(),
      );
      await syncService.addToQueue(operation);

      // 3. محاولة المزامنة الفورية إذا كان متصلاً
      if (connectivityService.isConnected) {
        await syncService.syncAll();
      }

      AppLogger.success('[$boxName] تم حفظ $id بنجاح');
      return Right(entity);
    } catch (e, stackTrace) {
      AppLogger.error('[$boxName] فشل الحفظ', e, stackTrace);
      return Left(ServerFailure('فشل الحفظ: ${e.toString()}'));
    }
  }

  /// تحديث مع مزامنة
  Future<Either<Failure, TEntity>> update(TEntity entity) async {
    try {
      // 1. حفظ محلياً أولاً
      final localResult = await saveLocal(entity);
      if (localResult.isLeft()) {
        return localResult.fold(
          (failure) => Left(failure),
          (_) => Right(entity),
        );
      }

      // 2. إضافة للـ sync queue
      final id = getId(entity);
      final model = toModel(entity);
      final operation = SyncOperation(
        id: '${collectionName}_update_$id',
        entity: collectionName,
        operation: 'update',
        data: toJson(model),
        timestamp: DateTime.now(),
      );
      await syncService.addToQueue(operation);

      // 3. محاولة المزامنة الفورية
      if (connectivityService.isConnected) {
        await syncService.syncAll();
      }

      AppLogger.success('[$boxName] تم تحديث $id بنجاح');
      return Right(entity);
    } catch (e, stackTrace) {
      AppLogger.error('[$boxName] فشل التحديث', e, stackTrace);
      return Left(ServerFailure('فشل التحديث: ${e.toString()}'));
    }
  }

  /// حذف مع مزامنة
  Future<Either<Failure, void>> delete(String id, {Map<String, dynamic>? additionalData}) async {
    try {
      // 1. حذف محلياً أولاً
      final localResult = await deleteLocal(id);
      if (localResult.isLeft()) {
        return localResult;
      }

      // 2. إضافة للـ sync queue مع البيانات الإضافية
      final syncData = <String, dynamic>{'id': id};
      if (additionalData != null) {
        syncData.addAll(additionalData);
      }
      
      final operation = SyncOperation(
        id: '${collectionName}_delete_$id',
        entity: collectionName,
        operation: 'delete',
        data: syncData,
        timestamp: DateTime.now(),
      );
      await syncService.addToQueue(operation);

      // 3. محاولة المزامنة الفورية
      if (connectivityService.isConnected) {
        await syncService.syncAll();
      }

      AppLogger.success('[$boxName] تم حذف $id بنجاح');
      return const Right(null);
    } catch (e, stackTrace) {
      AppLogger.error('[$boxName] فشل الحذف', e, stackTrace);
      return Left(ServerFailure('فشل الحذف: ${e.toString()}'));
    }
  }

  /// جلب (Offline-First)
  Future<Either<Failure, TEntity?>> get(String id) async {
    // 1. محاولة الجلب المحلي أولاً
    final localResult = await getLocal(id);
    
    return localResult.fold(
      (failure) {
        // إذا فشل المحلي وكان متصلاً، جرب السيرفر
        if (connectivityService.isConnected) {
          return fetchFromServer(id);
        }
        return Left(failure);
      },
      (entity) {
        if (entity != null) {
          // وجد محلياً
          return Right(entity);
        }
        
        // لم يوجد محلياً، جرب السيرفر إذا متصل
        if (connectivityService.isConnected) {
          return fetchFromServer(id);
        }
        
        return const Right(null);
      },
    );
  }

  /// جلب الكل (Offline-First)
  Future<Either<Failure, List<TEntity>>> getAll() async {
    // 1. محاولة الجلب المحلي أولاً
    final localResult = await getAllLocal();
    
    return localResult.fold(
      (failure) {
        // إذا فشل المحلي وكان متصلاً، جرب السيرفر
        if (connectivityService.isConnected) {
          return fetchAllFromServer();
        }
        return Left(failure);
      },
      (entities) {
        // إذا كان المخزن فارغاً وكان متصلاً، جرب جلب من السيرفر
        if (entities.isEmpty && connectivityService.isConnected) {
          AppLogger.info('[$boxName] المخزن المحلي فارغ، جاري الجلب من السيرفر');
          return fetchAllFromServer();
        }
        
        // إذا كان متصلاً، قم بالمزامنة في الخلفية (رفع التغييرات)
        if (connectivityService.isConnected) {
          syncService.syncAll();
        }
        
        return Right(entities);
      },
    );
  }

  // ==================== Helper Methods ====================

  /// جلب من السيرفر (يجب تنفيذه في كل Repository)
  Future<Either<Failure, TEntity?>> fetchFromServer(String id);

  /// جلب الكل من السيرفر (يجب تنفيذه في كل Repository)
  Future<Either<Failure, List<TEntity>>> fetchAllFromServer();

  /// عدد العناصر المحلية
  int get localCount => hiveService.length(boxName);

  /// التحقق من وجود عنصر محلياً
  bool existsLocal(String id) => hiveService.containsKey(boxName, id);
}
