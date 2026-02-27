import 'package:dartz/dartz.dart';
import 'package:psga_app/core/errors/failures.dart';
import 'package:psga_app/core/usecases/usecase.dart';
import 'package:psga_app/core/utils/logger.dart';
import 'package:psga_app/features/routes/domain/entities/route.dart';
import 'package:psga_app/features/routes/domain/repositories/routes_repository.dart';

/// UseCase لتحديث حالة المسار (active, inactive, archived)
/// يتبع Single Responsibility: تحديث حالة المسار فقط
class UpdateRouteStatusUseCase 
    implements UseCase<RouteEntity, UpdateRouteStatusParams> {
  final RoutesRepository repository;

  UpdateRouteStatusUseCase(this.repository);

  @override
  Future<Either<Failure, RouteEntity>> call(UpdateRouteStatusParams params) async {
    try {
      AppLogger.info('[UpdateRouteStatusUseCase] تحديث حالة المسار: ${params.routeId} إلى ${params.status}');
      
      // ✅ التحقق من صحة المدخلات
      if (params.routeId.trim().isEmpty) {
        AppLogger.error('[UpdateRouteStatusUseCase] معرف المسار فارغ');
        return const Left(ValidationFailure('معرف المسار مطلوب'));
      }
      
      final result = await repository.updateRouteStatus(params.routeId, params.status);
      
      result.fold(
        (failure) {
          AppLogger.error('[UpdateRouteStatusUseCase] فشل تحديث الحالة', failure);
        },
        (route) {
          AppLogger.success('[UpdateRouteStatusUseCase] تم تحديث الحالة إلى: ${params.status}');
        },
      );
      
      return result;
    } catch (e, stackTrace) {
      AppLogger.error('[UpdateRouteStatusUseCase] خطأ غير متوقع', e, stackTrace);
      return Left(UnknownFailure('فشل تحديث حالة المسار: ${e.toString()}'));
    }
  }
}

class UpdateRouteStatusParams {
  final String routeId;
  final RouteStatus status;

  const UpdateRouteStatusParams({
    required this.routeId,
    required this.status,
  });
}
