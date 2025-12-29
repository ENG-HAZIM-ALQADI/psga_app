import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/services/sync/sync_manager.dart';
import '../../../../core/services/sync/sync_item.dart';
import '../../domain/entities/route_entity.dart';
import '../../domain/repositories/route_repository.dart';
import '../datasources/route_local_datasource.dart';
import '../datasources/route_remote_datasource.dart';
import '../models/route_model.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// 🛣️ RouteRepositoryImpl - تطبيق Repository للمسارات (Data Layer)
/// ═══════════════════════════════════════════════════════════════════════════
///
/// الهدف: إدارة بيانات المسارات من مصادر متعددة
///
/// المسؤوليات:
/// 1. 💾 التعامل مع التخزين المحلي (Hive)
/// 2. ☁️ التعامل مع البيانات السحابية (Firebase)
/// 3. 🔄 مزامنة البيانات بين Local و Remote
/// 4. ❌ معالجة الأخطاء بشكل موحد
/// 5. 📊 إدارة الإحصائيات (المفضلة، عدد الاستخدام)
///
/// الاستراتيجية: **Offline-First**
/// - اقرأ من Hive أولاً (سريع + يعمل بدون إنترنت)
/// - إذا فارغ: اجلب من Firebase (للمزامنة)
/// - احفظ النتيجة في Hive (للمرات التالية)

class RouteRepositoryImpl implements RouteRepository {
  /// 🔗 الاعتماديات
  final RouteLocalDataSource localDataSource;   /// 💾 Hive
  final RouteRemoteDataSource remoteDataSource; /// ☁️ Firebase
  final SyncManager _syncManager = SyncManager.instance; /// 🔄 مزامنة

  RouteRepositoryImpl({
    required this.localDataSource,
    required this.remoteDataSource,
  });

  /// ═══════════════════════════════════════════════════════════════════════════
  /// ➕ createRoute() - إنشاء مسار جديد
  /// ═══════════════════════════════════════════════════════════════════════════
  ///
  /// الخطوات:
  /// 1️⃣ تحويل RouteEntity إلى RouteModel (للحفظ في Database)
  /// 2️⃣ حفظ في Hive محلياً (فوري)
  /// 3️⃣ إضافة لـ Sync Queue (لـ Firebase لاحقاً)
  /// 4️⃣ تسجيل العملية

  @override
  Future<Either<Failure, RouteEntity>> createRoute(RouteEntity route) async {
    try {
      /// تحويل Entity إلى Model
      final routeModel = RouteModel.fromEntity(route);
      
      /// حفظ محلياً
      await localDataSource.saveRoute(routeModel);
      
      /// إضافة لـ Sync Queue
      final syncItem = SyncItem(
        createdAt: DateTime.now(),
        id: route.id,
        type: SyncItemType.route,
        action: SyncAction.create,
        data: routeModel.toJson(),
        localId: route.id,
      );
      await _syncManager.addToQueue(syncItem);
      
      AppLogger.info('[RouteRepo] تم حفظ المسار: ${route.name}');
      return Right(route);
    } catch (e) {
      AppLogger.error('[RouteRepo] خطأ في إنشاء المسار: $e');
      return const Left(ServerFailure(message: 'فشل في إنشاء المسار'));
    }
  }

  /// ═══════════════════════════════════════════════════════════════════════════
  /// 📖 getRoute() - جلب مسار بمعرفه (Offline-First)
  /// ═══════════════════════════════════════════════════════════════════════════
  ///
  /// الاستراتيجية:
  /// 1️⃣ اقرأ من Hive أولاً
  /// 2️⃣ إذا لم تجد: اجلب من Firebase وحفظ محلياً
  /// 3️⃣ إرجع النتيجة

  @override
  Future<Either<Failure, RouteEntity>> getRoute(String id) async {
    try {
      /// 1️⃣ محاولة جلب من Hive
      var route = await localDataSource.getRoute(id);
      
      /// 2️⃣ إذا لم تجد محلياً: جلب من Firebase
      if (route == null) {
        AppLogger.info('[RouteRepo] 📥 جلب المسار من Firebase...');
        route = await remoteDataSource.getRoute(id);
        
        /// ✅ حفظ في Hive للمرات التالية
        if (route != null) {
          final routeModel = RouteModel.fromEntity(route);
          await localDataSource.saveRoute(routeModel);
          AppLogger.success('[RouteRepo] ✅ تم حفظ المسار محلياً: ${route.name}');
        }
      }
      
      /// التحقق النهائي: هل المسار موجود؟
      if (route == null) {
        return const Left(NotFoundFailure(message: 'المسار غير موجود'));
      }
      
      return Right(route);
    } catch (e) {
      AppLogger.error('[RouteRepo] ❌ خطأ في جلب المسار: $e');
      return const Left(ServerFailure(message: 'فشل في جلب المسار'));
    }
  }

