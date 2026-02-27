import 'package:equatable/equatable.dart';
import 'package:psga_app/features/alerts/domain/entities/alert_config_entity.dart';
import 'package:psga_app/features/alerts/domain/entities/alert_entity.dart';

abstract class AlertState extends Equatable {
  const AlertState();
  
  @override
  List<Object?> get props => [];
}

class AlertInitial extends AlertState {}

class AlertLoading extends AlertState {}

class AlertTriggered extends AlertState {
  final AlertEntity alert;

  const AlertTriggered(this.alert);

  @override
  List<Object> get props => [alert];
}

class SOSSent extends AlertState {
  final AlertEntity alert;

  const SOSSent(this.alert);

  @override
  List<Object> get props => [alert];
}

class ActiveAlertsLoaded extends AlertState {
  final List<AlertEntity> alerts;

  const ActiveAlertsLoaded(this.alerts);

  @override
  List<Object> get props => [alerts];
}

class AlertHistoryLoaded extends AlertState {
  final List<AlertEntity> alerts;

  const AlertHistoryLoaded(this.alerts);

  @override
  List<Object> get props => [alerts];
}

class AlertAcknowledged extends AlertState {
  final AlertEntity alert;

  const AlertAcknowledged(this.alert);

  @override
  List<Object> get props => [alert];
}

class AlertResolved extends AlertState {
  final AlertEntity alert;

  const AlertResolved(this.alert);

  @override
  List<Object> get props => [alert];
}

class AlertError extends AlertState {
  final String message;

  const AlertError(this.message);

  @override
  List<Object> get props => [message];
}

/// التصعيد جارٍ
class EscalationInProgress extends AlertState {
  final AlertEntity alert;
  final int remainingSeconds;
  final int totalSeconds;

  const EscalationInProgress({
    required this.alert,
    required this.remainingSeconds,
    required this.totalSeconds,
  });

  @override
  List<Object> get props => [alert, remainingSeconds, totalSeconds];

  /// نسبة الوقت المتبقي (0.0 - 1.0)
  double get progress => remainingSeconds / totalSeconds;
}

/// تم إلغاء التصعيد ("أنا بخير")
class EscalationCancelled extends AlertState {
  final String alertId;
  final String userId;

  const EscalationCancelled({
    required this.alertId,
    required this.userId,
  });

  @override
  List<Object> get props => [alertId, userId];
}

/// اكتمل التصعيد - تم الإرسال
class EscalationCompleted extends AlertState {
  final AlertEntity alert;
  final Map<String, dynamic> results;

  const EscalationCompleted({
    required this.alert,
    required this.results,
  });

  @override
  List<Object> get props => [alert, results];
}

/// SOS فوري تم الإرسال
class ImmediateSOSSent extends AlertState {
  final AlertEntity alert;
  final Map<String, dynamic> results;

  const ImmediateSOSSent({
    required this.alert,
    required this.results,
  });

  @override
  List<Object> get props => [alert, results];
}

/// تم حفظ إعدادات التنبيهات
class AlertConfigSaved extends AlertState {
  final AlertConfigEntity config;

  const AlertConfigSaved(this.config);

  @override
  List<Object> get props => [config];
}

/// تم تحميل إعدادات التنبيهات
class AlertConfigLoaded extends AlertState {
  final AlertConfigEntity config;

  const AlertConfigLoaded(this.config);

  @override
  List<Object> get props => [config];
}
