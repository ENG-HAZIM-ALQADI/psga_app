import 'package:dartz/dartz.dart';
import 'package:psga_app/core/errors/failures.dart';
import 'package:psga_app/core/usecases/usecase.dart';
import 'package:psga_app/core/utils/logger.dart';
import 'package:psga_app/features/alerts/domain/entities/alert_entity.dart';
import 'package:psga_app/features/alerts/domain/repositories/alerts_repository.dart';

/// حالة استخدام: جلب التنبيهات النشطة
/// 
/// Single Responsibility: مسؤول فقط عن جلب التنبيهات النشطة للمستخدم
/// يتم استدعاؤه لعرض التنبيهات الحالية التي تحتاج لمتابعة
class GetActiveAlertsUseCase implements UseCase<List<AlertEntity>, String> {
  final AlertsRepository repository;

  GetActiveAlertsUseCase(this.repository);

  @override
  Future<Either<Failure, List<AlertEntity>>> call(String userId) async {
    try {
      AppLogger.info('[GetActiveAlertsUseCase] جاري جلب التنبيهات النشطة للمستخدم: $userId');
      
      final result = await repository.getActiveAlerts(userId);
      
      result.fold(
        (failure) => AppLogger.error('[GetActiveAlertsUseCase] فشل جلب التنبيهات: ${failure.message}'),
        (alerts) => AppLogger.success('[GetActiveAlertsUseCase] تم جلب ${alerts.length} تنبيه نشط'),
      );
      
      return result;
    } catch (e, stackTrace) {
      AppLogger.error('[GetActiveAlertsUseCase] خطأ غير متوقع في جلب التنبيهات', e, stackTrace);
      return Left(ServerFailure('فشل جلب التنبيهات: ${e.toString()}'));
    }
  }
}
