import 'package:psga_app/core/utils/logger.dart';
import 'package:psga_app/core/utils/distance_calculator.dart';
import 'package:psga_app/features/routes/domain/entities/location.dart';
import 'package:psga_app/features/routes/domain/entities/route.dart';
import 'package:psga_app/features/routes/domain/entities/waypoint.dart';
import 'package:psga_app/features/maps/domain/repositories/maps_repository.dart';

/// خدمة حساب تفاصيل المسارات
/// 
/// تستخدم MapsRepository بدلاً من DirectionsService المباشر
/// تطبق Clean Architecture و SOLID Principles
class RouteCalculatorService {
  static final RouteCalculatorService instance = RouteCalculatorService._();
  RouteCalculatorService._();

  MapsRepository? _mapsRepository;

  /// تهيئة الخدمة مع Repository
  void initialize(MapsRepository repository) {
    _mapsRepository = repository;
    AppLogger.info('[RouteCalculator] تم تهيئة الخدمة');
  }

  MapsRepository get _repository {
    if (_mapsRepository == null) {
      throw Exception('RouteCalculatorService not initialized. Call initialize() first.');
    }
    return _mapsRepository!;
  }

  /// حساب المسافة الإجمالية للمسار (مباشرة بين النقاط)
  double calculateDirectDistance(List<Waypoint> waypoints) {
    if (waypoints.length < 2) return 0.0;

    final locations = waypoints.map((w) => w.location).toList();
    final totalDistance = DistanceCalculator.calculateTotalDistance(locations);

    AppLogger.info('[RouteCalculator] المسافة المباشرة: ${totalDistance.toStringAsFixed(2)} متر');
    return totalDistance;
  }

  /// حساب المسافة الفعلية للمسار (باستخدام Google Directions API)
  Future<double> calculateActualDistance(List<Waypoint> waypoints) async {
    if (waypoints.length < 2) return 0.0;

    try {
      double totalDistance = 0.0;

      // حساب المسافة بين كل نقطتين متتاليتين
      for (int i = 0; i < waypoints.length - 1; i++) {
        final result = await _repository.getDirections(
          origin: waypoints[i].location,
          destination: waypoints[i + 1].location,
        );

        result.fold(
          (failure) {
            AppLogger.warning('[RouteCalculator] فشل الحصول على الاتجاهات: ${failure.message}');
            // في حالة الفشل، استخدم المسافة المباشرة
            totalDistance += waypoints[i].location.distanceTo(
              waypoints[i + 1].location,
            );
          },
          (direction) {
            totalDistance += direction.totalDistanceValue;
          },
        );
      }

      AppLogger.success('[RouteCalculator] المسافة الفعلية: ${totalDistance.toStringAsFixed(2)} متر');
      return totalDistance;
    } catch (e, stackTrace) {
      AppLogger.error('[RouteCalculator] خطأ في حساب المسافة', e, stackTrace);
      // في حالة الخطأ، استخدم المسافة المباشرة
      return calculateDirectDistance(waypoints);
    }
  }

  /// حساب الوقت المتوقع للمسار (بالدقائق)
  Future<int> calculateEstimatedDuration(
    List<Waypoint> waypoints, {
    double averageSpeedKmh = 50.0, // السرعة المتوسطة الافتراضية
  }) async {
    if (waypoints.length < 2) return 0;

    try {
      int totalDuration = 0;

      // حساب الوقت بين كل نقطتين متتاليتين
      for (int i = 0; i < waypoints.length - 1; i++) {
        final result = await _repository.getDirections(
          origin: waypoints[i].location,
          destination: waypoints[i + 1].location,
        );

        result.fold(
          (failure) {
            // في حالة الفشل، احسب بناءً على المسافة والسرعة
            final distance = waypoints[i].location.distanceTo(
              waypoints[i + 1].location,
            ) / 1000; // بالكيلومتر
            totalDuration += ((distance / averageSpeedKmh) * 60).round();
          },
          (direction) {
            totalDuration += (direction.totalDurationValue / 60).round();
          },
        );
      }

      AppLogger.success('[RouteCalculator] الوقت المتوقع: $totalDuration دقيقة');
      return totalDuration;
    } catch (e, stackTrace) {
      AppLogger.error('[RouteCalculator] خطأ في حساب الوقت', e, stackTrace);
      // في حالة الخطأ، احسب بناءً على المسافة المباشرة والسرعة
      final distance = calculateDirectDistance(waypoints) / 1000; // بالكيلومتر
      return ((distance / averageSpeedKmh) * 60).round();
    }
  }

