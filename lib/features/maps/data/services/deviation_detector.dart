import 'dart:math';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:psga_app/core/utils/logger.dart';
import 'location_service.dart';

/// شدة الانحراف عن المسار
enum DeviationSeverity {
  /// لا توجد انحراف
  none,
  /// انحراف بسيط (أقل من 100 متر)
  low,
  /// انحراف متوسط (100-250 متر)
  medium,
  /// انحراف كبير (250-500 متر)
  high,
  /// انحراف حرج (أكثر من 500 متر)
  critical,
}

/// نتيجة فحص الانحراف عن المسار
class DeviationResult {
  final bool isDeviated;
  final double distanceFromRoute;
  final LatLng nearestRoutePoint;
  final DeviationSeverity severity;
  final String message;

  const DeviationResult({
    required this.isDeviated,
    required this.distanceFromRoute,
    required this.nearestRoutePoint,
    required this.severity,
    required this.message,
  });

  factory DeviationResult.noDeviation(LatLng nearestPoint) {
    return DeviationResult(
      isDeviated: false,
      distanceFromRoute: 0,
      nearestRoutePoint: nearestPoint,
      severity: DeviationSeverity.none,
      message: 'على المسار الصحيح',
    );
  }
}

/// كاشف الانحراف عن المسار
class DeviationDetector {
  static final DeviationDetector _instance = DeviationDetector._internal();
  factory DeviationDetector() => _instance;
  DeviationDetector._internal();

  final LocationService _locationService = LocationService();

  List<LatLng> _routePoints = [];
  double _thresholdMeters = 100;
  Function(DeviationResult)? _onDeviationDetected;

  List<LatLng> get routePoints => _routePoints;
  double get thresholdMeters => _thresholdMeters;

  /// تعيين المسار للمراقبة
  void setRoute(List<LatLng> points) {
    _routePoints = points;
    AppLogger.info('[Deviation] تم تعيين المسار: ${points.length} نقطة');
  }

  /// تعيين حد الانحراف بالأمتار
  void setThreshold(double meters) {
    _thresholdMeters = meters;
    AppLogger.info('[Deviation] حد الانحراف: $meters متر');
  }

  /// تعيين callback عند اكتشاف انحراف
  void setOnDeviationDetected(Function(DeviationResult) callback) {
    _onDeviationDetected = callback;
  }

  /// فحص الانحراف عن المسار
  DeviationResult checkDeviation(LatLng currentPosition) {
    if (_routePoints.isEmpty) {
      return DeviationResult.noDeviation(currentPosition);
    }

    LatLng nearestPoint = findNearestPointOnRoute(currentPosition);
    double distance = calculateDistanceToRoute(currentPosition);

    // التحقق من أن المسافة منطقية (أقل من 1000 كم) لتجنب أخطاء الإحداثيات الصفرية
    if (distance > 1000000) {
      AppLogger.warning('[Deviation] مسافة غير منطقية ($distance)، قد تكون بسبب خطأ في الإحداثيات');
      return DeviationResult.noDeviation(nearestPoint);
    }

    AppLogger.info('[Deviation] المسافة عن المسار: ${distance.round()} متر');

    bool isDeviated = distance > _thresholdMeters;
    DeviationSeverity severity = _calculateSeverity(distance);

    String message = _getDeviationMessage(distance, severity);

    final result = DeviationResult(
      isDeviated: isDeviated,
      distanceFromRoute: distance,
      nearestRoutePoint: nearestPoint,
      severity: severity,
      message: message,
    );

    if (isDeviated) {
      AppLogger.warning('[Deviation] انحراف مكتشف! تفعيل التنبيه');
      _onDeviationDetected?.call(result);
    }

    return result;
  }

  /// إيجاد أقرب نقطة على المسار
  LatLng findNearestPointOnRoute(LatLng position) {
    if (_routePoints.isEmpty) return position;

    LatLng nearest = _routePoints.first;
    double minDistance = double.infinity;

    for (int i = 0; i < _routePoints.length - 1; i++) {
      LatLng projectedPoint = _projectPointOnSegment(
        position,
        _routePoints[i],
        _routePoints[i + 1],
      );

      double distance = _locationService.getDistanceBetweenCoords(
        position.latitude,
        position.longitude,
        projectedPoint.latitude,
        projectedPoint.longitude,
      );

      if (distance < minDistance) {
        minDistance = distance;
        nearest = projectedPoint;
      }
    }

    return nearest;
  }

  /// حساب المسافة إلى المسار
  double calculateDistanceToRoute(LatLng position) {
    if (_routePoints.isEmpty) return 0;

    LatLng nearestPoint = findNearestPointOnRoute(position);
    return _locationService.getDistanceBetweenCoords(
      position.latitude,
      position.longitude,
      nearestPoint.latitude,
      nearestPoint.longitude,
    );
  }

  /// إسقاط نقطة على خط بين نقطتين
  LatLng _projectPointOnSegment(LatLng point, LatLng segStart, LatLng segEnd) {
    double dx = segEnd.longitude - segStart.longitude;
    double dy = segEnd.latitude - segStart.latitude;

    if (dx == 0 && dy == 0) {
      return segStart;
    }

    double t = ((point.longitude - segStart.longitude) * dx +
            (point.latitude - segStart.latitude) * dy) /
        (dx * dx + dy * dy);

    t = max(0, min(1, t));

    return LatLng(
      segStart.latitude + t * dy,
      segStart.longitude + t * dx,
    );
  }

  /// حساب شدة الانحراف
  DeviationSeverity _calculateSeverity(double distance) {
    if (distance <= _thresholdMeters) {
      return DeviationSeverity.none;
    } else if (distance <= _thresholdMeters * 1.5) {
      return DeviationSeverity.low;
    } else if (distance <= _thresholdMeters * 2) {
      return DeviationSeverity.medium;
    } else if (distance <= _thresholdMeters * 3) {
      return DeviationSeverity.high;
    } else {
      return DeviationSeverity.critical;
    }
  }

  /// رسالة الانحراف حسب الشدة
  String _getDeviationMessage(double distance, DeviationSeverity severity) {
    switch (severity) {
      case DeviationSeverity.none:
        return 'على المسار الصحيح';
      case DeviationSeverity.low:
        return 'انحراف بسيط (${distance.round()} متر)';
      case DeviationSeverity.medium:
        return 'انحراف متوسط (${distance.round()} متر)';
      case DeviationSeverity.high:
        return 'انحراف كبير (${distance.round()} متر)';
      case DeviationSeverity.critical:
        return 'انحراف خطير! (${distance.round()} متر)';
    }
  }

  /// إعادة تعيين المسار
  void clearRoute() {
    _routePoints = [];
    AppLogger.info('[Deviation] تم مسح المسار');
  }

  /// التحقق من وجود مسار محدد
  bool hasRoute() => _routePoints.isNotEmpty;

  /// الحصول على طول المسار بالأمتار
  double getRouteLength() {
    if (_routePoints.length < 2) return 0;

    double total = 0;
    for (int i = 0; i < _routePoints.length - 1; i++) {
      total += _locationService.getDistanceBetweenCoords(
        _routePoints[i].latitude,
        _routePoints[i].longitude,
        _routePoints[i + 1].latitude,
        _routePoints[i + 1].longitude,
      );
    }
    return total;
  }
}
