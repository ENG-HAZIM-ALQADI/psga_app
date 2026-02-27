import 'package:equatable/equatable.dart';
import 'package:psga_app/features/routes/domain/entities/location.dart';

/// نوع الانحراف
enum DeviationType {
  minorDeviation,    // انحراف بسيط (< 100م)
  majorDeviation,    // انحراف كبير (> 100م)
  wrongDirection,    // اتجاه خاطئ
  missedWaypoint,    // تجاوز نقطة
}

/// خطورة الانحراف
enum DeviationSeverity {
  none,     // لا يوجد انحراف
  low,      // منخفض
  medium,   // متوسط
  high,     // عالي
  critical, // حرج
}

/// كيان الانحراف عن المسار
class Deviation extends Equatable {
  final String id;
  final String tripId;
  final DeviationType type;
  final DeviationSeverity severity;
  
  // معلومات الموقع
  final Location deviationLocation;
  final Location? expectedLocation;
  final Location nearestPointOnRoute; // أقرب نقطة على المسار
  final double distanceFromRoute;
  
  // معلومات الوقت
  final DateTime detectedAt;
  final DateTime? resolvedAt;
  final Duration? duration;
  
  // معلومات إضافية
  final String? description;
  final String? waypointId; // إذا كان متعلق بنقطة معينة
  final bool isResolved;

  const Deviation({
    required this.id,
    required this.tripId,
    required this.type,
    required this.severity,
    required this.deviationLocation,
    required this.nearestPointOnRoute,
    required this.distanceFromRoute,
    required this.detectedAt,
    this.expectedLocation,
    this.resolvedAt,
    this.duration,
    this.description,
    this.waypointId,
    this.isResolved = false,
  });

  @override
  List<Object?> get props => [
        id,
        tripId,
        type,
        severity,
        deviationLocation,
        expectedLocation,
        nearestPointOnRoute,
        distanceFromRoute,
        detectedAt,
        resolvedAt,
        duration,
        description,
        waypointId,
        isResolved,
      ];
  
  /// اختصار للمسافة
  double get distance => distanceFromRoute;

  /// نسخ مع تعديلات
  Deviation copyWith({
    String? id,
    String? tripId,
    DeviationType? type,
    DeviationSeverity? severity,
    Location? deviationLocation,
    Location? expectedLocation,
    Location? nearestPointOnRoute,
    double? distanceFromRoute,
    DateTime? detectedAt,
    DateTime? resolvedAt,
    Duration? duration,
    String? description,
    String? waypointId,
    bool? isResolved,
  }) {
    return Deviation(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      type: type ?? this.type,
      severity: severity ?? this.severity,
      deviationLocation: deviationLocation ?? this.deviationLocation,
      expectedLocation: expectedLocation ?? this.expectedLocation,
      nearestPointOnRoute: nearestPointOnRoute ?? this.nearestPointOnRoute,
      distanceFromRoute: distanceFromRoute ?? this.distanceFromRoute,
      detectedAt: detectedAt ?? this.detectedAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      duration: duration ?? this.duration,
      description: description ?? this.description,
      waypointId: waypointId ?? this.waypointId,
      isResolved: isResolved ?? this.isResolved,
    );
  }

  /// حل الانحراف
  Deviation resolve() {
    final now = DateTime.now();
    return copyWith(
      isResolved: true,
      resolvedAt: now,
      duration: now.difference(detectedAt),
    );
  }

  /// هل الانحراف نشط؟
  bool get isActive => !isResolved;

  /// مدة الانحراف حتى الآن
  Duration get currentDuration {
    final end = resolvedAt ?? DateTime.now();
    return end.difference(detectedAt);
  }

  /// تحديد الخطورة بناءً على المسافة
  static DeviationSeverity calculateSeverity(double distance) {
    if (distance < 50) return DeviationSeverity.low;
    if (distance < 100) return DeviationSeverity.medium;
    if (distance < 200) return DeviationSeverity.high;
    return DeviationSeverity.critical;
  }

  /// تحديد النوع بناءً على المسافة والسياق
  static DeviationType calculateType({
    required double distance,
    bool? missedWaypoint,
    bool? wrongDirection,
  }) {
    if (missedWaypoint == true) return DeviationType.missedWaypoint;
    if (wrongDirection == true) return DeviationType.wrongDirection;
    if (distance > 100) return DeviationType.majorDeviation;
    return DeviationType.minorDeviation;
  }

  /// الحصول على لون الخطورة
  static String getSeverityColor(DeviationSeverity severity) {
    switch (severity) {
      case DeviationSeverity.none:
        return '#4CAF50'; // Green
      case DeviationSeverity.low:
        return '#FFA726'; // Orange
      case DeviationSeverity.medium:
        return '#FF7043'; // Deep Orange
      case DeviationSeverity.high:
        return '#E53935'; // Red
      case DeviationSeverity.critical:
        return '#C62828'; // Dark Red
    }
  }

  /// الحصول على أيقونة النوع
  static String getTypeIcon(DeviationType type) {
    switch (type) {
      case DeviationType.minorDeviation:
        return 'warning';
      case DeviationType.majorDeviation:
        return 'error';
      case DeviationType.wrongDirection:
        return 'wrong_location';
      case DeviationType.missedWaypoint:
        return 'location_off';
    }
  }

  /// الحصول على وصف النوع
  static String getTypeDescription(DeviationType type) {
    switch (type) {
      case DeviationType.minorDeviation:
        return 'انحراف بسيط عن المسار';
      case DeviationType.majorDeviation:
        return 'انحراف كبير عن المسار';
      case DeviationType.wrongDirection:
        return 'اتجاه خاطئ';
      case DeviationType.missedWaypoint:
        return 'تجاوز نقطة في المسار';
    }
  }
}