  /// حساب تفاصيل المسار الكاملة
  Future<RouteCalculation> calculateRouteDetails(
    List<Waypoint> waypoints, {
    bool useActualRoutes = true, // استخدام Google Directions أم لا
  }) async {
    if (waypoints.length < 2) {
      return RouteCalculation(
        distance: 0.0,
        duration: 0,
        segments: [],
      );
    }

    final segments = <RouteSegment>[];
    double totalDistance = 0.0;
    int totalDuration = 0;

    try {
      for (int i = 0; i < waypoints.length - 1; i++) {
        final start = waypoints[i];
        final end = waypoints[i + 1];

        double segmentDistance = 0.0;
        int segmentDuration = 0;

        if (useActualRoutes) {
          // استخدام Repository للحصول على الاتجاهات
          final result = await _repository.getDirections(
            origin: start.location,
            destination: end.location,
          );

          result.fold(
            (failure) {
              // Fallback للمسافة المباشرة
              segmentDistance = start.location.distanceTo(end.location);
              segmentDuration = ((segmentDistance / 1000) / 50 * 60).round();
            },
            (direction) {
              segmentDistance = direction.totalDistanceValue;
              segmentDuration = (direction.totalDurationValue / 60).round();
            },
          );
        } else {
          // استخدام المسافة المباشرة
          segmentDistance = start.location.distanceTo(end.location);
          segmentDuration = ((segmentDistance / 1000) / 50 * 60).round();
        }

        segments.add(RouteSegment(
          startWaypoint: start,
          endWaypoint: end,
          distance: segmentDistance,
          duration: segmentDuration,
        ));

        totalDistance += segmentDistance;
        totalDuration += segmentDuration;
      }

      AppLogger.success(
        '[RouteCalculator] حساب كامل - المسافة: ${totalDistance.toStringAsFixed(2)}م، '
        'الوقت: $totalDuration دقيقة',
      );

      return RouteCalculation(
        distance: totalDistance,
        duration: totalDuration,
        segments: segments,
      );
    } catch (e, stackTrace) {
      AppLogger.error('[RouteCalculator] خطأ في الحساب الكامل', e, stackTrace);
      
      // Fallback: حساب بسيط
      final directDistance = calculateDirectDistance(waypoints);
      final estimatedDuration = ((directDistance / 1000) / 50 * 60).round();
      
      return RouteCalculation(
        distance: directDistance,
        duration: estimatedDuration,
        segments: [],
      );
    }
  }

  /// تحديث مسار بالحسابات
  Future<RouteEntity> updateRouteWithCalculations(
    RouteEntity route, {
    bool useActualRoutes = true,
  }) async {
    final calculation = await calculateRouteDetails(
      route.waypoints,
      useActualRoutes: useActualRoutes,
    );

    return route.copyWith(
      estimatedDistance: calculation.distance,
      estimatedDuration: calculation.duration,
    );
  }

  /// حساب المسافة بين موقعين
  double calculateDistance(Location from, Location to) {
    return DistanceCalculator.calculateDistance(from, to);
  }

  /// تنسيق المسافة للعرض
  String formatDistance(double meters) {
    return DistanceCalculator.formatDistance(meters);
  }

  /// تنسيق الوقت للعرض
  String formatDuration(int minutes) {
    if (minutes < 60) {
      return '$minutes دقيقة';
    } else {
      final hours = minutes ~/ 60;
      final mins = minutes % 60;
      if (mins > 0) {
        return '$hours س $mins د';
      }
      return '$hours ساعة';
    }
  }

  /// حساب السرعة المتوسطة (كم/ساعة)
  double calculateAverageSpeed(double distanceMeters, int durationMinutes) {
    if (durationMinutes == 0) return 0.0;
    final distanceKm = distanceMeters / 1000;
    final durationHours = durationMinutes / 60;
    return distanceKm / durationHours;
  }

  /// تقدير وقت الوصول
  DateTime estimateArrivalTime(
    DateTime startTime,
    int durationMinutes,
  ) {
    return startTime.add(Duration(minutes: durationMinutes));
  }

