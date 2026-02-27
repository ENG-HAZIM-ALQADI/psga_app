import 'package:psga_app/features/routes/data/models/location_model.dart';
import 'package:psga_app/features/trips/domain/entities/deviation.dart';

/// نموذج الانحراف
class DeviationModel extends Deviation {
  const DeviationModel({
    required super.id,
    required super.tripId,
    required super.type,
    required super.severity,
    required super.deviationLocation,
    required super.nearestPointOnRoute,
    required super.distanceFromRoute,
    required super.detectedAt,
    super.expectedLocation,
    super.resolvedAt,
    super.duration,
    super.description,
    super.waypointId,
    super.isResolved,
  });

  /// من JSON
  factory DeviationModel.fromJson(Map<String, dynamic> json) {
    return DeviationModel(
      id: json['id'] as String,
      tripId: json['tripId'] as String,
      type: DeviationType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => DeviationType.minorDeviation,
      ),
      severity: DeviationSeverity.values.firstWhere(
        (e) => e.name == json['severity'],
        orElse: () => DeviationSeverity.low,
      ),
      deviationLocation: LocationModel.fromJson(
        json['deviationLocation'] as Map<String, dynamic>,
      ),
      nearestPointOnRoute: json['nearestPointOnRoute'] != null
          ? LocationModel.fromJson(
              json['nearestPointOnRoute'] as Map<String, dynamic>,
            )
          : LocationModel.fromJson(
              json['deviationLocation'] as Map<String, dynamic>,
            ),
      expectedLocation: json['expectedLocation'] != null
          ? LocationModel.fromJson(
              json['expectedLocation'] as Map<String, dynamic>,
            )
          : null,
      distanceFromRoute: (json['distanceFromRoute'] as num).toDouble(),
      detectedAt: DateTime.parse(json['detectedAt'] as String),
      resolvedAt: json['resolvedAt'] != null
          ? DateTime.parse(json['resolvedAt'] as String)
          : null,
      duration: json['duration'] != null
          ? Duration(seconds: json['duration'] as int)
          : null,
      description: json['description'] as String?,
      waypointId: json['waypointId'] as String?,
      isResolved: json['isResolved'] as bool? ?? false,
    );
  }

  /// إلى JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tripId': tripId,
      'type': type.name,
      'severity': severity.name,
      'deviationLocation': LocationModel.fromEntity(deviationLocation).toJson(),
      'nearestPointOnRoute': LocationModel.fromEntity(nearestPointOnRoute).toJson(),
      'expectedLocation': expectedLocation != null
          ? LocationModel.fromEntity(expectedLocation!).toJson()
          : null,
      'distanceFromRoute': distanceFromRoute,
      'detectedAt': detectedAt.toIso8601String(),
      'resolvedAt': resolvedAt?.toIso8601String(),
      'duration': duration?.inSeconds,
      'description': description,
      'waypointId': waypointId,
      'isResolved': isResolved,
    };
  }

  /// من Entity
  factory DeviationModel.fromEntity(Deviation entity) {
    return DeviationModel(
      id: entity.id,
      tripId: entity.tripId,
      type: entity.type,
      severity: entity.severity,
      deviationLocation: entity.deviationLocation,
      nearestPointOnRoute: entity.nearestPointOnRoute,
      expectedLocation: entity.expectedLocation,
      distanceFromRoute: entity.distanceFromRoute,
      detectedAt: entity.detectedAt,
      resolvedAt: entity.resolvedAt,
      duration: entity.duration,
      description: entity.description,
      waypointId: entity.waypointId,
      isResolved: entity.isResolved,
    );
  }

  /// إلى Entity
  Deviation toEntity() => this;
}
