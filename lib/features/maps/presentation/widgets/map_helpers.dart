import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:psga_app/core/constants/app_colors.dart';
import 'package:psga_app/features/routes/domain/entities/location.dart';
import 'package:psga_app/features/routes/domain/entities/waypoint.dart';

/// مساعد لإنشاء Markers و Polylines للخرائط
class MapHelpers {
  /// إنشاء Marker للبداية (أخضر)
  static Marker createStartMarker({
    required Location location,
    String? title,
    VoidCallback? onTap,
  }) {
    return Marker(
      markerId: const MarkerId('start'),
      position: LatLng(location.latitude, location.longitude),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      infoWindow: InfoWindow(
        title: title ?? 'نقطة البداية',
        snippet: '${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}',
      ),
      onTap: onTap,
    );
  }

  /// إنشاء Marker للنهاية (أحمر)
  static Marker createEndMarker({
    required Location location,
    String? title,
    VoidCallback? onTap,
  }) {
    return Marker(
      markerId: const MarkerId('end'),
      position: LatLng(location.latitude, location.longitude),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      infoWindow: InfoWindow(
        title: title ?? 'نقطة النهاية',
        snippet: '${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}',
      ),
      onTap: onTap,
    );
  }

  /// إنشاء Marker لنقطة وسيطة (برتقالي)
  static Marker createWaypointMarker({
    required String id,
    required Location location,
    required int index,
    String? title,
    VoidCallback? onTap,
  }) {
    return Marker(
      markerId: MarkerId(id),
      position: LatLng(location.latitude, location.longitude),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
      infoWindow: InfoWindow(
        title: title ?? 'نقطة وسيطة ${index + 1}',
        snippet: '${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}',
      ),
      onTap: onTap,
    );
  }

  /// إنشاء Marker للموقع الحالي (أزرق)
  static Marker createCurrentLocationMarker({
    required Location location,
    VoidCallback? onTap,
  }) {
    return Marker(
      markerId: const MarkerId('current_location'),
      position: LatLng(location.latitude, location.longitude),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      infoWindow: const InfoWindow(
        title: 'موقعك الحالي',
      ),
      onTap: onTap,
    );
  }

  /// إنشاء Marker للانحراف (أحمر داكن)
  static Marker createDeviationMarker({
    required String id,
    required Location location,
    required double deviationDistance,
    VoidCallback? onTap,
  }) {
    return Marker(
      markerId: MarkerId(id),
      position: LatLng(location.latitude, location.longitude),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
      infoWindow: InfoWindow(
        title: '⚠️ انحراف عن المسار',
        snippet: 'المسافة: ${deviationDistance.toStringAsFixed(0)} متر',
      ),
      onTap: onTap,
    );
  }

  /// إنشاء Markers لجميع waypoints في مسار
  static Set<Marker> createRouteMarkers({
    required Location start,
    required Location end,
    required List<Waypoint> waypoints,
    Function(String)? onWaypointTap,
  }) {
    final markers = <Marker>{};

    // نقطة البداية
    markers.add(createStartMarker(location: start));

    // النقاط الوسيطة
    for (int i = 0; i < waypoints.length; i++) {
      markers.add(createWaypointMarker(
        id: waypoints[i].id,
        location: waypoints[i].location,
        index: i,
        title: waypoints[i].name,
        onTap: onWaypointTap != null ? () => onWaypointTap(waypoints[i].id) : null,
      ));
    }

    // نقطة النهاية
    markers.add(createEndMarker(location: end));

    return markers;
  }

  /// إنشاء Polyline للمسار المحدد (أزرق)
  static Polyline createPlannedRoutePolyline({
    required List<Location> points,
    double width = 5.0,
  }) {
    return Polyline(
      polylineId: const PolylineId('planned_route'),
      points: points.map((loc) => LatLng(loc.latitude, loc.longitude)).toList(),
      color: AppColors.primary,
      width: width.toInt(),
      geodesic: true,
      patterns: const [], // خط متصل
    );
  }