  /// حساب الوقت المتبقي للرحلة
  int calculateRemainingTime(
    Location currentLocation,
    List<Waypoint> remainingWaypoints, {
    double averageSpeedKmh = 50.0,
  }) {
    if (remainingWaypoints.isEmpty) return 0;

    // المسافة من الموقع الحالي إلى أول نقطة
    double totalDistance = currentLocation.distanceTo(
      remainingWaypoints.first.location,
    );

    // المسافة بين باقي النقاط
    for (int i = 0; i < remainingWaypoints.length - 1; i++) {
      totalDistance += remainingWaypoints[i].location.distanceTo(
        remainingWaypoints[i + 1].location,
      );
    }

    final distanceKm = totalDistance / 1000;
    return ((distanceKm / averageSpeedKmh) * 60).round();
  }

  /// حساب نسبة إكمال المسار
  double calculateCompletionPercentage(
    double totalDistance,
    double remainingDistance,
  ) {
    if (totalDistance == 0) return 0.0;
    final completedDistance = totalDistance - remainingDistance;
    return (completedDistance / totalDistance) * 100;
  }

  /// تقدير استهلاك الوقود
  double estimateFuelConsumption(
    double distanceKm, {
    double fuelEfficiency = 12.0, // كم/لتر
  }) {
    return distanceKm / fuelEfficiency;
  }

  /// تقدير تكلفة الرحلة
  double estimateTripCost(
    double distanceKm, {
    double fuelPrice = 2.0, // ريال/لتر
    double fuelEfficiency = 12.0, // كم/لتر
  }) {
    final fuelNeeded = estimateFuelConsumption(distanceKm, fuelEfficiency: fuelEfficiency);
    return fuelNeeded * fuelPrice;
  }

  /// حساب تفاصيل متقدمة للمسار
  Future<AdvancedRouteAnalysis> analyzeRoute({
    required List<Waypoint> waypoints,
    double? currentSpeed,
    Location? currentLocation,
  }) async {
    try {
      final calculation = await calculateRouteDetails(waypoints);
      
      // حساب المسافة المتبقية إذا كان هناك موقع حالي
      double? remainingDistance;
      int? remainingTime;
      double? completionPercentage;

      if (currentLocation != null) {
        final currentIndex = _findNearestWaypointIndex(currentLocation, waypoints);
        final remaining = waypoints.sublist(currentIndex);
        
        remainingDistance = 0.0;
        for (int i = 0; i < remaining.length - 1; i++) {
          remainingDistance = (remainingDistance ?? 0.0) + remaining[i].location.distanceTo(remaining[i + 1].location);
        }
        
        remainingTime = calculateRemainingTime(
          currentLocation,
          remaining,
          averageSpeedKmh: currentSpeed ?? 50,
        );

        completionPercentage = calculateCompletionPercentage(
          calculation.distance,
          remainingDistance ?? 0.0,
        );
      }

      final distanceKm = calculation.distance / 1000;
      
      return AdvancedRouteAnalysis(
        totalDistance: calculation.distance,
        totalDuration: calculation.duration,
        estimatedFuelConsumption: estimateFuelConsumption(distanceKm),
        estimatedCost: estimateTripCost(distanceKm),
        averageSpeed: calculation.averageSpeed,
        segments: calculation.segments,
        remainingDistance: remainingDistance,
        remainingTime: remainingTime,
        completionPercentage: completionPercentage,
      );
    } catch (e, stackTrace) {
      AppLogger.error('[RouteCalculator] خطأ في التحليل المتقدم', e, stackTrace);
      rethrow;
    }
  }

  /// إيجاد أقرب نقطة waypoint للموقع الحالي
  int _findNearestWaypointIndex(Location location, List<Waypoint> waypoints) {
    double minDistance = double.infinity;
    int nearestIndex = 0;

    for (int i = 0; i < waypoints.length; i++) {
      final distance = location.distanceTo(waypoints[i].location);
      if (distance < minDistance) {
        minDistance = distance;
        nearestIndex = i;
      }
    }

    return nearestIndex;
  }

  /// حساب الوقت بناءً على حركة المرور (تقديري)
  int adjustTimeForTraffic(int baseTimeMinutes, TrafficLevel traffic) {
    switch (traffic) {
      case TrafficLevel.light:
        return baseTimeMinutes;
      case TrafficLevel.moderate:
        return (baseTimeMinutes * 1.2).round();
      case TrafficLevel.heavy:
        return (baseTimeMinutes * 1.5).round();
      case TrafficLevel.severe:
        return (baseTimeMinutes * 2.0).round();
    }
  }

