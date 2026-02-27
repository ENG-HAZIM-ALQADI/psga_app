import 'package:equatable/equatable.dart';
import 'package:psga_app/features/routes/domain/entities/location.dart';

/// نوع المناورة في الاتجاهات
enum ManeuverType {
  turnRight,
  turnLeft,
  turnSlightRight,
  turnSlightLeft,
  turnSharpRight,
  turnSharpLeft,
  uTurn,
  straight,
  merge,
  roundabout,
  ferry,
  arrive,
  depart,
}

/// خطوة في الاتجاهات
class DirectionStep extends Equatable {
  final Location startLocation;
  final Location endLocation;
  final String instruction;
  final String distance;
  final String duration;
  final double distanceValue; // بالأمتار
  final int durationValue; // بالثواني
  final ManeuverType? maneuver;
  final String? polyline;

  const DirectionStep({
    required this.startLocation,
    required this.endLocation,
    required this.instruction,
    required this.distance,
    required this.duration,
    required this.distanceValue,
    required this.durationValue,
    this.maneuver,
    this.polyline,
  });

  @override
  List<Object?> get props => [
        startLocation,
        endLocation,
        instruction,
        distance,
        duration,
        distanceValue,
        durationValue,
        maneuver,
        polyline,
      ];

  /// الحصول على وصف المناورة
  static String getManeuverDescription(ManeuverType maneuver) {
    switch (maneuver) {
      case ManeuverType.turnRight:
        return 'انعطف يميناً';
      case ManeuverType.turnLeft:
        return 'انعطف يساراً';
      case ManeuverType.turnSlightRight:
        return 'انعطف قليلاً يميناً';
      case ManeuverType.turnSlightLeft:
        return 'انعطف قليلاً يساراً';
      case ManeuverType.turnSharpRight:
        return 'انعطف بشدة يميناً';
      case ManeuverType.turnSharpLeft:
        return 'انعطف بشدة يساراً';
      case ManeuverType.uTurn:
        return 'اعكس الاتجاه';
      case ManeuverType.straight:
        return 'استمر مباشرة';
      case ManeuverType.merge:
        return 'اندمج';
      case ManeuverType.roundabout:
        return 'ادخل الدوار';
      case ManeuverType.ferry:
        return 'استقل العبّارة';
      case ManeuverType.arrive:
        return 'وصلت';
      case ManeuverType.depart:
        return 'انطلق';
    }
  }
}

/// كيان الاتجاهات
class DirectionEntity extends Equatable {
  final String id;
  final Location origin;
  final Location destination;
  final List<DirectionStep> steps;
  final String totalDistance;
  final String totalDuration;
  final double totalDistanceValue; // بالأمتار
  final int totalDurationValue; // بالثواني
  final String polyline;
  final List<Location> polylinePoints;
  final String? warnings;
  final String? copyrights;

  const DirectionEntity({
    required this.id,
    required this.origin,
    required this.destination,
    required this.steps,
    required this.totalDistance,
    required this.totalDuration,
    required this.totalDistanceValue,
    required this.totalDurationValue,
    required this.polyline,
    required this.polylinePoints,
    this.warnings,
    this.copyrights,
  });

  @override
  List<Object?> get props => [
        id,
        origin,
        destination,
        steps,
        totalDistance,
        totalDuration,
        totalDistanceValue,
        totalDurationValue,
        polyline,
        polylinePoints,
        warnings,
        copyrights,
      ];

  /// نسخ مع تعديلات
  DirectionEntity copyWith({
    String? id,
    Location? origin,
    Location? destination,
    List<DirectionStep>? steps,
    String? totalDistance,
    String? totalDuration,
    double? totalDistanceValue,
    int? totalDurationValue,
    String? polyline,
    List<Location>? polylinePoints,
    String? warnings,
    String? copyrights,
  }) {
    return DirectionEntity(
      id: id ?? this.id,
      origin: origin ?? this.origin,
      destination: destination ?? this.destination,
      steps: steps ?? this.steps,
      totalDistance: totalDistance ?? this.totalDistance,
      totalDuration: totalDuration ?? this.totalDuration,
      totalDistanceValue: totalDistanceValue ?? this.totalDistanceValue,
      totalDurationValue: totalDurationValue ?? this.totalDurationValue,
      polyline: polyline ?? this.polyline,
      polylinePoints: polylinePoints ?? this.polylinePoints,
      warnings: warnings ?? this.warnings,
      copyrights: copyrights ?? this.copyrights,
    );
  }

  /// المسافة بالكيلومترات
  double get distanceInKm => totalDistanceValue / 1000;

  /// المدة بالدقائق
  double get durationInMinutes => totalDurationValue / 60;

  /// المدة بالساعات
  double get durationInHours => totalDurationValue / 3600;

  /// تنسيق المدة
  String get formattedDuration {
    if (durationInHours >= 1) {
      final hours = durationInHours.floor();
      final minutes = (durationInMinutes % 60).round();
      if (minutes > 0) {
        return '$hours ساعة و $minutes دقيقة';
      }
      return '$hours ساعة';
    }
    return '${durationInMinutes.round()} دقيقة';
  }

  /// تنسيق المسافة
  String get formattedDistance {
    if (distanceInKm >= 1) {
      return '${distanceInKm.toStringAsFixed(1)} كم';
    }
    return '${totalDistanceValue.toStringAsFixed(0)} م';
  }
}
