import 'package:equatable/equatable.dart';
import 'package:psga_app/features/routes/domain/entities/location.dart';
import 'package:psga_app/features/trips/domain/entities/deviation.dart';

/// أحداث الرحلات
sealed class TripEvent extends Equatable {
  const TripEvent();

  @override
  List<Object?> get props => [];
}

/// بدء رحلة جديدة
class StartTripEvent extends TripEvent {
  final String userId;
  final String routeId;
  final bool forceEndActiveTrip; // إنهاء الرحلة النشطة تلقائياً

  const StartTripEvent({
    required this.userId,
    required this.routeId,
    this.forceEndActiveTrip = false,
  });

  @override
  List<Object> get props => [userId, routeId, forceEndActiveTrip];
}

/// إنهاء رحلة
class EndTripEvent extends TripEvent {
  final String tripId;

  const EndTripEvent({required this.tripId});

  @override
  List<Object> get props => [tripId];
}

/// إيقاف رحلة مؤقتاً
class PauseTripEvent extends TripEvent {
  final String tripId;

  const PauseTripEvent({required this.tripId});

  @override
  List<Object> get props => [tripId];
}

/// استئناف رحلة
class ResumeTripEvent extends TripEvent {
  final String tripId;

  const ResumeTripEvent({required this.tripId});

  @override
  List<Object> get props => [tripId];
}

/// إلغاء رحلة
class CancelTripEvent extends TripEvent {
  final String tripId;

  const CancelTripEvent({required this.tripId});

  @override
  List<Object> get props => [tripId];
}

/// تحديث موقع الرحلة
class UpdateLocationEvent extends TripEvent {
  final String tripId;
  final Location location;

  const UpdateLocationEvent({
    required this.tripId,
    required this.location,
  });

  @override
  List<Object> get props => [tripId, location];
}

/// تحميل الرحلة النشطة
class LoadActiveTripEvent extends TripEvent {
  final String userId;

  const LoadActiveTripEvent({required this.userId});

  @override
  List<Object> get props => [userId];
}

/// تحميل سجل الرحلات
class LoadTripHistoryEvent extends TripEvent {
  final String userId;
  final int? limit;
  final DateTime? startDate;
  final DateTime? endDate;

  const LoadTripHistoryEvent({
    required this.userId,
    this.limit,
    this.startDate,
    this.endDate,
  });

  @override
  List<Object?> get props => [userId, limit, startDate, endDate];
}

/// تحميل تفاصيل رحلة
class LoadTripDetailsEvent extends TripEvent {
  final String tripId;

  const LoadTripDetailsEvent({required this.tripId});

  @override
  List<Object> get props => [tripId];
}

/// تحديث الرحلة
class RefreshActiveTripEvent extends TripEvent {
  final String userId;

  const RefreshActiveTripEvent({required this.userId});

  @override
  List<Object> get props => [userId];
}

/// حذف رحلة
class DeleteTripEvent extends TripEvent {
  final String tripId;

  const DeleteTripEvent({required this.tripId});

  @override
  List<Object> get props => [tripId];
}

/// تحديث نقطة طريق
class UpdateWaypointProgressEvent extends TripEvent {
  final String tripId;
  final String waypointId;
  final bool visited;

  const UpdateWaypointProgressEvent({
    required this.tripId,
    required this.waypointId,
    required this.visited,
  });

  @override
  List<Object> get props => [tripId, waypointId, visited];
}

/// إضافة انحراف
class AddDeviationEvent extends TripEvent {
  final String tripId;
  final Deviation deviation;

  const AddDeviationEvent({
    required this.tripId,
    required this.deviation,
  });

  @override
  List<Object> get props => [tripId, deviation];
}

/// حل الانحراف الحالي
class ResolveCurrentDeviationEvent extends TripEvent {
  final String tripId;

  const ResolveCurrentDeviationEvent({required this.tripId});

  @override
  List<Object> get props => [tripId];
}

/// بدء التتبع التلقائي
class StartAutoTrackingEvent extends TripEvent {
  final String tripId;

  const StartAutoTrackingEvent({required this.tripId});

  @override
  List<Object> get props => [tripId];
}

/// إيقاف التتبع التلقائي
class StopAutoTrackingEvent extends TripEvent {
  const StopAutoTrackingEvent();
}

/// تحديث الإحصائيات
class UpdateTripStatsEvent extends TripEvent {
  const UpdateTripStatsEvent();
}

/// فحص الانحراف
class CheckDeviationEvent extends TripEvent {
  final Location location;

  const CheckDeviationEvent({required this.location});

  @override
  List<Object> get props => [location];
}

/// تأكيد "أنا بخير"
class DismissDeviationAlertEvent extends TripEvent {
  final String tripId;

  const DismissDeviationAlertEvent({required this.tripId});

  @override
  List<Object> get props => [tripId];
}

/// تفعيل طوارئ (SOS)
class TriggerSOSEvent extends TripEvent {
  final String tripId;
  final Location currentLocation;

  const TriggerSOSEvent({
    required this.tripId,
    required this.currentLocation,
  });

  @override
  List<Object> get props => [tripId, currentLocation];
}

/// بدء العد التنازلي للانحراف
class StartDeviationCountdownEvent extends TripEvent {
  final Deviation deviation;

  const StartDeviationCountdownEvent({required this.deviation});

  @override
  List<Object> get props => [deviation];
}

/// إلغاء العد التنازلي
class CancelDeviationCountdownEvent extends TripEvent {
  const CancelDeviationCountdownEvent();
}

/// التحقق من موقع المستخدم قبل بدء الرحلة
class ValidateUserLocationEvent extends TripEvent {
  final String userId;
  final String routeId;

  const ValidateUserLocationEvent({
    required this.userId,
    required this.routeId,
  });

  @override
  List<Object> get props => [userId, routeId];
}

/// بدء الرحلة من الموقع الحالي (تحديث نقطة البداية)
/// يُستخدم عندما يكون المستخدم بعيداً عن نقطة البداية الأصلية
class StartTripFromCurrentLocationEvent extends TripEvent {
  final String userId;
  final String routeId;

  const StartTripFromCurrentLocationEvent({
    required this.userId,
    required this.routeId,
  });

  @override
  List<Object> get props => [userId, routeId];
}


/// مسح جميع سجل الرحلات
class ClearAllTripsEvent extends TripEvent {
  final String userId;
  
  const ClearAllTripsEvent({required this.userId});
  
  @override
  List<Object?> get props => [userId];
}
