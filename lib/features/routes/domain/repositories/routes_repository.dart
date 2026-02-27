import 'package:dartz/dartz.dart';
import 'package:psga_app/core/errors/failures.dart';
import 'package:psga_app/features/routes/domain/entities/route.dart';

/// واجهة Repository للمسارات
abstract class RoutesRepository {
  /// إنشاء مسار جديد
  Future<Either<Failure, RouteEntity>> createRoute(RouteEntity route);

  /// الحصول على جميع مسارات المستخدم
  Future<Either<Failure, List<RouteEntity>>> getUserRoutes(String userId);

  /// الحصول على مسار محدد
  Future<Either<Failure, RouteEntity>> getRoute(String routeId);

  /// تحديث مسار
  Future<Either<Failure, RouteEntity>> updateRoute(RouteEntity route);

  /// حذف مسار
  Future<Either<Failure, void>> deleteRoute(String routeId);

  /// تبديل المفضلة
  Future<Either<Failure, RouteEntity>> toggleFavorite(String routeId);

  /// الحصول على المسارات المفضلة
  Future<Either<Failure, List<RouteEntity>>> getFavoriteRoutes(String userId);

  /// الحصول على المسارات النشطة
  Future<Either<Failure, List<RouteEntity>>> getActiveRoutes(String userId);

  /// البحث في المسارات
  Future<Either<Failure, List<RouteEntity>>> searchRoutes(
    String userId,
    String query,
  );

  /// تغيير حالة المسار
  Future<Either<Failure, RouteEntity>> updateRouteStatus(
    String routeId,
    RouteStatus status,
  );

  /// مزامنة المسارات
  Future<Either<Failure, void>> syncRoutes(String userId);
}
