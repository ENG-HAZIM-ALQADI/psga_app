import 'package:dartz/dartz.dart';
import 'package:psga_app/core/errors/failures.dart';
import 'package:psga_app/core/usecases/usecase.dart';
import 'package:psga_app/core/utils/logger.dart';
import 'package:psga_app/features/routes/domain/entities/route.dart';
import 'package:psga_app/features/routes/domain/repositories/routes_repository.dart';

/// UseCase للحصول على جميع مسارات المستخدم
/// يتبع Single Responsibility: مسؤولية واحدة فقط - جلب مسارات المستخدم
class GetUserRoutesUseCase
    implements UseCase<List<RouteEntity>, GetUserRoutesParams> {
  final RoutesRepository repository;

  GetUserRoutesUseCase(this.repository);

  @override
  Future<Either<Failure, List<RouteEntity>>> call(
    GetUserRoutesParams params,
  ) async {
    try {
      AppLogger.info('[GetUserRoutesUseCase] جاري الحصول على مسارات المستخدم: ${params.userId}');
      
      // ✅ التحقق من صحة المدخلات
      if (params.userId.trim().isEmpty) {
        AppLogger.error('[GetUserRoutesUseCase] معرف المستخدم فارغ');
        return const Left(ValidationFailure('معرف المستخدم مطلوب'));
      }

      final result = await repository.getUserRoutes(params.userId);

      result.fold(
        (failure) {
          AppLogger.error('[GetUserRoutesUseCase] فشل الحصول على المسارات', failure);
        },
        (routes) {
          AppLogger.success('[GetUserRoutesUseCase] تم جلب ${routes.length} مسار بنجاح');
        },
      );

      return result;
    } catch (e, stackTrace) {
      AppLogger.error('[GetUserRoutesUseCase] خطأ غير متوقع', e, stackTrace);
      return Left(UnknownFailure('فشل الحصول على المسارات: ${e.toString()}'));
    }
  }
}

/// معاملات الحصول على المسارات
class GetUserRoutesParams {
  final String userId;

  const GetUserRoutesParams({required this.userId});
}
