import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/logger.dart';
import '../entities/alert_entity.dart';
import '../repositories/alert_repository.dart';

class GetAlertHistoryParams {
  final String userId;
  final int? limit;
  final AlertType? typeFilter;
  final AlertStatus? statusFilter;

  GetAlertHistoryParams({
    required this.userId,
    this.limit,
    this.typeFilter,
    this.statusFilter,
  });
}

class GetAlertHistoryUseCase {
  final AlertRepository repository;

  GetAlertHistoryUseCase(this.repository);

  Future<Either<Failure, List<AlertEntity>>> call(GetAlertHistoryParams params) async {
    AppLogger.info('[Alert] جاري جلب سجل التنبيهات...');
    
    final result = await repository.getAlertHistory(
      params.userId,
      limit: params.limit,
      typeFilter: params.typeFilter,
      statusFilter: params.statusFilter,
    );

    return result.fold(
      (failure) => Left(failure),
      (alerts) {
        alerts.sort((a, b) => b.triggeredAt.compareTo(a.triggeredAt));
        AppLogger.info('[Alert] تم جلب ${alerts.length} تنبيه');
        return Right(alerts);
      },
    );
  }
}
