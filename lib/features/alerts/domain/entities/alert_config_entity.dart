import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:psga_app/features/alerts/domain/entities/alert_entity.dart';

/// إعدادات التنبيه لنوع معين
class AlertTypeConfig extends Equatable {
  final AlertType type;
  final bool enabled;
  final AlertSeverity defaultSeverity;
  final Duration escalationThreshold;
  final bool autoEscalate;
  final bool sendSMS;
  final bool sendEmail;
  final bool sendPushNotification;
  final bool playSoundAlert;
  final bool vibrateAlert;

  const AlertTypeConfig({
    required this.type,
    this.enabled = true,
    this.defaultSeverity = AlertSeverity.medium,
    this.escalationThreshold = const Duration(minutes: 5),
    this.autoEscalate = true,
    this.sendSMS = true,
    this.sendEmail = false,
    this.sendPushNotification = true,
    this.playSoundAlert = true,
    this.vibrateAlert = true,
  });

  @override
  List<Object?> get props => [
        type,
        enabled,
        defaultSeverity,
        escalationThreshold,
        autoEscalate,
        sendSMS,
        sendEmail,
        sendPushNotification,
        playSoundAlert,
        vibrateAlert,
      ];

  AlertTypeConfig copyWith({
    AlertType? type,
    bool? enabled,
    AlertSeverity? defaultSeverity,
    Duration? escalationThreshold,
    bool? autoEscalate,
    bool? sendSMS,
    bool? sendEmail,
    bool? sendPushNotification,
    bool? playSoundAlert,
    bool? vibrateAlert,
  }) {
    return AlertTypeConfig(
      type: type ?? this.type,
      enabled: enabled ?? this.enabled,
      defaultSeverity: defaultSeverity ?? this.defaultSeverity,
      escalationThreshold: escalationThreshold ?? this.escalationThreshold,
      autoEscalate: autoEscalate ?? this.autoEscalate,
      sendSMS: sendSMS ?? this.sendSMS,
      sendEmail: sendEmail ?? this.sendEmail,
      sendPushNotification: sendPushNotification ?? this.sendPushNotification,
      playSoundAlert: playSoundAlert ?? this.playSoundAlert,
      vibrateAlert: vibrateAlert ?? this.vibrateAlert,
    );
  }
}

/// كيان إعدادات التنبيهات
class AlertConfigEntity extends Equatable {
  final String id;
  final String userId;
  final bool globalEnabled;
  final List<AlertTypeConfig> typeConfigs;
  final int maxEscalationLevel;
  final Duration escalationInterval;
  final bool requireAcknowledgment;
  final bool autoResolveOnAcknowledge;
  
  // إعدادات التنبيهات
  final Duration countdownDuration;         // مدة العد التنازلي للتنبيه
  final bool enableQuietHours;              // تفعيل ساعات الهدوء
  final TimeOfDay? quietHoursStart;         // بداية ساعات الهدوء
  final TimeOfDay? quietHoursEnd;           // نهاية ساعات الهدوء
  final bool sendDuringQuietHours;          // الإرسال خلال ساعات الهدوء (للطوارئ)
  
  final DateTime createdAt;
  final DateTime? updatedAt;

  const AlertConfigEntity({
    required this.id,
    required this.userId,
    required this.createdAt,
    this.globalEnabled = true,
    this.typeConfigs = const [],
    this.maxEscalationLevel = 3,
    this.escalationInterval = const Duration(minutes: 5),
    this.requireAcknowledgment = true,
    this.autoResolveOnAcknowledge = false,
    this.countdownDuration = const Duration(seconds: 30),
    this.enableQuietHours = false,
    this.quietHoursStart,
    this.quietHoursEnd,
    this.sendDuringQuietHours = true, // للطوارئ دائماً
    this.updatedAt,
  });

  @override
  List<Object?> get props => [
        id,
        userId,
        globalEnabled,
        typeConfigs,
        maxEscalationLevel,
        escalationInterval,
        requireAcknowledgment,
        autoResolveOnAcknowledge,
        countdownDuration,
        enableQuietHours,
        quietHoursStart,
        quietHoursEnd,
        sendDuringQuietHours,
        createdAt,
        updatedAt,
      ];

  /// الحصول على إعدادات نوع تنبيه معين
  AlertTypeConfig? getConfigForType(AlertType type) {
    try {
      return typeConfigs.firstWhere((config) => config.type == type);
    } catch (e) {
      return null;
    }
  }

  /// هل نوع التنبيه مفعّل؟
  bool isTypeEnabled(AlertType type) {
    if (!globalEnabled) return false;
    final config = getConfigForType(type);
    return config?.enabled ?? false;
  }

  /// هل نحن في ساعات الهدوء؟
  bool isInQuietHours() {
    if (!enableQuietHours || quietHoursStart == null || quietHoursEnd == null) {
      return false;
    }

    final now = TimeOfDay.now();
    final start = quietHoursStart!;
    final end = quietHoursEnd!;

    // تحويل لدقائق للمقارنة
    final nowMinutes = now.hour * 60 + now.minute;
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;

    // إذا كانت الفترة تعبر منتصف الليل
    if (startMinutes > endMinutes) {
      return nowMinutes >= startMinutes || nowMinutes < endMinutes;
    } else {
      return nowMinutes >= startMinutes && nowMinutes < endMinutes;
    }
  }

