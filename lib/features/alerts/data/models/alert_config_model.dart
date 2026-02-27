import 'package:flutter/material.dart';
import 'package:psga_app/features/alerts/domain/entities/alert_config_entity.dart';
import 'package:psga_app/features/alerts/domain/entities/alert_entity.dart';

/// نموذج إعدادات نوع التنبيه
class AlertTypeConfigModel extends AlertTypeConfig {
  const AlertTypeConfigModel({
    required super.type,
    super.enabled,
    super.defaultSeverity,
    super.escalationThreshold,
    super.autoEscalate,
    super.sendSMS,
    super.sendEmail,
    super.sendPushNotification,
    super.playSoundAlert,
    super.vibrateAlert,
  });

  factory AlertTypeConfigModel.fromJson(Map<String, dynamic> json) {
    return AlertTypeConfigModel(
      type: AlertType.values.firstWhere(
        (e) => e.toString() == 'AlertType.${json['type']}',
      ),
      enabled: json['enabled'] as bool? ?? true,
      defaultSeverity: AlertSeverity.values.firstWhere(
        (e) => e.toString() == 'AlertSeverity.${json['defaultSeverity']}',
        orElse: () => AlertSeverity.medium,
      ),
      escalationThreshold: Duration(
        milliseconds: json['escalationThresholdMs'] as int? ?? 300000,
      ),
      autoEscalate: json['autoEscalate'] as bool? ?? true,
      sendSMS: json['sendSMS'] as bool? ?? true,
      sendEmail: json['sendEmail'] as bool? ?? false,
      sendPushNotification: json['sendPushNotification'] as bool? ?? true,
      playSoundAlert: json['playSoundAlert'] as bool? ?? true,
      vibrateAlert: json['vibrateAlert'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.toString().split('.').last,
      'enabled': enabled,
      'defaultSeverity': defaultSeverity.toString().split('.').last,
      'escalationThresholdMs': escalationThreshold.inMilliseconds,
      'autoEscalate': autoEscalate,
      'sendSMS': sendSMS,
      'sendEmail': sendEmail,
      'sendPushNotification': sendPushNotification,
      'playSoundAlert': playSoundAlert,
      'vibrateAlert': vibrateAlert,
    };
  }
}

/// نموذج إعدادات التنبيهات
class AlertConfigModel extends AlertConfigEntity {
  const AlertConfigModel({
    required super.id,
    required super.userId,
    required super.createdAt,
    super.globalEnabled,
    super.typeConfigs,
    super.maxEscalationLevel,
    super.escalationInterval,
    super.requireAcknowledgment,
    super.autoResolveOnAcknowledge,
    super.countdownDuration,
    super.enableQuietHours,
    super.quietHoursStart,
    super.quietHoursEnd,
    super.sendDuringQuietHours,
    super.updatedAt,
  });

