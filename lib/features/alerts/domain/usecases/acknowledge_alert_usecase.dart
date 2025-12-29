import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/logger.dart';
import '../repositories/alert_repository.dart';

class AcknowledgeAlertUseCase {
  final AlertRepository repository;

  AcknowledgeAlertUseCase(this.repository);

  Future<Either<Failure, void>> call(String alertId) async {
    AppLogger.success('[Alert] تم إلغاء التنبيه من قبل المستخدم');
    return repository.acknowledgeAlert(alertId);
  }
}