  /// تقسيم المسار لمراحل
  List<RouteStage> divideRouteIntoStages(
    List<Waypoint> waypoints, {
    int maxStageDistanceKm = 100,
  }) {
    if (waypoints.length < 2) return [];

    final stages = <RouteStage>[];
    var currentStageStart = 0;
    var currentStageDistance = 0.0;

    for (int i = 0; i < waypoints.length - 1; i++) {
      final segmentDistance = waypoints[i].location.distanceTo(
        waypoints[i + 1].location,
      );
      
      currentStageDistance += segmentDistance;

      // إذا وصلنا للحد الأقصى أو آخر waypoint
      if (currentStageDistance / 1000 >= maxStageDistanceKm || i == waypoints.length - 2) {
        stages.add(RouteStage(
          stageNumber: stages.length + 1,
          startWaypoint: waypoints[currentStageStart],
          endWaypoint: waypoints[i + 1],
          distance: currentStageDistance,
          waypoints: waypoints.sublist(currentStageStart, i + 2),
        ));

        currentStageStart = i + 1;
        currentStageDistance = 0;
      }
    }

    return stages;
  }
}

/// نتيجة حساب المسار
class RouteCalculation {
  final double distance; // بالمتر
  final int duration; // بالدقائق
  final List<RouteSegment> segments;

  RouteCalculation({
    required this.distance,
    required this.duration,
    required this.segments,
  });

  double get distanceKm => distance / 1000;
  
  String get formattedDistance {
    return RouteCalculatorService.instance.formatDistance(distance);
  }

  String get formattedDuration {
    return RouteCalculatorService.instance.formatDuration(duration);
  }

  double get averageSpeed {
    return RouteCalculatorService.instance.calculateAverageSpeed(
      distance,
      duration,
    );
  }
}

/// قطعة من المسار (بين نقطتين)
class RouteSegment {
  final Waypoint startWaypoint;
  final Waypoint endWaypoint;
  final double distance; // بالمتر
  final int duration; // بالدقائق

  RouteSegment({
    required this.startWaypoint,
    required this.endWaypoint,
    required this.distance,
    required this.duration,
  });

  double get distanceKm => distance / 1000;

  String get formattedDistance {
    return RouteCalculatorService.instance.formatDistance(distance);
  }

  String get formattedDuration {
    return RouteCalculatorService.instance.formatDuration(duration);
  }
}

/// تحليل متقدم للمسار
class AdvancedRouteAnalysis {
  final double totalDistance;
  final int totalDuration;
  final double? remainingDistance;
  final int? remainingTime;
  final double? completionPercentage;
  final double estimatedFuelConsumption;
  final double estimatedCost;
  final double averageSpeed;
  final List<RouteSegment> segments;

  AdvancedRouteAnalysis({
    required this.totalDistance,
    required this.totalDuration,
    required this.estimatedFuelConsumption,
    required this.estimatedCost,
    required this.averageSpeed,
    required this.segments,
    this.remainingDistance,
    this.remainingTime,
    this.completionPercentage,
  });

  String get formattedTotalDistance => 
    RouteCalculatorService.instance.formatDistance(totalDistance);

  String get formattedTotalDuration => 
    RouteCalculatorService.instance.formatDuration(totalDuration);

  String? get formattedRemainingDistance => 
    remainingDistance != null 
      ? RouteCalculatorService.instance.formatDistance(remainingDistance!)
      : null;

  String? get formattedRemainingTime => 
    remainingTime != null
      ? RouteCalculatorService.instance.formatDuration(remainingTime!)
      : null;
}

/// مرحلة من المسار
class RouteStage {
  final int stageNumber;
  final Waypoint startWaypoint;
  final Waypoint endWaypoint;
  final double distance;
  final List<Waypoint> waypoints;

  RouteStage({
    required this.stageNumber,
    required this.startWaypoint,
    required this.endWaypoint,
    required this.distance,
    required this.waypoints,
  });

  String get name => 'المرحلة $stageNumber: ${startWaypoint.name} → ${endWaypoint.name}';
}

/// مستوى الزحام
enum TrafficLevel {
  light,    // خفيف
  moderate, // متوسط
  heavy,    // كثيف
  severe,   // شديد
}
