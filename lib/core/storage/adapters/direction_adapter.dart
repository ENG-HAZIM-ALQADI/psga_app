import 'package:hive/hive.dart';
import 'package:psga_app/features/maps/domain/entities/direction_entity.dart';
import 'package:psga_app/features/routes/domain/entities/location.dart';

/// Hive Adapter لتخزين DirectionEntity
class DirectionAdapter extends TypeAdapter<DirectionEntity> {
  @override
  final int typeId = 20; // معرف فريد

  @override
  DirectionEntity read(BinaryReader reader) {
    final id = reader.readString();
    final originLat = reader.readDouble();
    final originLon = reader.readDouble();
    final destLat = reader.readDouble();
    final destLon = reader.readDouble();
    final totalDistance = reader.readString();
    final totalDuration = reader.readString();
    final totalDistanceValue = reader.readDouble();
    final totalDurationValue = reader.readInt();
    final polyline = reader.readString();
    
    // قراءة polylinePoints
    final pointsCount = reader.readInt();
    final polylinePoints = <Location>[];
    for (int i = 0; i < pointsCount; i++) {
      final lat = reader.readDouble();
      final lon = reader.readDouble();
      polylinePoints.add(Location(
        latitude: lat,
        longitude: lon,
        timestamp: DateTime.now(),
      ));
    }
    
    final warnings = reader.readString();
    final copyrights = reader.readString();

    return DirectionEntity(
      id: id,
      origin: Location(
        latitude: originLat,
        longitude: originLon,
        timestamp: DateTime.now(),
      ),
      destination: Location(
        latitude: destLat,
        longitude: destLon,
        timestamp: DateTime.now(),
      ),
      steps: const [], // تبسيط - يمكن إضافة Steps لاحقاً
      totalDistance: totalDistance,
      totalDuration: totalDuration,
      totalDistanceValue: totalDistanceValue,
      totalDurationValue: totalDurationValue,
      polyline: polyline,
      polylinePoints: polylinePoints,
      warnings: warnings.isEmpty ? null : warnings,
      copyrights: copyrights.isEmpty ? null : copyrights,
    );
  }

  @override
  void write(BinaryWriter writer, DirectionEntity obj) {
    writer.writeString(obj.id);
    writer.writeDouble(obj.origin.latitude);
    writer.writeDouble(obj.origin.longitude);
    writer.writeDouble(obj.destination.latitude);
    writer.writeDouble(obj.destination.longitude);
    writer.writeString(obj.totalDistance);
    writer.writeString(obj.totalDuration);
    writer.writeDouble(obj.totalDistanceValue);
    writer.writeInt(obj.totalDurationValue);
    writer.writeString(obj.polyline);
    
    // كتابة polylinePoints
    writer.writeInt(obj.polylinePoints.length);
    for (final point in obj.polylinePoints) {
      writer.writeDouble(point.latitude);
      writer.writeDouble(point.longitude);
    }
    
    writer.writeString(obj.warnings ?? '');
    writer.writeString(obj.copyrights ?? '');
  }
}
