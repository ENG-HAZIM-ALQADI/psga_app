import 'package:psga_app/features/maps/domain/entities/direction_entity.dart';
import 'package:psga_app/features/routes/domain/entities/location.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

/// نموذج بيانات لخطوة الاتجاه
/// يرث من Entity ويضيف دوال التحويل من/إلى JSON
class DirectionStepModel extends DirectionStep {
  const DirectionStepModel({
    required super.startLocation,
    required super.endLocation,
    required super.instruction,
    required super.distance,
    required super.duration,
    required super.distanceValue,
    required super.durationValue,
    super.maneuver,
    super.polyline,
  });

  /// تحويل من JSON
  factory DirectionStepModel.fromJson(Map<String, dynamic> json) {
    final startLoc = json['start_location'];
    final endLoc = json['end_location'];

    ManeuverType? maneuver;
    if (json.containsKey('maneuver')) {
      maneuver = _parseManeuver(json['maneuver'] as String);
    }

    return DirectionStepModel(
      startLocation: Location(
        latitude: startLoc['lat'] as double,
        longitude: startLoc['lng'] as double,
        timestamp: DateTime.now(),
      ),
      endLocation: Location(
        latitude: endLoc['lat'] as double,
        longitude: endLoc['lng'] as double,
        timestamp: DateTime.now(),
      ),
      instruction: _cleanHtml(json['html_instructions'] as String),
      distance: json['distance']['text'] as String,
      duration: json['duration']['text'] as String,
      distanceValue: (json['distance']['value'] as int).toDouble(),
      durationValue: json['duration']['value'] as int,
      maneuver: maneuver,
      polyline: json['polyline']['points'] as String?,
    );
  }

  /// تحليل نوع المناورة من النص
  static ManeuverType? _parseManeuver(String maneuver) {
    switch (maneuver) {
      case 'turn-right':
        return ManeuverType.turnRight;
      case 'turn-left':
        return ManeuverType.turnLeft;
      case 'turn-slight-right':
        return ManeuverType.turnSlightRight;
      case 'turn-slight-left':
        return ManeuverType.turnSlightLeft;
      case 'turn-sharp-right':
        return ManeuverType.turnSharpRight;
      case 'turn-sharp-left':
        return ManeuverType.turnSharpLeft;
      case 'uturn-right':
      case 'uturn-left':
        return ManeuverType.uTurn;
      case 'straight':
        return ManeuverType.straight;
      case 'merge':
        return ManeuverType.merge;
      case 'roundabout-right':
      case 'roundabout-left':
        return ManeuverType.roundabout;
      case 'ferry':
        return ManeuverType.ferry;
      default:
        return null;
    }
  }

  /// تنظيف HTML من التعليمات
  static String _cleanHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&quot;', '"')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');
  }

  /// تحويل إلى Entity
  DirectionStep toEntity() {
    return DirectionStep(
      startLocation: startLocation,
      endLocation: endLocation,
      instruction: instruction,
      distance: distance,
      duration: duration,
      distanceValue: distanceValue,
      durationValue: durationValue,
      maneuver: maneuver,
      polyline: polyline,
    );
  }
}

/// نموذج بيانات للاتجاهات
class DirectionModel extends DirectionEntity {
  const DirectionModel({
    required super.id,
    required super.origin,
    required super.destination,
    required super.steps,
    required super.totalDistance,
    required super.totalDuration,
    required super.totalDistanceValue,
    required super.totalDurationValue,
    required super.polyline,
    required super.polylinePoints,
    super.warnings,
    super.copyrights,
  });

  /// تحويل من JSON
  factory DirectionModel.fromJson(Map<String, dynamic> json) {
    final route = json['routes'][0];
    final leg = route['legs'][0];

    // فك تشفير polyline
    final encodedPolyline = route['overview_polyline']['points'] as String;
    final decodedPoints = _decodePolyline(encodedPolyline);

    // استخراج الخطوات
    final steps = <DirectionStep>[];
    for (final step in leg['steps']) {
      steps.add(DirectionStepModel.fromJson(step).toEntity());
    }

    return DirectionModel(
      id: '${DateTime.now().millisecondsSinceEpoch}',
      origin: Location(
        latitude: leg['start_location']['lat'] as double,
        longitude: leg['start_location']['lng'] as double,
        timestamp: DateTime.now(),
      ),
      destination: Location(
        latitude: leg['end_location']['lat'] as double,
        longitude: leg['end_location']['lng'] as double,
        timestamp: DateTime.now(),
      ),
      steps: steps,
      totalDistance: leg['distance']['text'] as String,
      totalDuration: leg['duration']['text'] as String,
      totalDistanceValue: (leg['distance']['value'] as int).toDouble(),
      totalDurationValue: leg['duration']['value'] as int,
      polyline: encodedPolyline,
      polylinePoints: decodedPoints,
      warnings: route['warnings']?.join(', '),
      copyrights: route['copyrights'] as String?,
    );
  }

  /// فك تشفير polyline
  static List<Location> _decodePolyline(String encoded) {
    final polylinePoints = PolylinePoints();
    final points = polylinePoints.decodePolyline(encoded);
    
    return points.map((point) => Location(
      latitude: point.latitude,
      longitude: point.longitude,
      timestamp: DateTime.now(),
    )).toList();
  }

  /// تحويل إلى Entity
  DirectionEntity toEntity() {
    return DirectionEntity(
      id: id,
      origin: origin,
      destination: destination,
      steps: steps,
      totalDistance: totalDistance,
      totalDuration: totalDuration,
      totalDistanceValue: totalDistanceValue,
      totalDurationValue: totalDurationValue,
      polyline: polyline,
      polylinePoints: polylinePoints,
      warnings: warnings,
      copyrights: copyrights,
    );
  }
}
