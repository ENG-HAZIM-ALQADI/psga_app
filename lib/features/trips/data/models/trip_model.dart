import 'package:psga_app/features/routes/data/models/location_model.dart';
import 'package:psga_app/features/routes/data/models/route_model.dart';
import 'package:psga_app/features/routes/domain/entities/location.dart';
import 'package:psga_app/features/trips/data/models/deviation_model.dart';
import 'package:psga_app/features/trips/domain/entities/deviation.dart';
import 'package:psga_app/features/trips/domain/entities/trip_entity.dart';

/// نموذج الرحلة
class TripModel extends TripEntity {
  const TripModel({
    required super.id,
    required super.userId,
    required super.routeId,
    required super.route,
    required super.status,
    required super.startTime,
    super.endTime,
    super.pausedAt,
    super.totalPausedDuration,
    super.distanceTraveled,
    super.locationHistory,
    super.visitedWaypointIds,
    super.missedWaypointIds,
    super.currentWaypointIndex,
    super.deviations,
    super.currentDeviation,
    super.totalDeviations,
    super.averageSpeed,
    super.maxSpeed,
    super.currentLocation,
    super.lastKnownLocation,
  });

  /// من JSON
  factory TripModel.fromJson(Map<String, dynamic> json) {
    return TripModel(
      id: json['id'] as String,
      userId: json['userId'] as String,
      routeId: json['routeId'] as String,
      route: json['route'] != null
          ? RouteModel.fromJson(json['route'] as Map<String, dynamic>)
          : RouteModel(
              id: json['routeId'] as String? ?? '',
              userId: json['userId'] as String? ?? '',
              name: 'جاري التحميل...',
              waypoints: const [],
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
      status: TripStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => TripStatus.active,
      ),
      startTime: _parseDateTime(json['startTime']),
      endTime: json['endTime'] != null
          ? _parseDateTime(json['endTime'])
          : null,
      pausedAt: json['pausedAt'] != null
          ? _parseDateTime(json['pausedAt'])
          : null,
      totalPausedDuration: Duration(
        seconds: (json['totalPausedDuration'] as num?)?.toInt() ?? 0,
      ),
      distanceTraveled: (json['distanceTraveled'] as num?)?.toDouble() ?? 0.0,
      locationHistory: (json['locationHistory'] as List<dynamic>?)
              ?.map((e) => LocationModel.fromJson(e as Map<String, dynamic>))
              .cast<Location>()
              .toList() ??
          const [],
      visitedWaypointIds: (json['visitedWaypointIds'] as List<dynamic>?)
              ?.cast<String>()
              .toList() ??
          const [],
      missedWaypointIds: (json['missedWaypointIds'] as List<dynamic>?)
              ?.cast<String>()
              .toList() ??
          const [],
      currentWaypointIndex: (json['currentWaypointIndex'] as num?)?.toInt() ?? 0,
      deviations: (json['deviations'] as List<dynamic>?)
              ?.map((e) => DeviationModel.fromJson(e as Map<String, dynamic>))
              .cast<Deviation>()
              .toList() ??
          const [],
      currentDeviation: json['currentDeviation'] != null
          ? DeviationModel.fromJson(
              json['currentDeviation'] as Map<String, dynamic>,
            )
          : null,
      totalDeviations: (json['totalDeviations'] as num?)?.toInt() ?? 0,
      averageSpeed: (json['averageSpeed'] as num?)?.toDouble(),
      maxSpeed: (json['maxSpeed'] as num?)?.toDouble(),
      currentLocation: json['currentLocation'] != null
          ? LocationModel.fromJson(
              json['currentLocation'] as Map<String, dynamic>,
            )
          : null,
      lastKnownLocation: json['lastKnownLocation'] != null
          ? LocationModel.fromJson(
              json['lastKnownLocation'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  /// إلى JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'routeId': routeId,
      'route': RouteModel.fromEntity(route).toJson(),
      'status': status.name,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'pausedAt': pausedAt?.toIso8601String(),
      'totalPausedDuration': totalPausedDuration.inSeconds,
      'distanceTraveled': distanceTraveled,
      'locationHistory': locationHistory
          .map((l) => LocationModel.fromEntity(l).toJson())
          .toList(),
      'visitedWaypointIds': visitedWaypointIds,
      'missedWaypointIds': missedWaypointIds,
      'currentWaypointIndex': currentWaypointIndex,
      'deviations': deviations
          .map((d) => DeviationModel.fromEntity(d).toJson())
          .toList(),
      'currentDeviation': currentDeviation != null
          ? DeviationModel.fromEntity(currentDeviation!).toJson()
          : null,
      'totalDeviations': totalDeviations,
      'averageSpeed': averageSpeed,
      'maxSpeed': maxSpeed,
      'currentLocation': currentLocation != null
          ? LocationModel.fromEntity(currentLocation!).toJson()
          : null,
      'lastKnownLocation': lastKnownLocation != null
          ? LocationModel.fromEntity(lastKnownLocation!).toJson()
          : null,
    };
  }

  /// من Entity
  factory TripModel.fromEntity(TripEntity entity) {
    return TripModel(
      id: entity.id,
      userId: entity.userId,
      routeId: entity.routeId,
      route: entity.route,
      status: entity.status,
      startTime: entity.startTime,
      endTime: entity.endTime,
      pausedAt: entity.pausedAt,
      totalPausedDuration: entity.totalPausedDuration,
      distanceTraveled: entity.distanceTraveled,
      locationHistory: entity.locationHistory,
      visitedWaypointIds: entity.visitedWaypointIds,
      missedWaypointIds: entity.missedWaypointIds,
      currentWaypointIndex: entity.currentWaypointIndex,
      deviations: entity.deviations,
      currentDeviation: entity.currentDeviation,
      totalDeviations: entity.totalDeviations,
      averageSpeed: entity.averageSpeed,
      maxSpeed: entity.maxSpeed,
      currentLocation: entity.currentLocation,
      lastKnownLocation: entity.lastKnownLocation,
    );
  }

  /// إلى Entity
  TripEntity toEntity() => this;

  /// تحويل DateTime من String أو Firestore Timestamp
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
