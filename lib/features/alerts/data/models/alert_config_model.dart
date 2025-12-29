import 'package:flutter/material.dart';
import '../../domain/entities/alert_config_entity.dart';

class AlertConfigModel extends AlertConfigEntity {
  const AlertConfigModel({
    required super.userId,
    super.isEnabled,
    super.deviationThreshold,
    super.countdownSeconds,
    super.autoEscalate,
    super.sosEnabled,
    super.sosCountdownSeconds,
    super.inactivityTimeout,
    super.lowBatteryThreshold,
    super.quietHoursEnabled,
    super.quietHoursStart,
    super.quietHoursEnd,
    super.soundEnabled,
    super.vibrationEnabled,
  });

  factory AlertConfigModel.fromJson(Map<String, dynamic> json) {
    return AlertConfigModel(
      userId: json['userId'] as String,
      isEnabled: json['isEnabled'] as bool? ?? true,
      deviationThreshold: (json['deviationThreshold'] as num?)?.toDouble() ?? 100.0,
      countdownSeconds: json['countdownSeconds'] as int? ?? 30,
      autoEscalate: json['autoEscalate'] as bool? ?? true,
      sosEnabled: json['sosEnabled'] as bool? ?? true,
      sosCountdownSeconds: json['sosCountdownSeconds'] as int? ?? 5,
      inactivityTimeout: json['inactivityTimeout'] as int? ?? 30,
      lowBatteryThreshold: json['lowBatteryThreshold'] as int? ?? 15,
      quietHoursEnabled: json['quietHoursEnabled'] as bool? ?? false,
      quietHoursStart: json['quietHoursStart'] != null
          ? TimeOfDay(
              hour: json['quietHoursStart']['hour'] as int,
              minute: json['quietHoursStart']['minute'] as int,
            )
          : null,
      quietHoursEnd: json['quietHoursEnd'] != null
          ? TimeOfDay(
              hour: json['quietHoursEnd']['hour'] as int,
              minute: json['quietHoursEnd']['minute'] as int,
            )
          : null,
      soundEnabled: json['soundEnabled'] as bool? ?? true,
      vibrationEnabled: json['vibrationEnabled'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'isEnabled': isEnabled,
      'deviationThreshold': deviationThreshold,
      'countdownSeconds': countdownSeconds,
      'autoEscalate': autoEscalate,
      'sosEnabled': sosEnabled,
      'sosCountdownSeconds': sosCountdownSeconds,
      'inactivityTimeout': inactivityTimeout,
      'lowBatteryThreshold': lowBatteryThreshold,
      'quietHoursEnabled': quietHoursEnabled,
      'quietHoursStart': quietHoursStart != null
          ? {'hour': quietHoursStart!.hour, 'minute': quietHoursStart!.minute}
          : null,
      'quietHoursEnd': quietHoursEnd != null
          ? {'hour': quietHoursEnd!.hour, 'minute': quietHoursEnd!.minute}
          : null,
      'soundEnabled': soundEnabled,
      'vibrationEnabled': vibrationEnabled,
    };
  }

  factory AlertConfigModel.defaultConfig(String userId) {
    return AlertConfigModel(
      userId: userId,
      isEnabled: true,
      deviationThreshold: 100.0,
      countdownSeconds: 30,
      autoEscalate: true,
      sosEnabled: true,
      sosCountdownSeconds: 5,
      inactivityTimeout: 30,
      lowBatteryThreshold: 15,
      quietHoursEnabled: false,
      soundEnabled: true,
      vibrationEnabled: true,
    );
  }

  factory AlertConfigModel.fromEntity(AlertConfigEntity entity) {
    return AlertConfigModel(
      userId: entity.userId,
      isEnabled: entity.isEnabled,
      deviationThreshold: entity.deviationThreshold,
      countdownSeconds: entity.countdownSeconds,
      autoEscalate: entity.autoEscalate,
      sosEnabled: entity.sosEnabled,
      sosCountdownSeconds: entity.sosCountdownSeconds,
      inactivityTimeout: entity.inactivityTimeout,
      lowBatteryThreshold: entity.lowBatteryThreshold,
      quietHoursEnabled: entity.quietHoursEnabled,
      quietHoursStart: entity.quietHoursStart,
      quietHoursEnd: entity.quietHoursEnd,
      soundEnabled: entity.soundEnabled,
      vibrationEnabled: entity.vibrationEnabled,
    );
  }
}