  /// ═══════════════════════════════════════════════════════════════════════════
  /// 📖 getUserRoutes() - جلب جميع مسارات المستخدم
  /// ═══════════════════════════════════════════════════════════════════════════
  ///
  /// المنطق:
  /// 1️⃣ اقرأ من Hive أولاً (قد تكون مجموعة المسارات محفوظة)
  /// 2️⃣ إذا كانت Hive فارغة: جلب من Firebase ملء Hive
  /// 3️⃣ صفّي حسب المستخدم

  @override
  Future<Either<Failure, List<RouteEntity>>> getUserRoutes(String userId) async {
    try {
      AppLogger.info('[RouteRepo] 📍 جاري تحميل المسارات للمستخدم: $userId');
      
      /// 1️⃣ قراءة من Hive أولاً (سريع)
      var routes = await localDataSource.getAllRoutes();
      AppLogger.info('[RouteRepo] 📖 تم قراءة ${routes.length} مسار من Hive');
      
      /// 2️⃣ إذا Hive فارغة: جلب من Firebase
      if (routes.isEmpty) {
        AppLogger.info('[RouteRepo] 📥 Hive فارغة - جاري جلب المسارات من Firebase...');
        final remoteRoutes = await remoteDataSource.getUserRoutes(userId);
        AppLogger.info('[RouteRepo] 📥 جلب ${remoteRoutes.length} مسار من Firebase');
        
        /// ✅ حفظ كل مسار في Hive
        for (final route in remoteRoutes) {
          await localDataSource.saveRoute(route);
          AppLogger.info('[RouteRepo] 💾 حفظ مسار في Hive: ${route.name}');
        }
        routes = remoteRoutes;
        AppLogger.info('[RouteRepo] ✅ اكتمل حفظ ${routes.length} مسار في Hive');
      }
      
      /// 3️⃣ تصفية حسب المستخدم
      /// قد تكون هناك مسارات لمستخدمين آخرين في Hive
      final userRoutes = routes.where((r) => r.userId == userId).toList();
      AppLogger.success('[RouteRepo] ✅ تم جلب ${userRoutes.length} مسار للمستخدم: $userId');
      return Right(userRoutes);
    } catch (e) {
      AppLogger.error('[RouteRepo] ❌ خطأ في جلب المسارات: $e');
      return const Left(ServerFailure(message: 'فشل في جلب المسارات'));
    }
  }

  /// ═══════════════════════════════════════════════════════════════════════════
  /// ✏️ updateRoute() - تحديث مسار
  /// ═══════════════════════════════════════════════════════════════════════════

  @override
  Future<Either<Failure, RouteEntity>> updateRoute(RouteEntity route) async {
    try {
      final routeModel = RouteModel.fromEntity(route);
      
      /// تحديث محلياً
      await localDataSource.updateRoute(routeModel);
      
      /// إضافة لـ Sync Queue
      final syncItem = SyncItem(
        createdAt: DateTime.now(),
        id: route.id,
        type: SyncItemType.route,
        action: SyncAction.update,
        data: routeModel.toJson(),
        localId: route.id,
      );
      await _syncManager.addToQueue(syncItem);
      
      AppLogger.info('[RouteRepo] تم تحديث المسار: ${route.name}');
      return Right(route);
    } catch (e) {
      AppLogger.error('[RouteRepo] خطأ في تحديث المسار: $e');
      return const Left(ServerFailure(message: 'فشل في تحديث المسار'));
    }
  }

  /// ═══════════════════════════════════════════════════════════════════════════
  /// 🗑️ deleteRoute() - حذف مسار
  /// ═══════════════════════════════════════════════════════════════════════════
  ///
  /// الخطوات:
  /// 1️⃣ حذف من Hive
  /// 2️⃣ إضافة عملية حذف لـ Sync Queue (لحذفها من Firebase لاحقاً)