  /// إنشاء Polyline للمسار الفعلي المقطوع (أخضر)
  static Polyline createActualRoutePolyline({
    required List<Location> points,
    double width = 4.0,
  }) {
    return Polyline(
      polylineId: const PolylineId('actual_route'),
      points: points.map((loc) => LatLng(loc.latitude, loc.longitude)).toList(),
      color: AppColors.success,
      width: width.toInt(),
      geodesic: true,
    );
  }

  /// إنشاء Polyline للانحراف (أحمر منقط)
  static Polyline createDeviationPolyline({
    required String id,
    required List<Location> points,
    double width = 3.0,
  }) {
    return Polyline(
      polylineId: PolylineId('deviation_$id'),
      points: points.map((loc) => LatLng(loc.latitude, loc.longitude)).toList(),
      color: AppColors.error,
      width: width.toInt(),
      geodesic: true,
      patterns: [
        PatternItem.dash(20),
        PatternItem.gap(10),
      ],
    );
  }

  /// إنشاء Circle لنطاق الانحراف
  static Circle createDeviationCircle({
    required Location center,
    required double radius,
  }) {
    return Circle(
      circleId: const CircleId('deviation_range'),
      center: LatLng(center.latitude, center.longitude),
      radius: radius,
      fillColor: AppColors.error.withOpacity(0.1),
      strokeColor: AppColors.error,
      strokeWidth: 2,
    );
  }

  /// إنشاء Circle للموقع الحالي مع دقة GPS
  static Circle createAccuracyCircle({
    required Location location,
  }) {
    return Circle(
      circleId: const CircleId('accuracy'),
      center: LatLng(location.latitude, location.longitude),
      radius: location.accuracy ?? 20,
      fillColor: AppColors.primary.withOpacity(0.1),
      strokeColor: AppColors.primary,
      strokeWidth: 1,
    );
  }

  /// حساب الحدود لعرض جميع المواقع
  static LatLngBounds calculateBounds(List<Location> locations) {
    if (locations.isEmpty) {
      // إرجاع حدود افتراضية (الرياض)
      return LatLngBounds(
        southwest: const LatLng(24.6, 46.6),
        northeast: const LatLng(24.8, 46.8),
      );
    }

    double minLat = locations.first.latitude;
    double maxLat = locations.first.latitude;
    double minLng = locations.first.longitude;
    double maxLng = locations.first.longitude;

    for (final location in locations) {
      if (location.latitude < minLat) minLat = location.latitude;
      if (location.latitude > maxLat) maxLat = location.latitude;
      if (location.longitude < minLng) minLng = location.longitude;
      if (location.longitude > maxLng) maxLng = location.longitude;
    }

    // إضافة هامش
    const padding = 0.01;
    return LatLngBounds(
      southwest: LatLng(minLat - padding, minLng - padding),
      northeast: LatLng(maxLat + padding, maxLng + padding),
    );
  }

  /// تحويل Waypoints إلى Locations
  static List<Location> waypointsToLocations(List<Waypoint> waypoints) {
    return waypoints.map((w) => w.location).toList();
  }

