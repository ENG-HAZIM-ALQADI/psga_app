import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/route_entity.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// 📌 RouteRepository - واجهة مستودع المسارات (Domain Layer)
/// ═══════════════════════════════════════════════════════════════════════════
/// تحدد هذه الواجهة العمليات المتاحة لإدارة المسارات المحفوظة.
abstract class RouteRepository {
  
  /// 🛠️ إنشاء مسار جديد وحفظه
  Future<Either<Failure, RouteEntity>> createRoute(RouteEntity route);
  
  /// 🔍 جلب بيانات مسار محدد بواسطة معرفه
  Future<Either<Failure, RouteEntity>> getRoute(String id);
  
  /// 📋 جلب كافة المسارات الخاصة بمستخدم معين
  Future<Either<Failure, List<RouteEntity>>> getUserRoutes(String userId);
  
  /// 🔧 تحديث بيانات مسار موجود مسبقاً
  Future<Either<Failure, RouteEntity>> updateRoute(RouteEntity route);
  
  /// 🗑️ حذف مسار نهائياً
  Future<Either<Failure, void>> deleteRoute(String id);
  
  /// ⭐ جلب المسارات التي وضعها المستخدم في المفضلة
  Future<Either<Failure, List<RouteEntity>>> getFavoriteRoutes(String userId);
  
  /// ❤️ تبديل حالة المفضلة للمسار (إضافة/إزالة)
  Future<Either<Failure, void>> toggleFavorite(String routeId);
}
