import 'package:equatable/equatable.dart';
import '../../domain/entities/alert_entity.dart';
import '../../domain/entities/alert_config_entity.dart';

abstract class AlertState extends Equatable {
  const AlertState();

  @override
  List<Object?> get props => [];
}

class AlertInitial extends AlertState {
  const AlertInitial();
}

class AlertLoading extends AlertState {
  const AlertLoading();
}

class AlertActive extends AlertState {
  final AlertEntity alert;
  final int remainingSeconds;

  const AlertActive({
    required this.alert,
    required this.remainingSeconds,
  });

  @override
  List<Object?> get props => [alert, remainingSeconds];
}

class AlertCountingDown extends AlertState {
  final AlertEntity alert;
  final int remainingSeconds;

  const AlertCountingDown({
    required this.alert,
    required this.remainingSeconds,
  });

  AlertCountingDown copyWith({
    AlertEntity? alert,
    int? remainingSeconds,
  }) {
    return AlertCountingDown(
      alert: alert ?? this.alert,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
    );
  }

  @override
  List<Object?> get props => [alert, remainingSeconds];
}

class AlertEscalated extends AlertState {
  final AlertEntity alert;

  const AlertEscalated(this.alert);

  @override
  List<Object?> get props => [alert];
}

class AlertAcknowledged extends AlertState {
  final AlertEntity alert;

  const AlertAcknowledged(this.alert);

  @override
  List<Object?> get props => [alert];
}

class AlertHistoryLoaded extends AlertState {
  final List<AlertEntity> alerts;

  const AlertHistoryLoaded(this.alerts);

  @override
  List<Object?> get props => [alerts];
}

class AlertConfigLoaded extends AlertState {
  final AlertConfigEntity config;

  const AlertConfigLoaded(this.config);

  @override
  List<Object?> get props => [config];
}

class AlertError extends AlertState {
  final String message;

  const AlertError(this.message);

  @override
  List<Object?> get props => [message];
}

class SOSSent extends AlertState {
  final AlertEntity alert;
  final List<String> notifiedContacts;

  const SOSSent({
    required this.alert,
    this.notifiedContacts = const [],
  });

  @override
  List<Object?> get props => [alert, notifiedContacts];
}

class SOSSending extends AlertState {
  final int countdownSeconds;

  const SOSSending(this.countdownSeconds);

  @override
  List<Object?> get props => [countdownSeconds];
}

class SOSCancelled extends AlertState {
  const SOSCancelled();
}