  /// إنشاء جميع Markers و Polylines لرحلة نشطة
  static Map<String, dynamic> createTripVisualization({
    required Location start,
    required Location end,
    required List<Waypoint> waypoints,
    required List<Location> plannedRoute,
    required List<Location> actualRoute,
    Location? currentLocation,
    List<Location>? deviationPoints,
  }) {
    final markers = <Marker>{};
    final polylines = <Polyline>{};
    final circles = <Circle>{};

    // Markers للمسار
    markers.addAll(createRouteMarkers(
      start: start,
      end: end,
      waypoints: waypoints,
    ));

    // Marker للموقع الحالي
    if (currentLocation != null) {
      markers.add(createCurrentLocationMarker(location: currentLocation));
      circles.add(createAccuracyCircle(location: currentLocation));
    }

    // Polyline للمسار المحدد
    if (plannedRoute.isNotEmpty) {
      polylines.add(createPlannedRoutePolyline(points: plannedRoute));
    }

    // Polyline للمسار الفعلي
    if (actualRoute.isNotEmpty) {
      polylines.add(createActualRoutePolyline(points: actualRoute));
    }

    // Polyline والmarkers للانحرافات
    if (deviationPoints != null && deviationPoints.isNotEmpty) {
      for (int i = 0; i < deviationPoints.length; i++) {
        final deviation = deviationPoints[i];
        markers.add(createDeviationMarker(
          id: 'deviation_$i',
          location: deviation,
          deviationDistance: 100, // يمكن حسابها
        ));
      }

      polylines.add(createDeviationPolyline(
        id: 'main',
        points: deviationPoints,
      ));
    }

    return {
      'markers': markers,
      'polylines': polylines,
      'circles': circles,
    };
  }

  /// حساب نقطة المنتصف بين موقعين
  static Location calculateMidpoint(Location loc1, Location loc2) {
    final lat = (loc1.latitude + loc2.latitude) / 2;
    final lng = (loc1.longitude + loc2.longitude) / 2;
    return Location(
      latitude: lat,
      longitude: lng,
      timestamp: DateTime.now(),
    );
  }

  /// تقسيم مسار إلى segments بناءً على المسافة
  static List<List<Location>> splitRouteIntoSegments({
    required List<Location> route,
    double segmentLengthKm = 1.0,
  }) {
    if (route.isEmpty) return [];

    final segments = <List<Location>>[];
    var currentSegment = <Location>[route.first];
    var currentDistance = 0.0;

    for (int i = 1; i < route.length; i++) {
      final distance = route[i - 1].distanceTo(route[i]) / 1000;
      currentDistance += distance;

      currentSegment.add(route[i]);

      if (currentDistance >= segmentLengthKm) {
        segments.add(List.from(currentSegment));
        currentSegment = [route[i]];
        currentDistance = 0.0;
      }
    }

    if (currentSegment.length > 1) {
      segments.add(currentSegment);
    }

    return segments;
  }

  /// إنشاء مسار مبسط (تقليل عدد النقاط مع الحفاظ على الشكل)
  static List<Location> simplifyRoute({
    required List<Location> route,
    double toleranceMeters = 10.0,
  }) {
    if (route.length <= 2) return route;

    // خوارزمية Douglas-Peucker المبسطة
    final simplified = <Location>[route.first];
    
    for (int i = 1; i < route.length - 1; i++) {
      final prev = route[i - 1];
      final current = route[i];
      final next = route[i + 1];

      // حساب المسافة من النقطة الحالية إلى الخط بين السابقة والتالية
      final distance = _perpendicularDistance(current, prev, next);

      if (distance > toleranceMeters) {
        simplified.add(current);
      }
    }

    simplified.add(route.last);
    return simplified;
  }

  /// حساب المسافة العمودية من نقطة إلى خط
  static double _perpendicularDistance(
    Location point,
    Location lineStart,
    Location lineEnd,
  ) {
    // استخدام الصيغة البسيطة للمسافة
    final dx = lineEnd.longitude - lineStart.longitude;
    final dy = lineEnd.latitude - lineStart.latitude;

    final denominator = dx * dx + dy * dy;
    if (denominator == 0) {
      return point.distanceTo(lineStart);
    }

    final t = ((point.longitude - lineStart.longitude) * dx +
            (point.latitude - lineStart.latitude) * dy) /
        denominator;

    final projectedLat = lineStart.latitude + t * dy;
    final projectedLng = lineStart.longitude + t * dx;

    final projected = Location(
      latitude: projectedLat,
      longitude: projectedLng,
      timestamp: DateTime.now(),
    );

    return point.distanceTo(projected);
  }
}
