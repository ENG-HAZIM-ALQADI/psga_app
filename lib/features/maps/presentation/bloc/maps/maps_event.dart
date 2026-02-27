import 'package:equatable/equatable.dart';
import 'package:psga_app/features/routes/domain/entities/location.dart';
import 'package:psga_app/features/maps/domain/entities/place_entity.dart';

/// الأحداث الخاصة بالخرائط والاتجاهات
abstract class MapsEvent extends Equatable {
  const MapsEvent();

  @override
  List<Object?> get props => [];
}

// ==================== Directions Events ====================

/// الحصول على الاتجاهات بين نقطتين
class GetDirectionsEvent extends MapsEvent {
  final Location origin;
  final Location destination;
  final List<Location>? waypoints;
  final String travelMode;

  const GetDirectionsEvent({
    required this.origin,
    required this.destination,
    this.waypoints,
    this.travelMode = 'driving',
  });

  @override
  List<Object?> get props => [origin, destination, waypoints, travelMode];
}

/// الحصول على مسارات بديلة
class GetAlternativeRoutesEvent extends MapsEvent {
  final Location origin;
  final Location destination;

  const GetAlternativeRoutesEvent({
    required this.origin,
    required this.destination,
  });

  @override
  List<Object?> get props => [origin, destination];
}

/// مسح الاتجاهات الحالية
class ClearDirectionsEvent extends MapsEvent {
  const ClearDirectionsEvent();
}

// ==================== Places Events ====================

/// البحث عن أماكن
class SearchPlacesEvent extends MapsEvent {
  final String query;
  final Location? location;
  final int radius;
  final PlaceType? type;

  const SearchPlacesEvent({
    required this.query,
    this.location,
    this.radius = 5000,
    this.type,
  });

  @override
  List<Object?> get props => [query, location, radius, type];
}

/// البحث عن أماكن قريبة
class SearchNearbyPlacesEvent extends MapsEvent {
  final Location location;
  final int radius;
  final PlaceType? type;
  final String? keyword;

  const SearchNearbyPlacesEvent({
    required this.location,
    this.radius = 5000,
    this.type,
    this.keyword,
  });

  @override
  List<Object?> get props => [location, radius, type, keyword];
}

/// الحصول على تفاصيل مكان
class GetPlaceDetailsEvent extends MapsEvent {
  final String placeId;
  final Location? currentLocation;

  const GetPlaceDetailsEvent({
    required this.placeId,
    this.currentLocation,
  });

  @override
  List<Object?> get props => [placeId, currentLocation];
}

/// الحصول على أقرب مكان من نوع معين
class GetNearestPlaceEvent extends MapsEvent {
  final Location location;
  final PlaceType type;
  final int radius;

  const GetNearestPlaceEvent({
    required this.location,
    required this.type,
    this.radius = 5000,
  });

  @override
  List<Object?> get props => [location, type, radius];
}

/// الحصول على أماكن الطوارئ
class GetEmergencyPlacesEvent extends MapsEvent {
  final Location location;
  final int radius;

  const GetEmergencyPlacesEvent({
    required this.location,
    this.radius = 10000,
  });

  @override
  List<Object?> get props => [location, radius];
}

/// مسح نتائج البحث
class ClearPlacesEvent extends MapsEvent {
  const ClearPlacesEvent();
}

// ==================== Offline Maps Events ====================

/// تنزيل منطقة للاستخدام الأوفلاين
class DownloadMapRegionEvent extends MapsEvent {
  final Location center;
  final double radiusKm;
  final List<int>? zoomLevels;

  const DownloadMapRegionEvent({
    required this.center,
    required this.radiusKm,
    this.zoomLevels,
  });

  @override
  List<Object?> get props => [center, radiusKm, zoomLevels];
}

/// الحصول على المناطق المحفوظة
class GetSavedRegionsEvent extends MapsEvent {
  const GetSavedRegionsEvent();
}

/// حذف منطقة محفوظة
class DeleteRegionEvent extends MapsEvent {
  final String regionId;

  const DeleteRegionEvent(this.regionId);

  @override
  List<Object?> get props => [regionId];
}

/// مسح جميع الخرائط المحفوظة
class ClearAllMapsEvent extends MapsEvent {
  const ClearAllMapsEvent();
}

/// تحديث تقدم التنزيل
class UpdateDownloadProgressEvent extends MapsEvent {
  final double progress;
  final String status;

  const UpdateDownloadProgressEvent({
    required this.progress,
    required this.status,
  });

  @override
  List<Object?> get props => [progress, status];
}
