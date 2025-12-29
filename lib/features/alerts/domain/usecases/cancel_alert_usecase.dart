import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/logger.dart';
import '../entities/alert_entity.dart';
import '../repositories/alert_repository.dart';

class CancelAlertUseCase {
  final AlertRepository repository;

  CancelAlertUseCase(this.repository);

  Future<Either<Failure, void>> call(AlertEntity alert) async {
    AppLogger.info('[Alert] تم إلغاء التنبيه');
    
    final cancelledAlert = alert.copyWith(
      status: AlertStatus.resolved,
    );
    
    return repository.updateAlert(cancelledAlert);
  }
}
