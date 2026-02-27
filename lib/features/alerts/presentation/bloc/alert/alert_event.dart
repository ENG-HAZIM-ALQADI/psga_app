import 'package:equatable/equatable.dart';
import 'package:psga_app/features/alerts/domain/entities/alert_config_entity.dart';
import 'package:psga_app/features/alerts/domain/entities/alert_entity.dart';
import 'package:psga_app/features/routes/domain/entities/location.dart';

abstract class AlertEvent extends Equatable {
  const AlertEvent();
  
  @override
  List<Object?> get props => [];
}

class TriggerAlertEvent extends AlertEvent {
  final String userId;
  final AlertType type;
  final String title;
  final String message;
  final AlertSeverity? severity;
  final String? tripId;
  final Location? location;
  final Map<String, dynamic>? metadata;

  const TriggerAlertEvent({
    required this.userId,
    required this.type,
    required this.title,
    required this.message,
    this.severity,
    this.tripId,
    this.location,
    this.metadata,
  });

  @override
  List<Object?> get props => [userId, type, title, message, severity, tripId, location, metadata];
}

class SendSOSEvent extends AlertEvent {
  final String userId;
  final Location location;
  final String? message;

  const SendSOSEvent({
    required this.userId,
    required this.location,
    this.message,
  });

  @override
  List<Object?> get props => [userId, location, message];
}

class AcknowledgeAlertEvent extends AlertEvent {
  final String alertId;
  final String userId;

  const AcknowledgeAlertEvent({
    required this.alertId,
    required this.userId,
  });

  @override
  List<Object> get props => [alertId, userId];
}

class LoadActiveAlertsEvent extends AlertEvent {
  final String userId;

  const LoadActiveAlertsEvent(this.userId);

  @override
  List<Object> get props => [userId];
}

class LoadAlertHistoryEvent extends AlertEvent {
  final String userId;

  const LoadAlertHistoryEvent(this.userId);

  @override
  List<Object> get props => [userId];
}

class ResolveAlertEvent extends AlertEvent {
  final String alertId;

  const ResolveAlertEvent(this.alertId);

  @override
  List<Object> get props => [alertId];
}

/// بدء تصعيد تلقائي لتنبيه
class StartEscalationEvent extends AlertEvent {
  final AlertEntity alert;
  final String userId;

  const StartEscalationEvent({
    required this.alert,
    required this.userId,
  });

  @override
  List<Object> get props => [alert, userId];
}

/// إلغاء تصعيد ("أنا بخير")
class CancelEscalationEvent extends AlertEvent {
  final String alertId;
  final String userId;

  const CancelEscalationEvent({
    required this.alertId,
    required this.userId,
  });

  @override
  List<Object> get props => [alertId, userId];
}

/// إرسال SOS فوري (بدون عد تنازلي)
class SendImmediateSOSEvent extends AlertEvent {
  final String userId;
  final Location location;
  final String? message;

  const SendImmediateSOSEvent({
    required this.userId,
    required this.location,
    this.message,
  });

  @override
  List<Object?> get props => [userId, location, message];
}

/// تحديث countdown tick
class EscalationCountdownTickEvent extends AlertEvent {
  final String alertId;
  final int remainingSeconds;

  const EscalationCountdownTickEvent({
    required this.alertId,
    required this.remainingSeconds,
  });

  @override
  List<Object> get props => [alertId, remainingSeconds];
}

/// حفظ إعدادات التنبيهات
class SaveAlertConfigEvent extends AlertEvent {
  final AlertConfigEntity config;

  const SaveAlertConfigEvent({required this.config});

  @override
  List<Object> get props => [config];
}

/// تحميل إعدادات التنبيهات
class LoadAlertConfigEvent extends AlertEvent {
  final String userId;

  const LoadAlertConfigEvent({required this.userId});

  @override
  List<Object> get props => [userId];
}
