import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';
import 'package:psga_app/core/errors/failures.dart';
import 'package:psga_app/core/repositories/base_offline_repository.dart';
import 'package:psga_app/core/services/connectivity_service.dart';
import 'package:psga_app/core/services/sync_service.dart';
import 'package:psga_app/core/utils/logger.dart';
import 'package:psga_app/features/routes/data/datasources/routes_local_datasource.dart';
import 'package:psga_app/features/routes/data/datasources/routes_remote_datasource.dart';
import 'package:psga_app/features/routes/data/models/route_model.dart';
import 'package:psga_app/features/routes/domain/entities/route.dart';
import 'package:psga_app/features/routes/domain/repositories/routes_repository.dart';

/// تنفيذ Routes Repository وفق Clean Architecture
/// يستخدم DataSources للفصل بين مصادر البيانات
class RoutesRepositoryImpl 
    extends BaseOfflineRepository<RouteEntity, RouteModel>
    implements RoutesRepository {
  
  final FirebaseFirestore _firestore;
  
  // ✅ استخدام DataSources للفصل بين مصادر البيانات
  late final RoutesLocalDataSource _localDataSource;
  late final RoutesRemoteDataSource _remoteDataSource;
  
  // استخدام services من الـ singletons مباشرة
  final ConnectivityService _connectivity = ConnectivityService.instance;
  final SyncService _sync = SyncService.instance;

  RoutesRepositoryImpl({
    required FirebaseFirestore firestore,
    RoutesLocalDataSource? localDataSource,
    RoutesRemoteDataSource? remoteDataSource,
  }) : _firestore = firestore {
    // ✅ Initialize DataSources
    _localDataSource = localDataSource ?? RoutesLocalDataSourceImpl(hiveService: hiveService);
    _remoteDataSource = remoteDataSource ?? RoutesRemoteDataSourceImpl(firestore: firestore);
  }

  // ==================== BaseOfflineRepository Implementation ====================

  @override
  String get boxName => 'routes';

  @override
  String get collectionName => 'routes';

  @override
  RouteModel toModel(RouteEntity entity) => RouteModel.fromEntity(entity);

  @override
  RouteEntity toEntity(RouteModel model) => model.toEntity();

  @override
  Map<String, dynamic> toJson(RouteModel model) => model.toJson();

  @override
  RouteModel fromJson(Map<String, dynamic> json) => RouteModel.fromJson(json);

  @override
  String getId(RouteEntity entity) => entity.id;

  @override
  Future<Either<Failure, RouteEntity?>> fetchFromServer(String id) async {
    try {
      AppLogger.info('[RoutesRepository] جلب مسار من السيرفر: $id');
      
      // ✅ استخدام RemoteDataSource
      final model = await _remoteDataSource.getRoute(id);
      final entity = model.toEntity();
      
      // حفظ محلياً للـ cache
      await saveLocal(entity);
      
      AppLogger.success('[RoutesRepository] تم جلب المسار من السيرفر');
      return Right(entity);
    } catch (e, stackTrace) {
      AppLogger.error('[RoutesRepository] فشل جلب المسار من السيرفر', e, stackTrace);
      if (e.toString().contains('المسار غير موجود')) {
        return const Right(null);
      }
      return Left(ServerFailure('فشل جلب المسار: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<RouteEntity>>> fetchAllFromServer() async {
    // ✅ يجب تمرير userId - استخدم _fetchUserRoutesFromServer بدلاً من هذه الدالة
    AppLogger.warning('[RoutesRepository] fetchAllFromServer بدون userId - استخدم getUserRoutes');
    return const Right([]);
  }

  // ==================== RoutesRepository Implementation ====================

  @override
  Future<Either<Failure, RouteEntity>> createRoute(RouteEntity route) async {
    AppLogger.info('[RoutesRepository] إنشاء مسار: ${route.name}');
    
    final result = await save(route);
    
    // ✅ تحديث cache_key فوراً بعد الحفظ لضمان ظهور المسار الجديد فوراً
    // ignore: unawaited_futures
    result.fold(
      (_) {},
      (savedRoute) async {
        try {
          final cachedModels = await _localDataSource.getCachedRoutes(route.userId);
          final model = RouteModel.fromEntity(savedRoute);
          final hasRoute = cachedModels.any((m) => m.id == model.id);
          if (!hasRoute) {
            final updated = [...cachedModels, model];
            await _localDataSource.cacheRoutes(updated, route.userId);
            AppLogger.success('[RoutesRepository] تم تحديث cache_key: ${updated.length} مسار');
          }
        } catch (e) {
          AppLogger.warning('[RoutesRepository] فشل تحديث cache_key: $e');
        }
      },
    );
    
    return result;
  }

  @override
  Future<Either<Failure, RouteEntity>> updateRoute(RouteEntity route) async {
    AppLogger.info('[RoutesRepository] تحديث مسار: ${route.id}');
    return update(route);
  }

  @override
  Future<Either<Failure, void>> deleteRoute(String routeId) async {
    AppLogger.info('[RoutesRepository] حذف مسار: $routeId');
    
    // ✅ الحصول على المسار أولاً للحصول على userId
    final routeResult = await getLocal(routeId);
    
    return routeResult.fold(
      (failure) {
        // إذا فشل الجلب المحلي، نحاول الحذف بدون userId
        AppLogger.warning('[RoutesRepository] فشل جلب المسار محلياً، حذف بدون userId');
        return delete(routeId);
      },
      (route) {
        if (route == null) {
          // المسار غير موجود
          return const Left(NotFoundFailure('المسار غير موجود'));
        }
        
        // ✅ حذف مع تمرير userId
        return delete(routeId, additionalData: {'userId': route.userId});
      },
    );
  }

  @override
  Future<Either<Failure, RouteEntity>> getRoute(String routeId) async {
    AppLogger.info('[RoutesRepository] جلب مسار: $routeId');
    
    try {
      // ✅ 1. محاولة جلب من LocalDataSource أولاً
      final cachedModel = await _localDataSource.getCachedRoute(routeId);
      
      if (cachedModel != null) {
        AppLogger.success('[RoutesRepository] تم جلب المسار محلياً: ${cachedModel.name}');
        return Right(cachedModel.toEntity());
      }
      
      // ✅ 2. إذا لم يوجد محلياً وكان متصلاً، جلب من السيرفر
      if (!_connectivity.isConnected) {
        AppLogger.warning('[RoutesRepository] لا يوجد اتصال ولم يوجد المسار محلياً');
        return const Left(NotFoundFailure('المسار غير موجود'));
      }
      
      // ✅ جلب من RemoteDataSource
      final remoteModel = await _remoteDataSource.getRoute(routeId);
      
      // ✅ حفظ محلياً للمرة القادمة
      await _localDataSource.cacheRoute(remoteModel);
      
      AppLogger.success('[RoutesRepository] تم جلب المسار من السيرفر: ${remoteModel.name}');
      return Right(remoteModel.toEntity());
      
    } catch (e, stackTrace) {
      AppLogger.error('[RoutesRepository] خطأ في جلب المسار', e, stackTrace);
      
      if (e.toString().contains('المسار غير موجود')) {
        return const Left(NotFoundFailure('المسار غير موجود'));
      }
      
      return Left(ServerFailure('فشل جلب المسار: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<RouteEntity>>> getUserRoutes(String userId) async {
    AppLogger.info('[RoutesRepository] جلب مسارات المستخدم: $userId');
    
    try {
      // ✅ التحقق من صحة المدخلات
      if (userId.trim().isEmpty) {
        AppLogger.error('[RoutesRepository] معرف المستخدم فارغ');
        return const Left(ValidationFailure('معرف المستخدم مطلوب'));
      }
      
      // ✅ 1. محاولة جلب من LocalDataSource أولاً
      try {
        final cachedModels = await _localDataSource.getCachedRoutes(userId);
        
        if (cachedModels.isNotEmpty) {
          final entities = cachedModels.map((model) => model.toEntity()).toList();
          AppLogger.info('[RoutesRepository] تم العثور على ${entities.length} مسار محلياً');
          
          // ✅ إذا كان متصلاً، حدّث من السيرفر في الخلفية بدون انتظار
          if (_connectivity.isConnected) {
            // ignore: unawaited_futures
            Future.microtask(() async {
              try {
                AppLogger.info('[RoutesRepository] تحديث مسارات $userId من السيرفر في الخلفية');
                final freshModels = await _remoteDataSource.getUserRoutes(userId);
                if (freshModels.isNotEmpty) {
                  await _localDataSource.cacheRoutes(freshModels, userId);
                  AppLogger.success('[RoutesRepository] تم تحديث ${freshModels.length} مسار في الخلفية');
                }
              } catch (e) {
                AppLogger.warning('[RoutesRepository] فشل التحديث في الخلفية: $e');
              }
            });
          }
          
          return Right(entities);
        }
        
        AppLogger.info('[RoutesRepository] لا توجد مسارات محلية، جلب من السيرفر');
      } catch (e) {
        AppLogger.warning('[RoutesRepository] فشل الجلب المحلي، محاولة من السيرفر', e);
      }
      
      // ✅ 2. إذا لم توجد بيانات محلية، جلب من السيرفر
      if (!_connectivity.isConnected) {
        AppLogger.warning('[RoutesRepository] لا يوجد اتصال ولا توجد بيانات محلية');
        return const Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
      }
      
      return await _fetchUserRoutesFromServer(userId);
      
    } catch (e, stackTrace) {
      AppLogger.error('[RoutesRepository] خطأ في getUserRoutes', e, stackTrace);
      return Left(UnknownFailure('خطأ غير متوقع: ${e.toString()}'));
    }
  }

  /// جلب مسارات المستخدم من السيرفر باستخدام RemoteDataSource
  /// ✅ يتبع Clean Architecture: Repository يستخدم DataSource
  Future<Either<Failure, List<RouteEntity>>> _fetchUserRoutesFromServer(String userId) async {
    try {
      AppLogger.info('[RoutesRepository] جلب مسارات $userId من Firestore عبر RemoteDataSource');
      
      // ✅ استخدام RemoteDataSource بدلاً من Firestore مباشرة
      final models = await _remoteDataSource.getUserRoutes(userId);
      
      // تحويل Models إلى Entities
      final entities = models.map((model) => model.toEntity()).toList();
      
      if (entities.isEmpty) {
        AppLogger.info('[RoutesRepository] لا توجد مسارات للمستخدم $userId');
        return const Right([]);
      }
      
      // حفظ جميع المسارات محلياً عبر LocalDataSource
      try {
        await _localDataSource.cacheRoutes(models, userId);
        AppLogger.success('[RoutesRepository] تم حفظ ${entities.length} مسار محلياً');
      } catch (e) {
        AppLogger.warning('[RoutesRepository] فشل الحفظ المحلي (لكن البيانات متاحة): $e');
        // نستمر حتى لو فشل الحفظ المحلي
      }
      
      AppLogger.success('[RoutesRepository] تم جلب ${entities.length} مسار من السيرفر');
      return Right(entities);
    } catch (e, stackTrace) {
      AppLogger.error('[RoutesRepository] فشل جلب من السيرفر', e, stackTrace);
      return Left(ServerFailure('فشل الجلب من السيرفر: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, RouteEntity>> toggleFavorite(String routeId) async {
    try {
      AppLogger.info('[RoutesRepository] تبديل المفضلة: $routeId');
      
      final routeResult = await get(routeId);
      
      return routeResult.fold(
        (failure) => Left(failure),
        (route) async {
          if (route == null) {
            return const Left(NotFoundFailure('المسار غير موجود'));
          }
          
          final updatedRoute = route.copyWith(
            isFavorite: !route.isFavorite,
          );
          
          return update(updatedRoute);
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('[RoutesRepository] فشل تبديل المفضلة', e, stackTrace);
      return Left(ServerFailure('فشل التبديل: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<RouteEntity>>> getFavoriteRoutes(String userId) async {
    try {
      AppLogger.info('[RoutesRepository] جلب المسارات المفضلة: $userId');
      
      final allResult = await getAllLocal();
      
      return allResult.fold(
        (failure) => Left(failure),
        (routes) {
          final favorites = routes
              .where((route) => route.userId == userId && route.isFavorite)
              .toList();
          
          return Right(favorites);
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('[RoutesRepository] فشل جلب المفضلة', e, stackTrace);
      return Left(ServerFailure('فشل الجلب: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<RouteEntity>>> getActiveRoutes(String userId) async {
    try {
      AppLogger.info('[RoutesRepository] جلب المسارات النشطة: $userId');
      
      final allResult = await getAllLocal();
      
      return allResult.fold(
        (failure) => Left(failure),
        (routes) {
          final active = routes
              .where((route) => 
                  route.userId == userId && 
                  route.status == RouteStatus.active)
              .toList();
          
          return Right(active);
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('[RoutesRepository] فشل جلب المسارات النشطة', e, stackTrace);
      return Left(ServerFailure('فشل الجلب: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<RouteEntity>>> searchRoutes(
    String userId,
    String query,
  ) async {
    try {
      AppLogger.info('[RoutesRepository] البحث في المسارات: $query');
      
      final allResult = await getAllLocal();
      
      return allResult.fold(
        (failure) => Left(failure),
        (routes) {
          final searchTerm = query.toLowerCase();
          final results = routes
              .where((route) => 
                  route.userId == userId &&
                  (route.name.toLowerCase().contains(searchTerm) ||
                   (route.description?.toLowerCase().contains(searchTerm) ?? false)))
              .toList();
          
          return Right(results);
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('[RoutesRepository] فشل البحث', e, stackTrace);
      return Left(ServerFailure('فشل البحث: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, RouteEntity>> updateRouteStatus(
    String routeId,
    RouteStatus status,
  ) async {
    try {
      AppLogger.info('[RoutesRepository] تحديث حالة المسار: $routeId');
      
      final routeResult = await get(routeId);
      
      return routeResult.fold(
        (failure) => Left(failure),
        (route) async {
          if (route == null) {
            return const Left(NotFoundFailure('المسار غير موجود'));
          }
          
          final updatedRoute = route.copyWith(
            status: status,
          );
          
          return update(updatedRoute);
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('[RoutesRepository] فشل تحديث الحالة', e, stackTrace);
      return Left(ServerFailure('فشل التحديث: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> syncRoutes(String userId) async {
    try {
      AppLogger.info('[RoutesRepository] مزامنة المسارات: $userId');
      
      // مزامنة الكل
      await _sync.syncAll();
      
      // جلب من السيرفر (كلا المسارين)
      if (_connectivity.isConnected) {
        final allEntities = <RouteEntity>[];
        
        // 1. من subcollection (المصدر الأساسي)
        try {
          final subSnap = await _firestore
              .collection('users')
              .doc(userId)
              .collection('routes')
              .get();
          for (final doc in subSnap.docs) {
            allEntities.add(RouteModel.fromJson({...doc.data(), 'id': doc.id}).toEntity());
          }
          AppLogger.info('[RoutesRepository] subcollection: ${subSnap.docs.length} مسار');
        } catch (e) {
          AppLogger.warning('[RoutesRepository] فشل جلب subcollection: $e');
        }
        
        // 2. من legacy collection (للتوافق مع البيانات القديمة)
        try {
          final legacySnap = await _firestore
              .collection('routes')
              .where('userId', isEqualTo: userId)
              .get();
          for (final doc in legacySnap.docs) {
            final entity = RouteModel.fromJson(doc.data()).toEntity();
            if (!allEntities.any((e) => e.id == entity.id)) {
              allEntities.add(entity);
            }
          }
          AppLogger.info('[RoutesRepository] legacy: ${legacySnap.docs.length} مسار');
        } catch (e) {
          AppLogger.warning('[RoutesRepository] فشل جلب legacy: $e');
        }
        
        if (allEntities.isNotEmpty) {
          await saveAllLocal(allEntities);
          AppLogger.success('[RoutesRepository] تمت المزامنة: ${allEntities.length} مسار');
        }
        return const Right(null);
      }
      
      return const Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    } catch (e, stackTrace) {
      AppLogger.error('[RoutesRepository] فشلت المزامنة', e, stackTrace);
      return Left(ServerFailure('فشلت المزامنة: ${e.toString()}'));
    }
  }
}