  /// هل يجب إرسال التنبيه (مع مراعاة ساعات الهدوء)
  bool shouldSendAlert(AlertType type) {
    if (!isTypeEnabled(type)) return false;

    // الطوارئ SOS دائماً تُرسل
    if (type == AlertType.sos) return true;

    // إذا مفعّل الإرسال خلال ساعات الهدوء
    if (sendDuringQuietHours) return true;

    // إذا لسنا في ساعات الهدوء
    if (!isInQuietHours()) return true;

    // في ساعات الهدوء ولا يُسمح بالإرسال
    return false;
  }

  /// نسخ مع تعديلات
  AlertConfigEntity copyWith({
    String? id,
    String? userId,
    bool? globalEnabled,
    List<AlertTypeConfig>? typeConfigs,
    int? maxEscalationLevel,
    Duration? escalationInterval,
    bool? requireAcknowledgment,
    bool? autoResolveOnAcknowledge,
    Duration? countdownDuration,
    bool? enableQuietHours,
    TimeOfDay? quietHoursStart,
    TimeOfDay? quietHoursEnd,
    bool? sendDuringQuietHours,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AlertConfigEntity(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      globalEnabled: globalEnabled ?? this.globalEnabled,
      typeConfigs: typeConfigs ?? this.typeConfigs,
      maxEscalationLevel: maxEscalationLevel ?? this.maxEscalationLevel,
      escalationInterval: escalationInterval ?? this.escalationInterval,
      requireAcknowledgment: requireAcknowledgment ?? this.requireAcknowledgment,
      autoResolveOnAcknowledge: autoResolveOnAcknowledge ?? this.autoResolveOnAcknowledge,
      countdownDuration: countdownDuration ?? this.countdownDuration,
      enableQuietHours: enableQuietHours ?? this.enableQuietHours,
      quietHoursStart: quietHoursStart ?? this.quietHoursStart,
      quietHoursEnd: quietHoursEnd ?? this.quietHoursEnd,
      sendDuringQuietHours: sendDuringQuietHours ?? this.sendDuringQuietHours,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// إعدادات افتراضية
  static AlertConfigEntity defaultConfig(String userId) {
    return AlertConfigEntity(
      id: '${userId}_config',
      userId: userId,
      globalEnabled: true,
      countdownDuration: const Duration(seconds: 30),
      enableQuietHours: false,
      quietHoursStart: const TimeOfDay(hour: 22, minute: 0), // 10 PM
      quietHoursEnd: const TimeOfDay(hour: 7, minute: 0),    // 7 AM
      sendDuringQuietHours: true, // SOS يُرسل دائماً
      typeConfigs: const [
        AlertTypeConfig(
          type: AlertType.sos,
          enabled: true,
          defaultSeverity: AlertSeverity.critical,
          escalationThreshold: Duration(seconds: 5), // SOS سريع جداً
          autoEscalate: true,
          sendSMS: true,
          sendEmail: true,
          sendPushNotification: true,
          playSoundAlert: true,
          vibrateAlert: true,
        ),
        AlertTypeConfig(
          type: AlertType.deviation,
          enabled: true,
          defaultSeverity: AlertSeverity.high,
          escalationThreshold: Duration(seconds: 30),
          autoEscalate: true,
          sendSMS: true,
          sendPushNotification: true,
          playSoundAlert: true,
          vibrateAlert: true,
        ),
        AlertTypeConfig(
          type: AlertType.checkpoint,
          enabled: true,
          defaultSeverity: AlertSeverity.medium,
          autoEscalate: false,
          sendSMS: false,
        ),
        AlertTypeConfig(
          type: AlertType.speedLimit,
          enabled: true,
          defaultSeverity: AlertSeverity.medium,
          autoEscalate: false,
          sendSMS: false,
        ),
        AlertTypeConfig(
          type: AlertType.lowBattery,
          enabled: true,
          defaultSeverity: AlertSeverity.low,
          escalationThreshold: Duration(minutes: 5),
          autoEscalate: false,
          sendSMS: false,
          sendPushNotification: true,
          playSoundAlert: false,
          vibrateAlert: false,
        ),
        AlertTypeConfig(
          type: AlertType.noMovement,
          enabled: true,
          defaultSeverity: AlertSeverity.high,
          escalationThreshold: Duration(minutes: 10),
          autoEscalate: true,
          sendSMS: true,
          playSoundAlert: true,
          vibrateAlert: true,
        ),
        AlertTypeConfig(
          type: AlertType.geofence,
          enabled: false,
          defaultSeverity: AlertSeverity.medium,
          autoEscalate: false,
        ),
      ],
      createdAt: DateTime.now(),
    );
  }
}
