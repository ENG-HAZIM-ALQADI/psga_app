import 'package:equatable/equatable.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:psga_app/features/trips/domain/entities/location_entity.dart';

/// كيان خطوة التوجيه
class DirectionStep extends Equatable {
  final String instruction;
  final double distance;
  final Duration duration;
  final String? maneuver;
  final LocationEntity startLocation;
  final LocationEntity endLocation;

  const DirectionStep({
    required this.instruction,
    required this.distance,
    required this.duration,
    this.maneuver,
    required this.startLocation,
    required this.endLocation,
  });

  @override
  List<Object?> get props => [
        instruction,
        distance,
        duration,
        maneuver,
        startLocation,
        endLocation,
      ];
}

/// كيان جزء من المسار
class DirectionLeg extends Equatable {
  final LocationEntity startLocation;
  final LocationEntity endLocation;
  final double distance;
  final Duration duration;
  final List<DirectionStep> steps;
  final String startAddress;
  final String endAddress;

  const DirectionLeg({
    required this.startLocation,
    required this.endLocation,
    required this.distance,
    required this.duration,
    this.steps = const [],
    this.startAddress = '',
    this.endAddress = '',
  });

  @override
  List<Object?> get props => [
        startLocation,
        endLocation,
        distance,
        duration,
        steps,
        startAddress,
        endAddress,
      ];
}

/// كيان حدود الخريطة
class MapBoundsEntity extends Equatable {
  final double southwestLat;
  final double southwestLng;
  final double northeastLat;
  final double northeastLng;

  const MapBoundsEntity({
    required this.southwestLat,
    required this.southwestLng,
    required this.northeastLat,
    required this.northeastLng,
  });

  LatLngBounds toLatLngBounds() {
    return LatLngBounds(
      southwest: LatLng(southwestLat, southwestLng),
      northeast: LatLng(northeastLat, northeastLng),
    );
  }

  @override
  List<Object?> get props => [
        southwestLat,
        southwestLng,
        northeastLat,
        northeastLng,
      ];
}

/// كيان اتجاهات المسار
class DirectionEntity extends Equatable {
  final List<LocationEntity> polylinePoints;
  final double totalDistance;
  final Duration totalDuration;
  final List<DirectionLeg> legs;
  final MapBoundsEntity? bounds;
  final String encodedPolyline;

  const DirectionEntity({
    required this.polylinePoints,
    required this.totalDistance,
    required this.totalDuration,
    this.legs = const [],
    this.bounds,
    this.encodedPolyline = '',
  });

  /// المسافة بالكيلومترات
  double get distanceKm => totalDistance / 1000;

  /// المسافة منسقة للعرض
  String get formattedDistance {
    if (totalDistance < 1000) {
      return '${totalDistance.round()} متر';
    }
    return '${distanceKm.toStringAsFixed(1)} كم';
  }

  /// المدة منسقة للعرض
  String get formattedDuration {
    if (totalDuration.inMinutes < 1) {
      return '${totalDuration.inSeconds} ثانية';
    } else if (totalDuration.inHours < 1) {
      return '${totalDuration.inMinutes} دقيقة';
    } else {
      final hours = totalDuration.inHours;
      final minutes = totalDuration.inMinutes.remainder(60);
      return '$hours ساعة${minutes > 0 ? ' و $minutes دقيقة' : ''}';
    }
  }

  DirectionEntity copyWith({
    List<LocationEntity>? polylinePoints,
    double? totalDistance,
    Duration? totalDuration,
    List<DirectionLeg>? legs,
    MapBoundsEntity? bounds,
    String? encodedPolyline,
  }) {
    return DirectionEntity(
      polylinePoints: polylinePoints ?? this.polylinePoints,
      totalDistance: totalDistance ?? this.totalDistance,
      totalDuration: totalDuration ?? this.totalDuration,
      legs: legs ?? this.legs,
      bounds: bounds ?? this.bounds,
      encodedPolyline: encodedPolyline ?? this.encodedPolyline,
    );
  }

  @override
  List<Object?> get props => [
        polylinePoints,
        totalDistance,
        totalDuration,
        legs,
        bounds,
        encodedPolyline,
      ];
}
