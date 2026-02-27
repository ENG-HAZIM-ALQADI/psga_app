import 'package:psga_app/core/constants/app_strings.dart';
import 'package:psga_app/core/storage/hive_service.dart';
import 'package:psga_app/core/utils/logger.dart';
import 'package:psga_app/features/routes/data/models/route_model.dart';

abstract class RoutesLocalDataSource {
  Future<void> cacheRoutes(List<RouteModel> routes, String userId);
  Future<List<RouteModel>> getCachedRoutes(String userId);
  Future<RouteModel?> getCachedRoute(String routeId);
  Future<void> cacheRoute(RouteModel route);
  Future<void> deleteCachedRoute(String routeId);
  Future<void> clearCache(String userId);
}

class RoutesLocalDataSourceImpl implements RoutesLocalDataSource {
  final HiveService hiveService;
  
  RoutesLocalDataSourceImpl({required this.hiveService});
  
  // استخدام نفس اسم الـ box المفتوح في HiveService
  static const String _boxName = 'routes';
  static const String _userRoutesPrefix = 'user_routes_';

  @override
  Future<void> cacheRoutes(List<RouteModel> routes, String userId) async {
    try {
      AppLogger.info('[RoutesLocalDataSource] حفظ ${routes.length} مسار محلياً');
      
      // حفظ Models مباشرة في Typed Box
      for (final route in routes) {
        await hiveService.put<RouteModel>(_boxName, route.id, route);
      }
      
      // حفظ قائمة IDs في cache box المحدد
      final routeIds = routes.map((r) => r.id).toList();
      await hiveService.put(AppStrings.cacheBox, '$_userRoutesPrefix$userId', routeIds);
      
      AppLogger.success('[RoutesLocalDataSource] تم الحفظ بنجاح');
    } catch (e, stackTrace) {
      AppLogger.error('[RoutesLocalDataSource] فشل الحفظ', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<List<RouteModel>> getCachedRoutes(String userId) async {
    try {
      AppLogger.info('[RoutesLocalDataSource] جلب المسارات المحلية');
      
      // ✅ الاستراتيجية المحسّنة: قراءة جميع المسارات من Box وتصفية بـ userId
      // هذا يضمن ظهور المسارات الجديدة فوراً بدون الاعتماد على cache_key فقط
      final allRoutes = hiveService.getAll<RouteModel>(_boxName);
      
      // تصفية مسارات هذا المستخدم فقط
      final userRoutes = allRoutes
          .where((r) => r.userId == userId)
          .toList();
      
      if (userRoutes.isNotEmpty) {
        AppLogger.success('[RoutesLocalDataSource] تم جلب ${userRoutes.length} مسار');
        // ✅ تحديث cache_key ليتطابق مع الواقع
        await _syncCacheKey(userRoutes, userId);
        return userRoutes;
      }
      
      // fallback: قراءة من cache_key (للتوافق)
      final routeIds = hiveService.get<List>(AppStrings.cacheBox, '$_userRoutesPrefix$userId');
      if (routeIds == null || routeIds.isEmpty) {
        AppLogger.info('[RoutesLocalDataSource] لا توجد مسارات محلية');
        return [];
      }
      
      final routes = <RouteModel>[];
      for (final id in routeIds) {
        final route = hiveService.get<RouteModel>(_boxName, id as String);
        if (route != null) routes.add(route);
      }
      
      AppLogger.success('[RoutesLocalDataSource] تم جلب ${routes.length} مسار (cache_key)');
      return routes;
    } catch (e, stackTrace) {
      AppLogger.error('[RoutesLocalDataSource] فشل الجلب', e, stackTrace);
      return [];
    }
  }
  
  /// مزامنة cache_key مع الواقع
  Future<void> _syncCacheKey(List<RouteModel> routes, String userId) async {
    try {
      final ids = routes.map((r) => r.id).toList();
      await hiveService.put(AppStrings.cacheBox, '$_userRoutesPrefix$userId', ids);
    } catch (_) {}
  }

  @override
  Future<RouteModel?> getCachedRoute(String routeId) async {
    try {
      final route = hiveService.get<RouteModel>(_boxName, routeId);
      return route;
    } catch (e) {
      AppLogger.error('[RoutesLocalDataSource] فشل جلب المسار', e);
      return null;
    }
  }

  @override
  Future<void> cacheRoute(RouteModel route) async {
    try {
      await hiveService.put<RouteModel>(_boxName, route.id, route);
      AppLogger.success('[RoutesLocalDataSource] تم حفظ المسار: ${route.id}');
    } catch (e) {
      AppLogger.error('[RoutesLocalDataSource] فشل حفظ المسار', e);
      rethrow;
    }
  }

  @override
  Future<void> deleteCachedRoute(String routeId) async {
    try {
      await hiveService.delete(_boxName, routeId);
      AppLogger.success('[RoutesLocalDataSource] تم حذف المسار: $routeId');
    } catch (e) {
      AppLogger.error('[RoutesLocalDataSource] فشل حذف المسار', e);
      rethrow;
    }
  }

  @override
  Future<void> clearCache(String userId) async {
    try {
      // جلب IDs من cache box المحدد
      final routeIds = hiveService.get<List>(AppStrings.cacheBox, '$_userRoutesPrefix$userId');
      if (routeIds != null) {
        // حذف المسارات من routes box
        for (final id in routeIds) {
          await hiveService.delete(_boxName, id as String);
        }
        // حذف قائمة IDs من cache box المحدد
        await hiveService.delete(AppStrings.cacheBox, '$_userRoutesPrefix$userId');
      }
      AppLogger.success('[RoutesLocalDataSource] تم مسح الـ cache');
    } catch (e) {
      AppLogger.error('[RoutesLocalDataSource] فشل مسح الـ cache', e);
      rethrow;
    }
  }
}
