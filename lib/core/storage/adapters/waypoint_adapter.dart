import 'package:hive/hive.dart';
import 'package:psga_app/features/routes/data/models/waypoint_model.dart';
import 'package:psga_app/features/routes/data/models/location_model.dart';

/// Hive Type Adapter لـ WaypointModel
class WaypointModelAdapter extends TypeAdapter<WaypointModel> {
  @override
  final int typeId = 2;

  @override
  WaypointModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    
    return WaypointModel(
      id: fields[0] as String,
      name: fields[1] as String,
      location: fields[2] as LocationModel,
      order: fields[3] as int,
      createdAt: DateTime.parse(fields[4] as String),
      description: fields[5] as String?,
      radius: fields[6] as double?,
      isCheckpoint: fields[7] as bool? ?? false,
    );
  }

  @override
  void write(BinaryWriter writer, WaypointModel obj) {
    // تحويل Location إلى LocationModel للكتابة
    final locationModel = obj.location is LocationModel 
        ? obj.location as LocationModel
        : LocationModel.fromEntity(obj.location);
    
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(locationModel)
      ..writeByte(3)
      ..write(obj.order)
      ..writeByte(4)
      ..write(obj.createdAt.toIso8601String())
      ..writeByte(5)
      ..write(obj.description)
      ..writeByte(6)
      ..write(obj.radius)
      ..writeByte(7)
      ..write(obj.isCheckpoint);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WaypointModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
