import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:psga_app/core/errors/failures.dart';
import 'package:psga_app/core/usecases/usecase.dart';
import 'package:psga_app/core/utils/logger.dart';
import 'package:psga_app/features/alerts/domain/entities/alert_entity.dart';
import 'package:psga_app/features/alerts/domain/repositories/alerts_repository.dart';

/// معاملات الإقرار بالتنبيه
class AcknowledgeAlertParams extends Equatable {
  final String alertId;
  final String userId;

  const AcknowledgeAlertParams({
    required this.alertId,
    required this.userId,
  });

  @override
  List<Object> get props => [alertId, userId];
}

/// حالة استخدام: الإقرار بتنبيه
/// 
/// Single Responsibility: مسؤول فقط عن الإقرار بالتنبيهات
/// يتم استدعاؤه عندما يقر المستخدم باستلام التنبيه
class AcknowledgeAlertUseCase implements UseCase<AlertEntity, AcknowledgeAlertParams> {
  final AlertsRepository repository;

  AcknowledgeAlertUseCase(this.repository);

  @override
  Future<Either<Failure, AlertEntity>> call(AcknowledgeAlertParams params) async {
    try {
      AppLogger.info('[AcknowledgeAlertUseCase] جاري الإقرار بالتنبيه: ${params.alertId}');
      
      final result = await repository.acknowledgeAlert(
        alertId: params.alertId,
        userId: params.userId,
      );
      
      result.fold(
        (failure) => AppLogger.error('[AcknowledgeAlertUseCase] فشل الإقرار بالتنبيه: ${failure.message}'),
        (alert) => AppLogger.success('[AcknowledgeAlertUseCase] تم الإقرار بالتنبيه بنجاح'),
      );
      
      return result;
    } catch (e, stackTrace) {
      AppLogger.error('[AcknowledgeAlertUseCase] خطأ غير متوقع في الإقرار بالتنبيه', e, stackTrace);
      return Left(ServerFailure('فشل الإقرار بالتنبيه: ${e.toString()}'));
    }
  }
}
