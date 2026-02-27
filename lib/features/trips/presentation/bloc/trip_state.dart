import 'package:equatable/equatable.dart';
import 'package:psga_app/features/trips/domain/entities/trip_entity.dart';
import 'package:psga_app/features/trips/domain/entities/deviation.dart';

/// حالات الرحلات
sealed class TripState extends Equatable {
  const TripState();

  @override
  List<Object?> get props => [];
}

/// الحالة الأولية
class TripInitial extends TripState {
  const TripInitial();
}

/// جاري التحميل
class TripLoading extends TripState {
  const TripLoading();
}

/// رحلة نشطة
class TripActive extends TripState {
  final TripEntity trip;

  const TripActive({required this.trip});

  @override
  List<Object> get props => [trip];
}

/// رحلة متوقفة مؤقتاً
class TripPaused extends TripState {
  final TripEntity trip;

  const TripPaused({required this.trip});

  @override
  List<Object> get props => [trip];
}

/// رحلة مكتملة
class TripCompleted extends TripState {
  final TripEntity trip;

  const TripCompleted({required this.trip});

  @override
  List<Object> get props => [trip];
}

/// لا توجد رحلة نشطة
class NoActiveTrip extends TripState {
  const NoActiveTrip();
}

/// تم تحميل سجل الرحلات
class TripHistoryLoaded extends TripState {
  final List<TripEntity> trips;
  final int totalCount;

  const TripHistoryLoaded({
    required this.trips,
    required this.totalCount,
  });

  @override
  List<Object> get props => [trips, totalCount];
}

/// تم تحميل تفاصيل الرحلة
class TripDetailsLoaded extends TripState {
  final TripEntity trip;

  const TripDetailsLoaded({required this.trip});

  @override
  List<Object> get props => [trip];
}

/// خطأ في الرحلات
class TripError extends TripState {
  final String message;

  const TripError({required this.message});

  @override
  List<Object> get props => [message];
}

/// يوجد رحلة نشطة بالفعل - يتطلب اختيار المستخدم
class TripActiveTripExists extends TripState {
  final String message;
  final String activeTripId;
  final String routeId; // المسار المطلوب للرحلة الجديدة

  const TripActiveTripExists({
    required this.message,
    required this.activeTripId,
    required this.routeId,
  });

  @override
  List<Object> get props => [message, activeTripId, routeId];
}

/// عملية نجحت (مع رسالة)
class TripOperationSuccess extends TripState {
  final String message;
  final TripEntity? trip;

  const TripOperationSuccess({
    required this.message,
    this.trip,
  });

  @override
  List<Object?> get props => [message, trip];
}

/// جاري تحديث الموقع
class TripLocationUpdating extends TripState {
  final TripEntity trip;
  final bool isUpdating;

  const TripLocationUpdating({
    required this.trip,
    this.isUpdating = true,
  });

  @override
  List<Object> get props => [trip, isUpdating];
}

/// تم إضافة انحراف
class DeviationAdded extends TripState {
  final TripEntity trip;
  final Deviation deviation;

  const DeviationAdded({
    required this.trip,
    required this.deviation,
  });

  @override
  List<Object> get props => [trip, deviation];
}

/// تم حل الانحراف
class DeviationResolved extends TripState {
  final TripEntity trip;

  const DeviationResolved({required this.trip});

  @override
  List<Object> get props => [trip];
}

/// تم تحديث نقطة طريق
class WaypointProgressUpdated extends TripState {
  final TripEntity trip;
  final String waypointId;
  final bool visited;

  const WaypointProgressUpdated({
    required this.trip,
    required this.waypointId,
    required this.visited,
  });

  @override
  List<Object> get props => [trip, waypointId, visited];
}

/// حالة الإحصائيات المحدثة
class TripStatsUpdated extends TripState {
  final TripEntity trip;
  final double currentSpeed; // السرعة الحالية (كم/س)
  final double distanceTraveled; // المسافة المقطوعة (كم)
  final Duration elapsed; // الوقت المنقضي
  final double remainingDistance; // المسافة المتبقية (كم)
  final Duration? estimatedTime; // الوقت المتوقع للوصول

  const TripStatsUpdated({
    required this.trip,
    required this.currentSpeed,
    required this.distanceTraveled,
    required this.elapsed,
    required this.remainingDistance,
    this.estimatedTime,
  });

  @override
  List<Object?> get props => [
        trip,
        currentSpeed,
        distanceTraveled,
        elapsed,
        remainingDistance,
        estimatedTime,
      ];
}

/// حالة الانحراف المكتشف
class DeviationDetectedState extends TripState {
  final TripEntity trip;
  final Deviation deviation;
  final bool isActive; // هل التنبيه نشط

  const DeviationDetectedState({
    required this.trip,
    required this.deviation,
    this.isActive = true,
  });

  @override
  List<Object> get props => [trip, deviation, isActive];
}

/// حالة العد التنازلي
class DeviationCountdownState extends TripState {
  final TripEntity trip;
  final Deviation deviation;
  final int secondsRemaining; // الثواني المتبقية

  const DeviationCountdownState({
    required this.trip,
    required this.deviation,
    required this.secondsRemaining,
  });

  @override
  List<Object> get props => [trip, deviation, secondsRemaining];
}

/// حالة الطوارئ
class TripEmergencyState extends TripState {
  final TripEntity trip;
  final DateTime triggeredAt;

  const TripEmergencyState({
    required this.trip,
    required this.triggeredAt,
  });

  @override
  List<Object> get props => [trip, triggeredAt];
}

/// حالة التتبع النشط
class TripTrackingActive extends TripState {
  final TripEntity trip;
  final bool isTracking;

  const TripTrackingActive({
    required this.trip,
    required this.isTracking,
  });

  @override
  List<Object> get props => [trip, isTracking];
}

/// حالة: المستخدم بعيد عن نقطة البداية
class TripUserFarFromStartPoint extends TripState {
  final String routeId;
  final String routeName;
  final double distanceFromStart; // المسافة من نقطة البداية بالمتر
  final String userId;

  const TripUserFarFromStartPoint({
    required this.routeId,
    required this.routeName,
    required this.distanceFromStart,
    required this.userId,
  });

  @override
  List<Object> get props => [routeId, routeName, distanceFromStart, userId];
}

/// تم حذف رحلة
class TripDeleted extends TripState {
  final String tripId;
  
  const TripDeleted({required this.tripId});
  
  @override
  List<Object?> get props => [tripId];
}

/// تم مسح جميع سجل الرحلات
class TripHistoryCleared extends TripState {
  const TripHistoryCleared();
  
  @override
  List<Object?> get props => [];
}
