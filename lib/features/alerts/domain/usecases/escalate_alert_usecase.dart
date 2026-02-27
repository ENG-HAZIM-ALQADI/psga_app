import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:psga_app/core/errors/failures.dart';
import 'package:psga_app/core/usecases/usecase.dart';
import 'package:psga_app/core/utils/logger.dart';
import 'package:psga_app/features/alerts/domain/entities/alert_entity.dart';
import 'package:psga_app/features/alerts/domain/repositories/alerts_repository.dart';

/// معاملات تصعيد التنبيه
class EscalateAlertParams extends Equatable {
  final String alertId;
  final AlertSeverity newSeverity;

  const EscalateAlertParams({
    required this.alertId,
    required this.newSeverity,
  });

  @override
  List<Object> get props => [alertId, newSeverity];
}

/// حالة استخدام: تصعيد التنبيه
/// 
/// Single Responsibility: مسؤول فقط عن تصعيد مستوى خطورة التنبيه
/// يتم استدعاؤه تلقائياً أو يدوياً عند الحاجة لزيادة أهمية التنبيه
class EscalateAlertUseCase implements UseCase<AlertEntity, EscalateAlertParams> {
  final AlertsRepository repository;

  EscalateAlertUseCase(this.repository);

  @override
  Future<Either<Failure, AlertEntity>> call(EscalateAlertParams params) async {
    try {
      AppLogger.warning('[EscalateAlertUseCase] جاري تصعيد التنبيه: ${params.alertId} إلى ${params.newSeverity.name}');
      
      final result = await repository.escalateAlert(
        alertId: params.alertId,
        newSeverity: params.newSeverity,
      );
      
      result.fold(
        (failure) => AppLogger.error('[EscalateAlertUseCase] فشل تصعيد التنبيه: ${failure.message}'),
        (alert) => AppLogger.success('[EscalateAlertUseCase] تم تصعيد التنبيه بنجاح إلى ${alert.severity.name}'),
      );
      
      return result;
    } catch (e, stackTrace) {
      AppLogger.error('[EscalateAlertUseCase] خطأ غير متوقع في تصعيد التنبيه', e, stackTrace);
      return Left(ServerFailure('فشل تصعيد التنبيه: ${e.toString()}'));
    }
  }
}
