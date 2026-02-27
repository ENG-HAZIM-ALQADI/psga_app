import 'package:hive/hive.dart';
import 'package:flutter/material.dart';
import 'package:psga_app/features/alerts/data/models/alert_config_model.dart';
import 'package:psga_app/features/alerts/domain/entities/alert_config_entity.dart';
import 'package:psga_app/features/alerts/domain/entities/alert_entity.dart';

/// Hive TypeAdapter لـ AlertConfigModel
/// TypeId: 7
class AlertConfigModelAdapter extends TypeAdapter<AlertConfigModel> {
  @override
  final int typeId = 7;

  @override
  AlertConfigModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };

    // قراءة typeConfigs
    final typeConfigsList = (fields[4] as List?)?.cast<Map<dynamic, dynamic>>() ?? [];
    final typeConfigs = typeConfigsList.map((config) {
      return AlertTypeConfig(
        type: AlertType.values[config['type'] as int],
        enabled: config['enabled'] as bool? ?? true,
        defaultSeverity: AlertSeverity.values[config['defaultSeverity'] as int],
        escalationThreshold: Duration(milliseconds: config['escalationThresholdMs'] as int),
        autoEscalate: config['autoEscalate'] as bool? ?? true,
        sendSMS: config['sendSMS'] as bool? ?? true,
        sendEmail: config['sendEmail'] as bool? ?? false,
        sendPushNotification: config['sendPushNotification'] as bool? ?? true,
        playSoundAlert: config['playSoundAlert'] as bool? ?? true,
        vibrateAlert: config['vibrateAlert'] as bool? ?? true,
      );
    }).toList();

    return AlertConfigModel(
      id: fields[0] as String,
      userId: fields[1] as String,
      createdAt: fields[2] as DateTime,
      globalEnabled: fields[3] as bool? ?? true,
      typeConfigs: typeConfigs,
      maxEscalationLevel: fields[5] as int? ?? 3,
      escalationInterval: Duration(milliseconds: fields[6] as int? ?? 300000),
      requireAcknowledgment: fields[7] as bool? ?? true,
      autoResolveOnAcknowledge: fields[8] as bool? ?? false,
      countdownDuration: Duration(milliseconds: fields[9] as int? ?? 30000),
      // field[10] was deviationThresholdMeters - removed, now in TripSettings
      enableQuietHours: fields[11] as bool? ?? false,
      quietHoursStart: fields[12] != null
          ? TimeOfDay(
              hour: (fields[12] as Map)['hour'] as int,
              minute: (fields[12] as Map)['minute'] as int,
            )
          : null,
      quietHoursEnd: fields[13] != null
          ? TimeOfDay(
              hour: (fields[13] as Map)['hour'] as int,
              minute: (fields[13] as Map)['minute'] as int,
            )
          : null,
      sendDuringQuietHours: fields[14] as bool? ?? true,
      updatedAt: fields[15] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, AlertConfigModel obj) {
    writer
      ..writeByte(15) // number of fields (was 16, now 15)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.userId)
      ..writeByte(2)
      ..write(obj.createdAt)
      ..writeByte(3)
      ..write(obj.globalEnabled)
      ..writeByte(4)
      ..write(obj.typeConfigs.map((config) => {
            'type': config.type.index,
            'enabled': config.enabled,
            'defaultSeverity': config.defaultSeverity.index,
            'escalationThresholdMs': config.escalationThreshold.inMilliseconds,
            'autoEscalate': config.autoEscalate,
            'sendSMS': config.sendSMS,
            'sendEmail': config.sendEmail,
            'sendPushNotification': config.sendPushNotification,
            'playSoundAlert': config.playSoundAlert,
            'vibrateAlert': config.vibrateAlert,
          }).toList())
      ..writeByte(5)
      ..write(obj.maxEscalationLevel)
      ..writeByte(6)
      ..write(obj.escalationInterval.inMilliseconds)
      ..writeByte(7)
      ..write(obj.requireAcknowledgment)
      ..writeByte(8)
      ..write(obj.autoResolveOnAcknowledge)
      ..writeByte(9)
      ..write(obj.countdownDuration.inMilliseconds)
      // field[10] (deviationThresholdMeters) removed - now in TripSettings
      ..writeByte(11)
      ..write(obj.enableQuietHours)
      ..writeByte(12)
      ..write(obj.quietHoursStart != null
          ? {'hour': obj.quietHoursStart!.hour, 'minute': obj.quietHoursStart!.minute}
          : null)
      ..writeByte(13)
      ..write(obj.quietHoursEnd != null
          ? {'hour': obj.quietHoursEnd!.hour, 'minute': obj.quietHoursEnd!.minute}
          : null)
      ..writeByte(14)
      ..write(obj.sendDuringQuietHours)
      ..writeByte(15)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AlertConfigModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
