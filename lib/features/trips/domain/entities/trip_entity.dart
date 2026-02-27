import 'package:equatable/equatable.dart';
import 'package:psga_app/features/routes/domain/entities/location.dart';
import 'package:psga_app/features/routes/domain/entities/route.dart';
import 'package:psga_app/features/routes/domain/entities/waypoint.dart';
import 'package:psga_app/features/trips/domain/entities/deviation.dart';

/// حالة الرحلة
enum TripStatus {
  active,      // نشطة - جارية الآن
  paused,      // متوقفة مؤقتاً
  completed,   // مكتملة
  cancelled,   // ملغاة
}

/// كيان الرحلة
class TripEntity extends Equatable {
  final String id;
  final String userId;
  final String routeId;
  final RouteEntity route;
  final TripStatus status;
  
  // معلومات الوقت
  final DateTime startTime;
  final DateTime? endTime;
  final DateTime? pausedAt;
  final Duration totalPausedDuration;
  
  // معلومات المسافة
  final double distanceTraveled;
  final List<Location> locationHistory;
  
  // معلومات نقاط الطريق
  final List<String> visitedWaypointIds;
  final List<String> missedWaypointIds;
  final int currentWaypointIndex;
  
  // الانحرافات
  final List<Deviation> deviations;
  final Deviation? currentDeviation; // الانحراف الحالي
  final int totalDeviations;
  
  // الإحصائيات
  final double? averageSpeed;
  final double? maxSpeed;
  final Location? currentLocation;
  final Location? lastKnownLocation;

  const TripEntity({
    required this.id,
    required this.userId,
    required this.routeId,
    required this.route,
    required this.status,
    required this.startTime,
    this.endTime,
    this.pausedAt,
    this.totalPausedDuration = Duration.zero,
    this.distanceTraveled = 0.0,
    this.locationHistory = const [],
    this.visitedWaypointIds = const [],
    this.missedWaypointIds = const [],
    this.currentWaypointIndex = 0,
    this.deviations = const [],
    this.currentDeviation,
    this.totalDeviations = 0,
    this.averageSpeed,
    this.maxSpeed,
    this.currentLocation,
    this.lastKnownLocation,
  });

  @override
  List<Object?> get props => [
        id,
        userId,
        routeId,
        status,
        startTime,
        endTime,
        pausedAt,
        totalPausedDuration,
        distanceTraveled,
        locationHistory,
        visitedWaypointIds,
        missedWaypointIds,
        currentWaypointIndex,
        deviations,
        currentDeviation,
        totalDeviations,
        averageSpeed,
        maxSpeed,
        currentLocation,
        lastKnownLocation,
      ];

  /// نسخ مع تعديلات
  TripEntity copyWith({
    String? id,
    String? userId,
    String? routeId,
    RouteEntity? route,
    TripStatus? status,
    DateTime? startTime,
    DateTime? endTime,
    DateTime? pausedAt,
    Duration? totalPausedDuration,
    double? distanceTraveled,
    List<Location>? locationHistory,
    List<String>? visitedWaypointIds,
    List<String>? missedWaypointIds,
    int? currentWaypointIndex,
    List<Deviation>? deviations,
    Deviation? currentDeviation,
    int? totalDeviations,
    double? averageSpeed,
    double? maxSpeed,
    Location? currentLocation,
    Location? lastKnownLocation,
  }) {
    return TripEntity(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      routeId: routeId ?? this.routeId,
      route: route ?? this.route,
      status: status ?? this.status,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      pausedAt: pausedAt ?? this.pausedAt,
      totalPausedDuration: totalPausedDuration ?? this.totalPausedDuration,
      distanceTraveled: distanceTraveled ?? this.distanceTraveled,
      locationHistory: locationHistory ?? this.locationHistory,
      visitedWaypointIds: visitedWaypointIds ?? this.visitedWaypointIds,
      missedWaypointIds: missedWaypointIds ?? this.missedWaypointIds,
      currentWaypointIndex: currentWaypointIndex ?? this.currentWaypointIndex,
      deviations: deviations ?? this.deviations,
      currentDeviation: currentDeviation ?? this.currentDeviation,
      totalDeviations: totalDeviations ?? this.totalDeviations,
      averageSpeed: averageSpeed ?? this.averageSpeed,
      maxSpeed: maxSpeed ?? this.maxSpeed,
      currentLocation: currentLocation ?? this.currentLocation,
      lastKnownLocation: lastKnownLocation ?? this.lastKnownLocation,
    );
  }

  /// مدة الرحلة الفعلية (بدون التوقفات)
  Duration get actualDuration {
    final end = endTime ?? DateTime.now();
    final total = end.difference(startTime);
    return total - totalPausedDuration;
  }

