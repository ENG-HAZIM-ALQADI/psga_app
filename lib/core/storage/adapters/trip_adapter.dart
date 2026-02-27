import 'package:hive/hive.dart';
import 'package:psga_app/features/trips/data/models/trip_model.dart';
import 'package:psga_app/features/trips/domain/entities/trip_entity.dart';
import 'package:psga_app/features/routes/data/models/route_model.dart';
import 'package:psga_app/features/routes/data/models/location_model.dart';
import 'package:psga_app/features/trips/data/models/deviation_model.dart';

class TripModelAdapter extends TypeAdapter<TripModel> {
  @override
  final int typeId = 8; // تأكد من عدم تضارب typeId

  @override
  TripModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };

    return TripModel(
      id: fields[0] as String,
      userId: fields[1] as String,
      routeId: fields[2] as String,
      route: fields[3] as RouteModel,
      status: TripStatus.values[fields[4] as int],
      startTime: DateTime.parse(fields[5] as String),
      endTime: fields[6] != null ? DateTime.parse(fields[6] as String) : null,
      pausedAt: fields[7] != null ? DateTime.parse(fields[7] as String) : null,
      totalPausedDuration: fields[8] != null 
          ? Duration(seconds: fields[8] as int) 
          : Duration.zero,
      distanceTraveled: (fields[9] as num?)?.toDouble() ?? 0.0,
      locationHistory: fields[10] != null 
          ? (fields[10] as List).cast<LocationModel>() 
          : const [],
      visitedWaypointIds: fields[11] != null 
          ? (fields[11] as List).cast<String>() 
          : const [],
      missedWaypointIds: fields[12] != null 
          ? (fields[12] as List).cast<String>() 
          : const [],
      currentWaypointIndex: fields[13] as int? ?? 0,
      deviations: fields[14] != null 
          ? (fields[14] as List).cast<DeviationModel>() 
          : const [],
      totalDeviations: fields[15] as int? ?? 0,
      averageSpeed: (fields[16] as num?)?.toDouble(),
      maxSpeed: (fields[17] as num?)?.toDouble(),
      currentLocation: fields[18] as LocationModel?,
      lastKnownLocation: fields[19] as LocationModel?,
    );
  }

  @override
  void write(BinaryWriter writer, TripModel obj) {
    // تحويل Route إلى RouteModel
    final routeModel = obj.route is RouteModel
        ? obj.route as RouteModel
        : RouteModel.fromEntity(obj.route);
    
    // تحويل Location History إلى LocationModel
    final locationModels = obj.locationHistory
        .map((loc) => loc is LocationModel ? loc : LocationModel.fromEntity(loc))
        .toList();
    
    // تحويل Current و Last Location
    final currentLoc = obj.currentLocation != null
        ? (obj.currentLocation is LocationModel 
            ? obj.currentLocation 
            : LocationModel.fromEntity(obj.currentLocation!))
        : null;
        
    final lastLoc = obj.lastKnownLocation != null
        ? (obj.lastKnownLocation is LocationModel 
            ? obj.lastKnownLocation 
            : LocationModel.fromEntity(obj.lastKnownLocation!))
        : null;
    
    writer
      ..writeByte(20) // عدد الحقول
      ..writeByte(0) ..write(obj.id)
      ..writeByte(1) ..write(obj.userId)
      ..writeByte(2) ..write(obj.routeId)
      ..writeByte(3) ..write(routeModel)
      ..writeByte(4) ..write(obj.status.index)
      ..writeByte(5) ..write(obj.startTime.toIso8601String())
      ..writeByte(6) ..write(obj.endTime?.toIso8601String())
      ..writeByte(7) ..write(obj.pausedAt?.toIso8601String())
      ..writeByte(8) ..write(obj.totalPausedDuration.inSeconds)
      ..writeByte(9) ..write(obj.distanceTraveled)
      ..writeByte(10) ..write(locationModels.isNotEmpty ? locationModels : null)
      ..writeByte(11) ..write(obj.visitedWaypointIds.isNotEmpty ? obj.visitedWaypointIds : null)
      ..writeByte(12) ..write(obj.missedWaypointIds.isNotEmpty ? obj.missedWaypointIds : null)
      ..writeByte(13) ..write(obj.currentWaypointIndex)
      ..writeByte(14) ..write(obj.deviations.isNotEmpty ? obj.deviations : null)
      ..writeByte(15) ..write(obj.totalDeviations)
      ..writeByte(16) ..write(obj.averageSpeed)
      ..writeByte(17) ..write(obj.maxSpeed)
      ..writeByte(18) ..write(currentLoc)
      ..writeByte(19) ..write(lastLoc);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TripModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
