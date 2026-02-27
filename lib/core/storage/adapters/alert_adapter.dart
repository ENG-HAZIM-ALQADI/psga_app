import 'package:hive/hive.dart';
import 'package:psga_app/features/alerts/data/models/alert_model.dart';
import 'package:psga_app/features/alerts/domain/entities/alert_entity.dart';
import 'package:psga_app/features/routes/data/models/location_model.dart';

class AlertModelAdapter extends TypeAdapter<AlertModel> {
  @override
  final int typeId = 4;

  @override
  AlertModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    
    return AlertModel(
      id: fields[0] as String,
      userId: fields[1] as String,
      tripId: fields[2] as String?,
      type: AlertType.values[fields[3] as int],
      severity: AlertSeverity.values[fields[4] as int],
      status: AlertStatus.values[fields[5] as int],
      title: fields[6] as String,
      message: fields[7] as String,
      location: fields[8] as LocationModel?,
      triggeredAt: DateTime.parse(fields[9] as String),
      acknowledgedAt: fields[10] != null ? DateTime.parse(fields[10] as String) : null,
      resolvedAt: fields[11] != null ? DateTime.parse(fields[11] as String) : null,
      acknowledgedBy: fields[12] as String?,
      metadata: fields[13] != null ? Map<String, dynamic>.from(fields[13] as Map) : null,
      notifiedContacts: fields[14] != null ? List<String>.from(fields[14] as List) : const [],
      isSent: fields[15] as bool? ?? false,
      isEscalated: fields[16] as bool? ?? false,
      escalationLevel: fields[17] as int? ?? 0,
    );
  }

  @override
  void write(BinaryWriter writer, AlertModel obj) {
    // تحويل Location إلى LocationModel
    final locationModel = obj.location != null
        ? (obj.location is LocationModel 
            ? obj.location 
            : LocationModel.fromEntity(obj.location!))
        : null;
    
    writer
      ..writeByte(18)
      ..writeByte(0) ..write(obj.id)
      ..writeByte(1) ..write(obj.userId)
      ..writeByte(2) ..write(obj.tripId)
      ..writeByte(3) ..write(obj.type.index)
      ..writeByte(4) ..write(obj.severity.index)
      ..writeByte(5) ..write(obj.status.index)
      ..writeByte(6) ..write(obj.title)
      ..writeByte(7) ..write(obj.message)
      ..writeByte(8) ..write(locationModel)
      ..writeByte(9) ..write(obj.triggeredAt.toIso8601String())
      ..writeByte(10) ..write(obj.acknowledgedAt?.toIso8601String())
      ..writeByte(11) ..write(obj.resolvedAt?.toIso8601String())
      ..writeByte(12) ..write(obj.acknowledgedBy)
      ..writeByte(13) ..write(obj.metadata)
      ..writeByte(14) ..write(obj.notifiedContacts)
      ..writeByte(15) ..write(obj.isSent)
      ..writeByte(16) ..write(obj.isEscalated)
      ..writeByte(17) ..write(obj.escalationLevel);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AlertModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
