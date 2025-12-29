import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/logger.dart';
import '../entities/route_entity.dart';
import '../repositories/route_repository.dart';

/// 📌 خيارات الترتيب المتاحة للمستخدم في الواجهة
enum RouteSortOrder { 
  byUsage, // الأكثر استخداماً (شائع)
  byDate,  // الأحدث إنتاجاً
  byName   // أبجدياً حسب الاسم
}

/// ═══════════════════════════════════════════════════════════════════════════
/// 📋 GetUserRoutesUseCase - "منظم قائمة الطرق" (Domain Layer)
/// ═══════════════════════════════════════════════════════════════════════════
/// 
/// ❓ ما هي وظيفة هذا الملف؟
/// جلب المسارات التي رسمها المستخدم سابقاً، مع تقديم ميزة "الترتيب الذكي" 
/// لكي يجد المستخدم طريقه المفضل بسرعة.
///
/// 💡 شرح للمبتدئين:
/// - Switch Case: هي أداة اختيار. إذا طلب المستخدم الترتيب حسب "الاسم"، 
///   ننفذ كود الترتيب الأبجدي، وهكذا.

class GetUserRoutesUseCase {
  final RouteRepository repository;

  GetUserRoutesUseCase(this.repository);

  /// 🔹 جلب وتنظيم المسارات (Call)
  Future<Either<Failure, List<RouteEntity>>> call(
    String userId, {
    RouteSortOrder sortOrder = RouteSortOrder.byDate,
  }) async {
    AppLogger.info('[Routes] طلب جلب قائمة مسارات المستخدم مع ترتيب: ${sortOrder.name}');

    // 1️⃣ جلب المسارات من المستودع.
    final result = await repository.getUserRoutes(userId);

    // 2️⃣ تنفيذ عملية الترتيب بناءً على رغبة المستخدم.
    return result.map((routes) {
      List<RouteEntity> sortedRoutes;
      
      switch (sortOrder) {
        case RouteSortOrder.byUsage:
          // ترتيب تنازلي (من الأكثر استخداماً للأقل).
          sortedRoutes = List.from(routes)
            ..sort((a, b) => b.usageCount.compareTo(a.usageCount));
          break;
        case RouteSortOrder.byDate:
          // ترتيب تنازلي (من الأحدث للأقدم).
          sortedRoutes = List.from(routes)
            ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
          break;
        case RouteSortOrder.byName:
          // ترتيب أبجدي (أ، ب، ت...).
          sortedRoutes = List.from(routes)
            ..sort((a, b) => a.name.compareTo(b.name));
          break;
      }

      AppLogger.info('[Routes] تم تحميل وترتيب ${sortedRoutes.length} مسار بنجاح');
      return sortedRoutes;
    });
  }
}
