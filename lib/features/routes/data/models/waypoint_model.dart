import 'package:psga_app/features/routes/data/models/location_model.dart';
import 'package:psga_app/features/routes/domain/entities/waypoint.dart';

class WaypointModel extends Waypoint {
  const WaypointModel({
    required super.id,
    required super.name,
    required super.location,
    required super.order,
    required super.createdAt,
    super.description,
    super.radius,
    super.isCheckpoint,
  });

  factory WaypointModel.fromEntity(Waypoint entity) {
    return WaypointModel(
      id: entity.id,
      name: entity.name,
      location: entity.location,
      order: entity.order,
      createdAt: entity.createdAt,
      description: entity.description,
      radius: entity.radius,
      isCheckpoint: entity.isCheckpoint,
    );
  }

  factory WaypointModel.fromJson(Map<String, dynamic> json) {
    return WaypointModel(
      id: json['id'] as String,
      name: json['name'] as String,
      location: LocationModel.fromJson(json['location'] as Map<String, dynamic>),
      order: json['order'] as int,
      createdAt: _parseDateTime(json['createdAt']),
      description: json['description'] as String?,
      radius: json['radius'] != null ? (json['radius'] as num).toDouble() : 50.0,
      isCheckpoint: json['isCheckpoint'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'location': LocationModel.fromEntity(location).toJson(),
      'order': order,
      'radius': radius,
      'isCheckpoint': isCheckpoint,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  Waypoint toEntity() => this;

  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is String) return DateTime.parse(value);
    if (value is Map) {
      final seconds = value['_seconds'] as int? ?? value['seconds'] as int? ?? 0;
      return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
    }
    try { return (value as dynamic).toDate() as DateTime; } catch (_) { return DateTime.now(); }
  }
}
