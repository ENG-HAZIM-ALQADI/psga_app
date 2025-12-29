import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/logger.dart';
import '../../../trips/domain/entities/location_entity.dart';
import '../entities/alert_entity.dart';
import '../repositories/alert_repository.dart';

class TriggerAlertParams {
  final String tripId;
  final String userId;
  final AlertType type;
  final AlertLevel level;
  final LocationEntity location;
  final String? message;

  TriggerAlertParams({
    required this.tripId,
    required this.userId,
    required this.type,
    required this.level,
    required this.location,
    this.message,
  });
}

class TriggerAlertUseCase {
  final AlertRepository repository;

  TriggerAlertUseCase(this.repository);

  Future<Either<Failure, AlertEntity>> call(TriggerAlertParams params) async {
    AppLogger.info('[Alert] تفعيل تنبيه من نوع ${params.type.name} بمستوى ${params.level.name}');
    
    final alert = AlertEntity(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      tripId: params.tripId,
      userId: params.userId,
      type: params.type,
      level: params.level,
      status: AlertStatus.active,
      location: params.location,
      message: params.message ?? _getDefaultMessage(params.type),
      triggeredAt: DateTime.now(),
      deliveryMethod: DeliveryMethod.inApp,
    );

    return repository.createAlert(alert);
  }

  String _getDefaultMessage(AlertType type) {
    switch (type) {
      case AlertType.deviation:
        return 'تم اكتشاف انحراف عن المسار المحدد';
      case AlertType.sos:
        return 'تم إرسال إشارة طوارئ';
      case AlertType.inactivity:
        return 'لم يتم اكتشاف أي حركة لفترة طويلة';
      case AlertType.lowBattery:
        return 'مستوى البطارية منخفض';
      case AlertType.noConnection:
        return 'انقطع الاتصال بالإنترنت';
    }
  }
}