  /// مدة الرحلة الإجمالية (مع التوقفات)
  Duration get totalDuration {
    final end = endTime ?? DateTime.now();
    return end.difference(startTime);
  }

  /// هل الرحلة نشطة؟
  bool get isActive => status == TripStatus.active;

  /// هل الرحلة متوقفة مؤقتاً؟
  bool get isPaused => status == TripStatus.paused;

  /// هل الرحلة مكتملة؟
  bool get isCompleted => status == TripStatus.completed;

  /// هل الرحلة ملغاة؟
  bool get isCancelled => status == TripStatus.cancelled;

  /// نسبة التقدم (0.0 - 1.0)
  double get progress {
    if (route.waypoints.isEmpty) return 0.0;
    return currentWaypointIndex / route.waypoints.length;
  }

  /// عدد النقاط المتبقية
  int get remainingWaypoints {
    return route.waypoints.length - visitedWaypointIds.length;
  }

  /// النقطة الحالية
  Waypoint? get currentWaypoint {
    if (currentWaypointIndex >= route.waypoints.length) return null;
    return route.waypoints[currentWaypointIndex];
  }

  /// النقطة التالية
  Waypoint? get nextWaypoint {
    final nextIndex = currentWaypointIndex + 1;
    if (nextIndex >= route.waypoints.length) return null;
    return route.waypoints[nextIndex];
  }

  /// المسافة المتبقية (تقريبية)
  double get remainingDistance {
    if (currentLocation == null) return 0.0;
    
    double distance = 0.0;
    Location current = currentLocation!;
    
    // من الموقع الحالي إلى النقطة الحالية
    if (currentWaypoint != null) {
      distance += current.distanceTo(currentWaypoint!.location);
      current = currentWaypoint!.location;
    }
    
    // من النقطة الحالية إلى باقي النقاط
    for (int i = currentWaypointIndex + 1; i < route.waypoints.length; i++) {
      distance += current.distanceTo(route.waypoints[i].location);
      current = route.waypoints[i].location;
    }
    
    return distance;
  }

  /// نسبة إكمال نقاط التفتيش
  double get checkpointCompletion {
    final checkpoints = route.waypoints.where((w) => w.isCheckpoint).toList();
    if (checkpoints.isEmpty) return 1.0;
    
    final visitedCheckpoints = checkpoints
        .where((w) => visitedWaypointIds.contains(w.id))
        .length;
    
    return visitedCheckpoints / checkpoints.length;
  }

  /// هل تم زيارة جميع نقاط التفتيش؟
  bool get allCheckpointsVisited {
    final checkpoints = route.waypoints.where((w) => w.isCheckpoint);
    return checkpoints.every((w) => visitedWaypointIds.contains(w.id));
  }

  /// حساب السرعة الحالية (كم/ساعة)
  double? calculateCurrentSpeed() {
    if (locationHistory.length < 2) return null;
    
    final last = locationHistory.last;
    final previous = locationHistory[locationHistory.length - 2];
    
    final distance = previous.distanceTo(last); // meters
    final timeDiff = last.timestamp.difference(previous.timestamp).inSeconds;
    
    if (timeDiff == 0) return null;
    
    // Convert to km/h
    final speedMps = distance / timeDiff; // meters per second
    return speedMps * 3.6; // km/h
  }

  /// السرعة الحالية (getter للاستخدام السهل)
  double? get currentSpeed => calculateCurrentSpeed();

  /// حساب الوقت المتوقع للوصول (ETA)
  Duration? calculateETA() {
    final currentSpeed = calculateCurrentSpeed();
    if (currentSpeed == null || currentSpeed <= 0) return null;
    
    // المسافة الكلية (بالمتر)
    final totalDistanceMeters = route.calculateTotalDistance();
    
    // المسافة المتبقية (بالكيلومتر)
    final totalDistanceKm = totalDistanceMeters / 1000;
    final distanceTraveledKm = distanceTraveled / 1000;
    final remaining = totalDistanceKm - distanceTraveledKm;
    
    if (remaining <= 0) return Duration.zero;
    
    // الوقت = المسافة / السرعة (بالساعات)
    final hoursRemaining = remaining / currentSpeed;
    final minutesRemaining = (hoursRemaining * 60).round();
    
    return Duration(minutes: minutesRemaining);
  }

  /// حساب وقت الوصول المتوقع
  DateTime? calculateArrivalTime() {
    final eta = calculateETA();
    if (eta == null) return null;
    
    return DateTime.now().add(eta);
  }

  /// التحقق من الوصول لنقطة
  bool hasReachedWaypoint(Waypoint waypoint) {
    if (currentLocation == null) return false;
    return waypoint.isReached(currentLocation!);
  }
}
