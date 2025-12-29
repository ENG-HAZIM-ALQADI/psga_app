import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

class AlertConfigEntity extends Equatable {
  final String userId;
  final bool isEnabled;
  final double deviationThreshold;
  final int countdownSeconds;
  final bool autoEscalate;
  final bool sosEnabled;
  final int sosCountdownSeconds;
  final int inactivityTimeout;
  final int lowBatteryThreshold;
  final bool quietHoursEnabled;
  final TimeOfDay? quietHoursStart;
  final TimeOfDay? quietHoursEnd;
  final bool soundEnabled;
  final bool vibrationEnabled;

  const AlertConfigEntity({
    required this.userId,
    this.isEnabled = true,
    this.deviationThreshold = 100.0,
    this.countdownSeconds = 30,
    this.autoEscalate = true,
    this.sosEnabled = true,
    this.sosCountdownSeconds = 5,
    this.inactivityTimeout = 30,
    this.lowBatteryThreshold = 15,
    this.quietHoursEnabled = false,
    this.quietHoursStart,
    this.quietHoursEnd,
    this.soundEnabled = true,
    this.vibrationEnabled = true,
  });

  AlertConfigEntity copyWith({
    String? userId,
    bool? isEnabled,
    double? deviationThreshold,
    int? countdownSeconds,
    bool? autoEscalate,
    bool? sosEnabled,
    int? sosCountdownSeconds,
    int? inactivityTimeout,
    int? lowBatteryThreshold,
    bool? quietHoursEnabled,
    TimeOfDay? quietHoursStart,
    TimeOfDay? quietHoursEnd,
    bool? soundEnabled,
    bool? vibrationEnabled,
  }) {
    return AlertConfigEntity(
      userId: userId ?? this.userId,
      isEnabled: isEnabled ?? this.isEnabled,
      deviationThreshold: deviationThreshold ?? this.deviationThreshold,
      countdownSeconds: countdownSeconds ?? this.countdownSeconds,
      autoEscalate: autoEscalate ?? this.autoEscalate,
      sosEnabled: sosEnabled ?? this.sosEnabled,
      sosCountdownSeconds: sosCountdownSeconds ?? this.sosCountdownSeconds,
      inactivityTimeout: inactivityTimeout ?? this.inactivityTimeout,
      lowBatteryThreshold: lowBatteryThreshold ?? this.lowBatteryThreshold,
      quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
      quietHoursStart: quietHoursStart ?? this.quietHoursStart,
      quietHoursEnd: quietHoursEnd ?? this.quietHoursEnd,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
    );
  }

  bool isQuietHoursNow() {
    if (!quietHoursEnabled || quietHoursStart == null || quietHoursEnd == null) {
      return false;
    }
    
    final now = TimeOfDay.now();
    final nowMinutes = now.hour * 60 + now.minute;
    final startMinutes = quietHoursStart!.hour * 60 + quietHoursStart!.minute;
    final endMinutes = quietHoursEnd!.hour * 60 + quietHoursEnd!.minute;
    
    if (startMinutes <= endMinutes) {
      return nowMinutes >= startMinutes && nowMinutes <= endMinutes;
    } else {
      return nowMinutes >= startMinutes || nowMinutes <= endMinutes;
    }
  }

  @override
  List<Object?> get props => [
        userId,
        isEnabled,
        deviationThreshold,
        countdownSeconds,
        autoEscalate,
        sosEnabled,
        sosCountdownSeconds,
        inactivityTimeout,
        lowBatteryThreshold,
        quietHoursEnabled,
        quietHoursStart,
        quietHoursEnd,
        soundEnabled,
        vibrationEnabled,
      ];
}