  factory AlertConfigModel.fromJson(Map<String, dynamic> json) {
    return AlertConfigModel(
      id: json['id'] as String,
      userId: json['userId'] as String,
      globalEnabled: json['globalEnabled'] as bool? ?? true,
      typeConfigs: json['typeConfigs'] != null
          ? (json['typeConfigs'] as List)
              .map((e) => AlertTypeConfigModel.fromJson(e as Map<String, dynamic>))
              .toList()
          : const [],
      maxEscalationLevel: json['maxEscalationLevel'] as int? ?? 3,
      escalationInterval: Duration(
        milliseconds: json['escalationIntervalMs'] as int? ?? 300000,
      ),
      requireAcknowledgment: json['requireAcknowledgment'] as bool? ?? true,
      autoResolveOnAcknowledge: json['autoResolveOnAcknowledge'] as bool? ?? false,
      countdownDuration: Duration(
        milliseconds: json['countdownDurationMs'] as int? ?? 30000,
      ),
      enableQuietHours: json['enableQuietHours'] as bool? ?? false,
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
      sendDuringQuietHours: json['sendDuringQuietHours'] as bool? ?? true,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'globalEnabled': globalEnabled,
      'typeConfigs': typeConfigs
          .map((e) => AlertTypeConfigModel(
                type: e.type,
                enabled: e.enabled,
                defaultSeverity: e.defaultSeverity,
                escalationThreshold: e.escalationThreshold,
                autoEscalate: e.autoEscalate,
                sendSMS: e.sendSMS,
                sendEmail: e.sendEmail,
                sendPushNotification: e.sendPushNotification,
                playSoundAlert: e.playSoundAlert,
                vibrateAlert: e.vibrateAlert,
              ).toJson())
          .toList(),
      'maxEscalationLevel': maxEscalationLevel,
      'escalationIntervalMs': escalationInterval.inMilliseconds,
      'requireAcknowledgment': requireAcknowledgment,
      'autoResolveOnAcknowledge': autoResolveOnAcknowledge,
      'countdownDurationMs': countdownDuration.inMilliseconds,
      'enableQuietHours': enableQuietHours,
      'quietHoursStart': quietHoursStart != null
          ? {'hour': quietHoursStart!.hour, 'minute': quietHoursStart!.minute}
          : null,
      'quietHoursEnd': quietHoursEnd != null
          ? {'hour': quietHoursEnd!.hour, 'minute': quietHoursEnd!.minute}
          : null,
      'sendDuringQuietHours': sendDuringQuietHours,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory AlertConfigModel.fromEntity(AlertConfigEntity entity) {
    return AlertConfigModel(
      id: entity.id,
      userId: entity.userId,
      createdAt: entity.createdAt,
      globalEnabled: entity.globalEnabled,
      typeConfigs: entity.typeConfigs,
      maxEscalationLevel: entity.maxEscalationLevel,
      escalationInterval: entity.escalationInterval,
      requireAcknowledgment: entity.requireAcknowledgment,
      autoResolveOnAcknowledge: entity.autoResolveOnAcknowledge,
      countdownDuration: entity.countdownDuration,
      enableQuietHours: entity.enableQuietHours,
      quietHoursStart: entity.quietHoursStart,
      quietHoursEnd: entity.quietHoursEnd,
      sendDuringQuietHours: entity.sendDuringQuietHours,
      updatedAt: entity.updatedAt,
    );
  }

  AlertConfigEntity toEntity() => this;

  /// إنشاء إعدادات افتراضية للمستخدم
  /// 
  /// يتم استدعاء هذه الدالة عندما يفتح المستخدم إعدادات التنبيهات لأول مرة
  /// وليس لديه إعدادات محفوظة مسبقاً
  factory AlertConfigModel.createDefault(String userId) {
    final now = DateTime.now();
    
    // إنشاء إعدادات افتراضية لجميع أنواع التنبيهات
    final defaultTypeConfigs = AlertType.values.map((type) {
      // إعدادات خاصة لكل نوع
      switch (type) {
        case AlertType.sos:
          // SOS: أعلى أولوية وأسرع تصعيد
          return AlertTypeConfigModel(
            type: type,
            enabled: true,
            defaultSeverity: AlertSeverity.critical,
            escalationThreshold: const Duration(seconds: 10),
            autoEscalate: true,
            sendSMS: true,
            sendEmail: true,
            sendPushNotification: true,
            playSoundAlert: true,
            vibrateAlert: true,
          );
        
        case AlertType.deviation:
          // الانحراف: مدة عد تنازلي 30 ثانية
          return AlertTypeConfigModel(
            type: type,
            enabled: true,
            defaultSeverity: AlertSeverity.high,
            escalationThreshold: const Duration(seconds: 30),
            autoEscalate: true,
            sendSMS: true,
            sendEmail: false,
            sendPushNotification: true,
            playSoundAlert: true,
            vibrateAlert: true,
          );
        
        case AlertType.checkpoint:
          // نقطة تفتيش: أقل أولوية
          return AlertTypeConfigModel(
            type: type,
            enabled: true,
            defaultSeverity: AlertSeverity.medium,
            escalationThreshold: const Duration(minutes: 5),
            autoEscalate: false,
            sendSMS: false,
            sendEmail: false,
            sendPushNotification: true,
            playSoundAlert: false,
            vibrateAlert: false,
          );
        
        case AlertType.speedLimit:
          // تجاوز السرعة: أولوية عالية
          return AlertTypeConfigModel(
            type: type,
            enabled: true,
            defaultSeverity: AlertSeverity.high,
            escalationThreshold: const Duration(minutes: 2),
            autoEscalate: true,
            sendSMS: false,
            sendEmail: false,
            sendPushNotification: true,
            playSoundAlert: true,
            vibrateAlert: true,
          );
        
        case AlertType.lowBattery:
          // بطارية منخفضة: تنبيه بسيط
          return AlertTypeConfigModel(
            type: type,
            enabled: true,
            defaultSeverity: AlertSeverity.low,
            escalationThreshold: const Duration(minutes: 10),
            autoEscalate: false,
            sendSMS: false,
            sendEmail: false,
            sendPushNotification: true,
            playSoundAlert: false,
            vibrateAlert: false,
          );
        
        case AlertType.noMovement:
          // عدم حركة: أولوية متوسطة
          return AlertTypeConfigModel(
            type: type,
            enabled: true,
            defaultSeverity: AlertSeverity.medium,
            escalationThreshold: const Duration(minutes: 5),
            autoEscalate: true,
            sendSMS: true,
            sendEmail: false,
            sendPushNotification: true,
            playSoundAlert: true,
            vibrateAlert: true,
          );
        
        case AlertType.geofence:
          // خروج من منطقة: أولوية عالية
          return AlertTypeConfigModel(
            type: type,
            enabled: true,
            defaultSeverity: AlertSeverity.high,
            escalationThreshold: const Duration(minutes: 3),
            autoEscalate: true,
            sendSMS: true,
            sendEmail: false,
            sendPushNotification: true,
            playSoundAlert: true,
            vibrateAlert: true,
          );
        
        case AlertType.custom:
          // مخصص: إعدادات متوسطة
          return AlertTypeConfigModel(
            type: type,
            enabled: true,
            defaultSeverity: AlertSeverity.medium,
            escalationThreshold: const Duration(minutes: 5),
            autoEscalate: true,
            sendSMS: true,
            sendEmail: false,
            sendPushNotification: true,
            playSoundAlert: true,
            vibrateAlert: true,
          );
      }
    }).toList();
    
    return AlertConfigModel(
      id: '${userId}_config',
      userId: userId,
      globalEnabled: true,
      typeConfigs: defaultTypeConfigs,
      maxEscalationLevel: 3,
      escalationInterval: const Duration(minutes: 5),
      requireAcknowledgment: true,
      autoResolveOnAcknowledge: false,
      countdownDuration: const Duration(seconds: 30),
      enableQuietHours: false,
      quietHoursStart: const TimeOfDay(hour: 22, minute: 0), // 10 PM
      quietHoursEnd: const TimeOfDay(hour: 7, minute: 0),    // 7 AM
      sendDuringQuietHours: true, // للطوارئ دائماً
      createdAt: now,
      updatedAt: now,
    );
  }
}