  @override
  Future<Either<Failure, void>> deleteRoute(String id) async {
    try {
      await localDataSource.deleteRoute(id);
      
      /// إضافة عملية حذف للمزامنة
      final syncItem = SyncItem(
        createdAt: DateTime.now(),
        id: id,
        type: SyncItemType.route,
        action: SyncAction.delete,
        data: {'id': id},
        localId: id,
      );
      await _syncManager.addToQueue(syncItem);
      
      AppLogger.info('[RouteRepo] تم حذف المسار: $id');
      return const Right(null);
    } catch (e) {
      AppLogger.error('[RouteRepo] خطأ في حذف المسار: $e');
      return const Left(ServerFailure(message: 'فشل في حذف المسار'));
    }
  }

  /// ═══════════════════════════════════════════════════════════════════════════
  /// ⭐ getFavoriteRoutes() - جلب المسارات المفضلة
  /// ═══════════════════════════════════════════════════════════════════════════
  ///
  /// عملية محلية بحتة (لا حاجة لـ Firebase)
  /// فقط: صفي المسارات حسب isFavorite

  @override
  Future<Either<Failure, List<RouteEntity>>> getFavoriteRoutes(String userId) async {
    try {
      final allRoutes = await localDataSource.getAllRoutes();
      final favorites = allRoutes
          .where((r) => r.userId == userId && r.isFavorite)
          .toList();
      
      return Right(favorites);
    } catch (e) {
      AppLogger.error('[RouteRepo] خطأ في جلب المفضلة: $e');
      return const Left(ServerFailure(message: 'فشل في جلب المسارات المفضلة'));
    }
  }

  /// ═══════════════════════════════════════════════════════════════════════════
  /// 🔄 toggleFavorite() - تبديل حالة المفضلة
  /// ═══════════════════════════════════════════════════════════════════════════
  ///
  /// الخطوات:
  /// 1️⃣ جلب المسار الحالي
  /// 2️⃣ عكس قيمة isFavorite (true ↔️ false)
  /// 3️⃣ حفظ التحديث
  /// 4️⃣ إضافة للمزامنة

  @override
  Future<Either<Failure, void>> toggleFavorite(String routeId) async {
    try {
      final route = await localDataSource.getRoute(routeId);
      
      if (route == null) {
        return const Left(NotFoundFailure(message: 'المسار غير موجود'));
      }
      
      /// تبديل: جعل المفضل غير مفضل والعكس
      final updatedRoute = RouteModel(
        id: route.id,
        userId: route.userId,
        name: route.name,
        description: route.description,
        startPoint: route.startPoint,
        endPoint: route.endPoint,
        waypoints: route.waypoints,
        estimatedDuration: route.estimatedDuration,
        estimatedDistance: route.estimatedDistance,
        isFavorite: !route.isFavorite,  /// عكس القيمة
        usageCount: route.usageCount,
        createdAt: route.createdAt,
        updatedAt: DateTime.now(),
        polylinePoints: route.polylinePoints,
      );
      
      /// حفظ التحديث
      await localDataSource.updateRoute(updatedRoute);
      
      /// إضافة للمزامنة
      final syncItem = SyncItem(
        createdAt: DateTime.now(),
        id: routeId,
        type: SyncItemType.route,
        action: SyncAction.update,
        data: updatedRoute.toJson(),
        localId: routeId,
      );
      await _syncManager.addToQueue(syncItem);
      
      AppLogger.info('[RouteRepo] تم تبديل المفضلة للمسار: $routeId');
      return const Right(null);
    } catch (e) {
      AppLogger.error('[RouteRepo] خطأ في تبديل المفضلة: $e');
      return const Left(ServerFailure(message: 'فشل في تبديل المفضلة'));
    }
  }
}

/// ═══════════════════════════════════════════════════════════════════════════
/// ملخص تدفق البيانات:
/// ═══════════════════════════════════════════════════════════════════════════
/// 
/// ```
/// UI (RouteListPage)
///   ↓ اطلب المسارات
/// RouteBloc.add(LoadRoutesEvent)
///   ↓
/// RouteBloc يستدعي: getUserRoutesUseCase()
///   ↓
/// UseCase يستدعي: routeRepository.getUserRoutes()
///   ↓ ← أنت هنا
/// RouteRepositoryImpl:
///   1. اقرأ من Hive ✓
///   2. إذا فارغ: اجلب من Firebase ✓
///   3. احفظ في Hive ✓
///   4. صفّي حسب المستخدم ✓
///   ↓
/// النتيجة: Right(routes)
///   ↓
/// BLoC يصدر: emit(RoutesLoaded(routes))
///   ↓
/// BlocBuilder يرى الحالة الجديدة
///   ↓
/// UI تعرض قائمة المسارات
/// ```
/// ═══════════════════════════════════════════════════════════════════════════
