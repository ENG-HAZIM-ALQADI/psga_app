import 'package:dartz/dartz.dart';
import 'package:psga_app/core/errors/failures.dart';
import 'package:psga_app/core/usecases/usecase.dart';
import 'package:psga_app/core/utils/logger.dart';
import 'package:psga_app/features/routes/domain/repositories/routes_repository.dart';

/// UseCase لمزامنة المسارات بين التخزين المحلي والسحابي
/// يتبع Single Responsibility: المزامنة فقط
class SyncRoutesUseCase implements UseCase<void, SyncRoutesParams> {
  final RoutesRepository repository;

  SyncRoutesUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(SyncRoutesParams params) async {
    try {
      AppLogger.info('[SyncRoutesUseCase] بدء مزامنة المسارات للمستخدم: ${params.userId}');
      
      // ✅ التحقق من صحة المدخلات
      if (params.userId.trim().isEmpty) {
        AppLogger.error('[SyncRoutesUseCase] معرف المستخدم فارغ');
        return const Left(ValidationFailure('معرف المستخدم مطلوب'));
      }
      
      final result = await repository.syncRoutes(params.userId);
      
      result.fold(
        (failure) {
          AppLogger.error('[SyncRoutesUseCase] فشلت المزامنة', failure);
        },
        (_) {
          AppLogger.success('[SyncRoutesUseCase] تمت المزامنة بنجاح');
        },
      );
      
      return result;
    } catch (e, stackTrace) {
      AppLogger.error('[SyncRoutesUseCase] خطأ غير متوقع', e, stackTrace);
      return Left(UnknownFailure('فشلت المزامنة: ${e.toString()}'));
    }
  }
}

class SyncRoutesParams {
  final String userId;

  const SyncRoutesParams({required this.userId});
}
