import 'package:hive/hive.dart';
import 'package:psga_app/features/trips/domain/entities/deviation.dart';
import 'package:psga_app/features/routes/data/models/location_model.dart';

class DeviationAdapter extends TypeAdapter<Deviation> {
  @override
  final int typeId = 6;

  @override
  Deviation read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    
    return Deviation(
      id: fields[0] as String,
      tripId: fields[1] as String,
      type: DeviationType.values[fields[2] as int],
      severity: DeviationSeverity.values[fields[3] as int],
      deviationLocation: fields[4] as LocationModel,
      nearestPointOnRoute: fields[12] as LocationModel? ?? fields[4] as LocationModel,
      distanceFromRoute: fields[5] as double,
      detectedAt: DateTime.parse(fields[6] as String),
      resolvedAt: fields[7] != null ? DateTime.parse(fields[7] as String) : null,
      duration: fields[8] != null ? Duration(seconds: fields[8] as int) : null,
      description: fields[9] as String?,
      waypointId: fields[10] as String?,
      isResolved: fields[11] as bool? ?? false,
    );
  }

  @override
  void write(BinaryWriter writer, Deviation obj) {
    // تحويل Locations إلى LocationModel
    final deviationLoc = obj.deviationLocation is LocationModel
        ? obj.deviationLocation as LocationModel
        : LocationModel.fromEntity(obj.deviationLocation);
    
    // nearestPointOnRoute هو required (غير nullable)
    final nearestLoc = obj.nearestPointOnRoute is LocationModel 
        ? obj.nearestPointOnRoute as LocationModel
        : LocationModel.fromEntity(obj.nearestPointOnRoute);
    
    writer
      ..writeByte(13)
      ..writeByte(0) ..write(obj.id)
      ..writeByte(1) ..write(obj.tripId)
      ..writeByte(2) ..write(obj.type.index)
      ..writeByte(3) ..write(obj.severity.index)
      ..writeByte(4) ..write(deviationLoc)
      ..writeByte(5) ..write(obj.distanceFromRoute)
      ..writeByte(6) ..write(obj.detectedAt.toIso8601String())
      ..writeByte(7) ..write(obj.resolvedAt?.toIso8601String())
      ..writeByte(8) ..write(obj.duration?.inSeconds)
      ..writeByte(9) ..write(obj.description)
      ..writeByte(10) ..write(obj.waypointId)
      ..writeByte(11) ..write(obj.isResolved)
      ..writeByte(12) ..write(nearestLoc);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeviationAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
