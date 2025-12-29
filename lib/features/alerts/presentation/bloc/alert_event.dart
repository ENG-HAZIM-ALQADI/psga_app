import 'package:equatable/equatable.dart';
import '../../../trips/domain/entities/location_entity.dart';
import '../../domain/entities/alert_entity.dart';
import '../../domain/entities/alert_config_entity.dart';

abstract class AlertEvent extends Equatable {
  const AlertEvent();

  @override
  List<Object?> get props => [];
}

class TriggerAlertEvent extends AlertEvent {
  final AlertType type;
  final AlertLevel level;
  final LocationEntity location;
  final String? tripId;
  final String? message;

  const TriggerAlertEvent({
    required this.type,
    required this.level,
    required this.location,
    this.tripId,
    this.message,
  });

  @override
  List<Object?> get props => [type, level, location, tripId, message];
}

class AcknowledgeAlertEvent extends AlertEvent {
  final String alertId;

  const AcknowledgeAlertEvent(this.alertId);

  @override
  List<Object?> get props => [alertId];
}

class CancelAlertEvent extends AlertEvent {
  final AlertEntity alert;

  const CancelAlertEvent(this.alert);

  @override
  List<Object?> get props => [alert];
}

class EscalateAlertEvent extends AlertEvent {
  final AlertEntity alert;

  const EscalateAlertEvent(this.alert);

  @override
  List<Object?> get props => [alert];
}

class SendSOSEvent extends AlertEvent {
  final LocationEntity location;

  const SendSOSEvent(this.location);

  @override
  List<Object?> get props => [location];
}

class LoadAlertHistoryEvent extends AlertEvent {
  final AlertType? typeFilter;
  final AlertStatus? statusFilter;
  final int? limit;

  const LoadAlertHistoryEvent({
    this.typeFilter,
    this.statusFilter,
    this.limit,
  });

  @override
  List<Object?> get props => [typeFilter, statusFilter, limit];
}

class LoadAlertConfigEvent extends AlertEvent {
  const LoadAlertConfigEvent();
}

class UpdateAlertConfigEvent extends AlertEvent {
  final AlertConfigEntity config;

  const UpdateAlertConfigEvent(this.config);

  @override
  List<Object?> get props => [config];
}

class StartCountdownEvent extends AlertEvent {
  final int seconds;
  final AlertEntity alert;

  const StartCountdownEvent({
    required this.seconds,
    required this.alert,
  });

  @override
  List<Object?> get props => [seconds, alert];
}

class CountdownTickEvent extends AlertEvent {
  final int remainingSeconds;

  const CountdownTickEvent(this.remainingSeconds);

  @override
  List<Object?> get props => [remainingSeconds];
}

class StopCountdownEvent extends AlertEvent {
  const StopCountdownEvent();
}
