import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:psga_app/core/utils/logger.dart';
import 'location_service.dart';

/// نوع وسيلة التنقل
enum TravelMode { driving, walking, cycling }

/// نتيجة الاتجاهات
class DirectionsResult {
  final List<LatLng> polylinePoints;
  final int distanceMeters;
  final int durationSeconds;
  final String distanceText;
  final String durationText;
  final String startAddress;
  final String endAddress;

  const DirectionsResult({
    required this.polylinePoints,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.distanceText,
    required this.durationText,
    required this.startAddress,
    required this.endAddress,
  });

  double get distanceKm => distanceMeters / 1000;
  Duration get duration => Duration(seconds: durationSeconds);
}

/// خدمة الاتجاهات والمسارات
class DirectionsService {
  static final DirectionsService _instance = DirectionsService._internal();
  factory DirectionsService() => _instance;
  DirectionsService._internal();

  final PolylinePoints _polylinePoints = PolylinePoints();
  final LocationService _locationService = LocationService();

  /// الحصول على المسار بين نقطتين
  Future<DirectionsResult?> getDirections({
    required LatLng origin,
    required LatLng destination,
    List<LatLng>? waypoints,
    TravelMode mode = TravelMode.driving,
  }) async {
    try {
      AppLogger.info(
          '[Directions] جلب المسار: ${origin.latitude},${origin.longitude} → ${destination.latitude},${destination.longitude}');

      List<LatLng> routePoints = await _getRoutePoints(
        origin: origin,
        destination: destination,
        waypoints: waypoints,
      );

      if (routePoints.isEmpty) {
        routePoints = [origin, destination];
      }

      double totalDistance = _calculateTotalDistance(routePoints);
      int estimatedDuration = _estimateDuration(totalDistance, mode);

      final result = DirectionsResult(
        polylinePoints: routePoints,
        distanceMeters: totalDistance.round(),
        durationSeconds: estimatedDuration,
        distanceText: _formatDistance(totalDistance),
        durationText: _formatDuration(estimatedDuration),
        startAddress: 'نقطة البداية',
        endAddress: 'نقطة النهاية',
      );

      AppLogger.info(
          '[Directions] المسافة: ${result.distanceText}, الوقت: ${result.durationText}');
      return result;
    } catch (e) {
      AppLogger.error('[Directions] خطأ في جلب المسار: $e');
      return null;
    }
  }

  /// الحصول على نقاط المسار
  Future<List<LatLng>> _getRoutePoints({
    required LatLng origin,
    required LatLng destination,
    List<LatLng>? waypoints,
  }) async {
    List<LatLng> points = [origin];

    if (waypoints != null) {
      points.addAll(waypoints);
    }

    points.add(destination);

    List<LatLng> interpolatedPoints = [];
    for (int i = 0; i < points.length - 1; i++) {
      interpolatedPoints.addAll(
        _interpolatePoints(points[i], points[i + 1], 20),
      );
    }

    return interpolatedPoints;
  }

  /// إنشاء نقاط وسيطة بين نقطتين
  List<LatLng> _interpolatePoints(LatLng start, LatLng end, int count) {
    List<LatLng> points = [start];

    double latDiff = (end.latitude - start.latitude) / count;
    double lngDiff = (end.longitude - start.longitude) / count;

    for (int i = 1; i < count; i++) {
      points.add(LatLng(
        start.latitude + (latDiff * i),
        start.longitude + (lngDiff * i),
      ));
    }

    points.add(end);
    return points;
  }

  /// حساب المسافة الإجمالية للمسار
  double _calculateTotalDistance(List<LatLng> points) {
    double total = 0;
    for (int i = 0; i < points.length - 1; i++) {
      total += _locationService.getDistanceBetweenCoords(
        points[i].latitude,
        points[i].longitude,
        points[i + 1].latitude,
        points[i + 1].longitude,
      );
    }
    return total;
  }

  /// تقدير مدة الرحلة بناءً على المسافة ونوع التنقل
  int _estimateDuration(double distanceMeters, TravelMode mode) {
    double speedKmh;
    switch (mode) {
      case TravelMode.walking:
        speedKmh = 5;
        break;
      case TravelMode.cycling:
        speedKmh = 15;
        break;
      case TravelMode.driving:
      default:
        speedKmh = 40;
    }

    double hours = (distanceMeters / 1000) / speedKmh;
    return (hours * 3600).round();
  }

  /// تنسيق المسافة للعرض
  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()} متر';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)} كم';
    }
  }

  /// تنسيق المدة للعرض
  String _formatDuration(int seconds) {
    if (seconds < 60) {
      return '$seconds ثانية';
    } else if (seconds < 3600) {
      return '${(seconds / 60).round()} دقيقة';
    } else {
      int hours = seconds ~/ 3600;
      int minutes = (seconds % 3600) ~/ 60;
      return '$hours ساعة ${minutes > 0 ? 'و $minutes دقيقة' : ''}';
    }
  }

  /// فك تشفير polyline المشفر
  List<LatLng> decodePolyline(String encoded) {
    List<PointLatLng> points = _polylinePoints.decodePolyline(encoded);
    return points.map((p) => LatLng(p.latitude, p.longitude)).toList();
  }

  /// تشفير قائمة نقاط إلى polyline
  String encodePolyline(List<LatLng> points) {
    return points.map((p) => '${p.latitude},${p.longitude}').join('|');
  }

  /// حساب مركز المسار
  LatLng calculateCenter(List<LatLng> points) {
    if (points.isEmpty) return const LatLng(0, 0);

    double sumLat = 0;
    double sumLng = 0;

    for (var point in points) {
      sumLat += point.latitude;
      sumLng += point.longitude;
    }

    return LatLng(sumLat / points.length, sumLng / points.length);
  }

  /// حساب حدود المسار للتكبير
  LatLngBounds calculateBounds(List<LatLng> points) {
    if (points.isEmpty) {
      return LatLngBounds(
        southwest: const LatLng(0, 0),
        northeast: const LatLng(0, 0),
      );
    }

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (var point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }
}
