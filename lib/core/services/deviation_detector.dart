import 'package:psga_app/core/utils/logger.dart';
import 'package:psga_app/core/utils/distance_calculator.dart';
import 'package:psga_app/features/routes/domain/entities/location.dart';
import 'package:psga_app/features/routes/domain/entities/route.dart' as route_entity;
import 'package:psga_app/features/trips/domain/entities/deviation.dart';

/// كاشف الانحراف عن المسار
class DeviationDetector {
  static final DeviationDetector _instance = DeviationDetector._();
  factory DeviationDetector() => _instance;
  DeviationDetector._();

  static DeviationDetector get instance => _instance;

  // عتبات الانحراف الافتراضية (بالمتر)
  static const double lowThreshold = 50.0;
  static const double mediumThreshold = 150.0;
  static const double highThreshold = 300.0;

  // العتبات المخصصة الحالية (يمكن تحديثها)
  double _customLowThreshold = lowThreshold;
  double _customMediumThreshold = mediumThreshold;
  double _customHighThreshold = highThreshold;

  /// تحديث العتبات المخصصة
  void updateThresholds({
    double? low,
    double? medium,
    double? high,
  }) {
    if (low != null) _customLowThreshold = low;
    if (medium != null) _customMediumThreshold = medium;
    if (high != null) _customHighThreshold = high;
    
    AppLogger.info(
      '[DeviationDetector] تحديث العتبات: Low=$_customLowThreshold م, '
      'Medium=$_customMediumThreshold م, High=$_customHighThreshold م',
    );
  }

  /// إعادة تعيين للقيم الافتراضية
  void resetToDefaults() {
    _customLowThreshold = lowThreshold;
    _customMediumThreshold = mediumThreshold;
    _customHighThreshold = highThreshold;
    AppLogger.info('[DeviationDetector] إعادة تعيين العتبات للقيم الافتراضية');
  }

  /// كشف الانحراف عن المسار
  Deviation? detectDeviation({
    required Location currentLocation,
    required route_entity.RouteEntity route,
  }) {
    try {
      // إيجاد أقرب نقطة على المسار
      final closestPoint = _findClosestPointOnRoute(currentLocation, route);
      
      if (closestPoint == null) {
        AppLogger.warning('[DeviationDetector] لا يمكن إيجاد أقرب نقطة');
        return null;
      }

      // حساب المسافة
      final distance = DistanceCalculator.calculateDistance(
        currentLocation,
        closestPoint.location,
      );

      // تحديد نوع وشدة الانحراف باستخدام العتبات المخصصة
      final type = _determineDeviationType(currentLocation, route);
      final severity = _determineSeverity(distance);

      // إذا كانت المسافة ضمن الحد المقبول
      if (severity == DeviationSeverity.low && distance < _customLowThreshold) {
        return null;
      }

      final deviation = Deviation(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        tripId: '', // سيتم تعيينه من TripBloc
        type: type,
        severity: severity,
        deviationLocation: currentLocation,
        nearestPointOnRoute: closestPoint.location,
        distanceFromRoute: distance,
        detectedAt: DateTime.now(),
      );

      AppLogger.warning(
        '[DeviationDetector] انحراف: ${severity.name} - ${distance.toStringAsFixed(1)}م',
      );

      return deviation;
    } catch (e, stackTrace) {
      AppLogger.error('[DeviationDetector] خطأ في كشف الانحراف', e, stackTrace);
      return null;
    }
  }

  /// إيجاد أقرب نقطة على المسار
  _ClosestPoint? _findClosestPointOnRoute(
    Location currentLocation,
    route_entity.RouteEntity route,
  ) {
    if (route.waypoints.isEmpty) return null;

    _ClosestPoint? closest;
    double minDistance = double.infinity;

    // البحث في جميع نقاط الطريق
    for (var i = 0; i < route.waypoints.length; i++) {
      final waypoint = route.waypoints[i];
      final distance = DistanceCalculator.calculateDistance(currentLocation, waypoint.location);

      if (distance < minDistance) {
        minDistance = distance;
        closest = _ClosestPoint(
          location: waypoint.location,
          waypointIndex: i,
          distance: distance,
        );
      }

      // إذا كان هناك نقطة تالية، افحص الخط بينهما
      if (i < route.waypoints.length - 1) {
        final nextWaypoint = route.waypoints[i + 1];
        final pointOnLine = _closestPointOnLine(
          currentLocation,
          waypoint.location,
          nextWaypoint.location,
        );

        final lineDistance = DistanceCalculator.calculateDistance(currentLocation, pointOnLine);
        if (lineDistance < minDistance) {
          minDistance = lineDistance;
          closest = _ClosestPoint(
            location: pointOnLine,
            waypointIndex: i,
            distance: lineDistance,
          );
        }
      }
    }

    return closest;
  }

  /// إيجاد أقرب نقطة على خط
  Location _closestPointOnLine(
    Location point,
    Location lineStart,
    Location lineEnd,
  ) {
    return DistanceCalculator.findClosestPointOnLine(
      point: point,
      lineStart: lineStart,
      lineEnd: lineEnd,
    );
  }

  /// تحديد نوع الانحراف
  DeviationType _determineDeviationType(
    Location currentLocation,
    route_entity.RouteEntity route,
  ) {
    // يمكن تحسين هذا بناءً على السرعة، الاتجاه، إلخ
    // الآن نستخدم نوع بسيط
    return DeviationType.minorDeviation;
  }

  /// تحديد شدة الانحراف
  DeviationSeverity _determineSeverity(double distance) {
    if (distance < _customLowThreshold) {
      return DeviationSeverity.low;
    } else if (distance < _customMediumThreshold) {
      return DeviationSeverity.medium;
    } else if (distance < _customHighThreshold) {
      return DeviationSeverity.high;
    } else {
      return DeviationSeverity.critical;
    }
  }
}

/// نقطة أقرب على المسار
class _ClosestPoint {
  final Location location;
  final int waypointIndex;
  final double distance;

  _ClosestPoint({
    required this.location,
    required this.waypointIndex,
    required this.distance,
  });
}
