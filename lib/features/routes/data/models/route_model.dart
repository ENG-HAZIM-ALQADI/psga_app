import 'package:psga_app/features/routes/data/models/waypoint_model.dart';
import 'package:psga_app/features/routes/domain/entities/route.dart';

class RouteModel extends RouteEntity {
  const RouteModel({
    required super.id,
    required super.userId,
    required super.name,
    required super.waypoints,
    required super.createdAt,
    required super.updatedAt,
    super.description,
    super.status,
    super.isFavorite,
    super.estimatedDistance,
    super.estimatedDuration,
  });

  factory RouteModel.fromEntity(RouteEntity entity) {
    return RouteModel(
      id: entity.id,
      userId: entity.userId,
      name: entity.name,
      waypoints: entity.waypoints,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      description: entity.description,
      status: entity.status,
      isFavorite: entity.isFavorite,
      estimatedDistance: entity.estimatedDistance,
      estimatedDuration: entity.estimatedDuration,
    );
  }

  factory RouteModel.fromJson(Map<String, dynamic> json) {
    return RouteModel(
      id: json['id'] as String,
      userId: json['userId'] as String,
      name: json['name'] as String,
      waypoints: (json['waypoints'] as List? ?? [])
          .map((w) => WaypointModel.fromJson(w as Map<String, dynamic>))
          .toList(),
      createdAt: _parseDateTime(json['createdAt']),
      updatedAt: _parseDateTime(json['updatedAt']),
      description: json['description'] as String?,
      status: RouteStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => RouteStatus.active,
      ),
      isFavorite: json['isFavorite'] as bool? ?? false,
      estimatedDistance: json['estimatedDistance'] != null
          ? (json['estimatedDistance'] as num).toDouble()
          : null,
      estimatedDuration: json['estimatedDuration'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'description': description,
      'waypoints': waypoints.map((w) => WaypointModel.fromEntity(w).toJson()).toList(),
      'status': status.name,
      'isFavorite': isFavorite,
      'estimatedDistance': estimatedDistance,
      'estimatedDuration': estimatedDuration,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  RouteEntity toEntity() => this;

  /// تحويل DateTime من String أو Timestamp
  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is String) return DateTime.parse(value);
    // Firestore Timestamp
    if (value is Map) {
      final seconds = value['_seconds'] as int? ?? value['seconds'] as int? ?? 0;
      return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
    }
    try {
      // Firestore Timestamp object (toDate)
      return (value as dynamic).toDate() as DateTime;
    } catch (_) {
      return DateTime.now();
    }
  }
}
