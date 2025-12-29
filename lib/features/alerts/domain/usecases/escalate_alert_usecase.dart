import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/logger.dart';
import '../entities/alert_entity.dart';
import '../entities/contact_entity.dart';
import '../repositories/alert_repository.dart';
import '../repositories/contact_repository.dart';

class EscalateAlertParams {
  final String alertId;
  final AlertEntity currentAlert;

  EscalateAlertParams({
    required this.alertId,
    required this.currentAlert,
  });
}

class EscalateAlertUseCase {
  final AlertRepository alertRepository;
  final ContactRepository contactRepository;

  EscalateAlertUseCase({
    required this.alertRepository,
    required this.contactRepository,
  });

  Future<Either<Failure, AlertEntity>> call(EscalateAlertParams params) async {
    final currentLevel = params.currentAlert.level;
    final newLevel = _getNextLevel(currentLevel);
    final newDeliveryMethod = _getDeliveryMethod(newLevel);
    
    AppLogger.warning('[Alert] تصعيد التنبيه إلى المستوى ${newLevel.name}');
    
    final escalatedAlert = params.currentAlert.copyWith(
      level: newLevel,
      status: AlertStatus.escalated,
      escalatedAt: DateTime.now(),
      deliveryMethod: newDeliveryMethod,
    );

    final result = await alertRepository.escalateAlert(
      params.alertId,
      newLevel,
    );

    return result.fold(
      (failure) => Left(failure),
      (_) => Right(escalatedAlert),
    );
  }

  AlertLevel _getNextLevel(AlertLevel current) {
    switch (current) {
      case AlertLevel.low:
        return AlertLevel.medium;
      case AlertLevel.medium:
        return AlertLevel.high;
      case AlertLevel.high:
        return AlertLevel.critical;
      case AlertLevel.critical:
        return AlertLevel.critical;
    }
  }

  DeliveryMethod _getDeliveryMethod(AlertLevel level) {
    switch (level) {
      case AlertLevel.low:
        return DeliveryMethod.inApp;
      case AlertLevel.medium:
        return DeliveryMethod.fcm;
      case AlertLevel.high:
        return DeliveryMethod.sms;
      case AlertLevel.critical:
        return DeliveryMethod.all;
    }
  }

  Future<Either<Failure, List<ContactEntity>>> getContactsToNotify(
    String userId,
  ) async {
    return contactRepository.getContacts(userId);
  }
}
