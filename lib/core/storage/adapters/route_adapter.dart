import 'package:hive/hive.dart';
import 'package:psga_app/features/routes/data/models/route_model.dart';
import 'package:psga_app/features/routes/data/models/waypoint_model.dart';
import 'package:psga_app/features/routes/domain/entities/route.dart';

/// Hive Type Adapter لـ RouteModel
class RouteModelAdapter extends TypeAdapter<RouteModel> {
  @override
  final int typeId = 3;

  @override
  RouteModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    
    return RouteModel(
      id: fields[0] as String,
      userId: fields[1] as String,
      name: fields[2] as String,
      description: fields[3] as String?,
      waypoints: (fields[4] as List).cast<WaypointModel>(),
      createdAt: DateTime.parse(fields[5] as String),
      updatedAt: DateTime.parse(fields[6] as String),
      status: RouteStatus.values[fields[7] as int? ?? 0],
      isFavorite: fields[8] as bool? ?? false,
      estimatedDistance: fields[9] as double?,
      estimatedDuration: fields[10] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, RouteModel obj) {
    // تحويل Waypoints إلى WaypointModel للكتابة
    final waypointModels = obj.waypoints
        .map((w) => w is WaypointModel ? w : WaypointModel.fromEntity(w))
        .toList();
    
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.userId)
      ..writeByte(2)
      ..write(obj.name)
      ..writeByte(3)
      ..write(obj.description)
      ..writeByte(4)
      ..write(waypointModels)
      ..writeByte(5)
      ..write(obj.createdAt.toIso8601String())
      ..writeByte(6)
      ..write(obj.updatedAt.toIso8601String())
      ..writeByte(7)
      ..write(obj.status.index)
      ..writeByte(8)
      ..write(obj.isFavorite)
      ..writeByte(9)
      ..write(obj.estimatedDistance)
      ..writeByte(10)
      ..write(obj.estimatedDuration);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RouteModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
