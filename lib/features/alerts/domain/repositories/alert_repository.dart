import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/alert_entity.dart';
import '../entities/alert_config_entity.dart';

abstract class AlertRepository {
  Future<Either<Failure, AlertEntity>> createAlert(AlertEntity alert);
  
  Future<Either<Failure, void>> updateAlert(AlertEntity alert);
  
  Future<Either<Failure, AlertEntity?>> getActiveAlert(String tripId);
  
  Future<Either<Failure, List<AlertEntity>>> getAlertHistory(
    String userId, {
    int? limit,
    AlertType? typeFilter,
    AlertStatus? statusFilter,
  });
  
  Future<Either<Failure, void>> acknowledgeAlert(String alertId);
  
  Future<Either<Failure, void>> escalateAlert(String alertId, AlertLevel newLevel);
  
  Future<Either<Failure, AlertConfigEntity>> getAlertConfig(String userId);
  
  Future<Either<Failure, void>> updateAlertConfig(AlertConfigEntity config);
  
  Stream<AlertEntity> alertUpdates(String tripId);
}
