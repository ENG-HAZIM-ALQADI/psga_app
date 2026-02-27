import 'package:dartz/dartz.dart';
import 'package:psga_app/core/errors/failures.dart';
import 'package:psga_app/core/usecases/usecase.dart';
import 'package:psga_app/core/utils/logger.dart';
import 'package:psga_app/features/routes/domain/entities/route.dart';
import 'package:psga_app/features/routes/domain/repositories/routes_repository.dart';

/// UseCase للحصول على المسارات النشطة فقط
/// يتبع Single Responsibility: جلب المسارات النشطة
class GetActiveRoutesUseCase 
    implements UseCase<List<RouteEntity>, GetActiveRoutesParams> {
  final RoutesRepository repository;

  GetActiveRoutesUseCase(this.repository);

  @override
  Future<Either<Failure, List<RouteEntity>>> call(GetActiveRoutesParams params) async {
    try {
      AppLogger.info('[GetActiveRoutesUseCase] جاري الحصول على المسارات النشطة للمستخدم: ${params.userId}');
      
      // ✅ التحقق من صحة المدخلات
      if (params.userId.trim().isEmpty) {
        AppLogger.error('[GetActiveRoutesUseCase] معرف المستخدم فارغ');
        return const Left(ValidationFailure('معرف المستخدم مطلوب'));
      }
      
      final result = await repository.getActiveRoutes(params.userId);
      
      result.fold(
        (failure) {
          AppLogger.error('[GetActiveRoutesUseCase] فشل الحصول على المسارات النشطة', failure);
        },
        (routes) {
          AppLogger.success('[GetActiveRoutesUseCase] تم جلب ${routes.length} مسار نشط');
        },
      );
      
      return result;
    } catch (e, stackTrace) {
      AppLogger.error('[GetActiveRoutesUseCase] خطأ غير متوقع', e, stackTrace);
      return Left(UnknownFailure('فشل الحصول على المسارات النشطة: ${e.toString()}'));
    }
  }
}

class GetActiveRoutesParams {
  final String userId;

  const GetActiveRoutesParams({required this.userId});
}
