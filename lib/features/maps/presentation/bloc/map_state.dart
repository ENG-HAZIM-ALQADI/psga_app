import 'package:equatable/equatable.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:psga_app/features/maps/data/services/deviation_detector.dart';
import 'package:psga_app/features/maps/domain/entities/place_entity.dart';
import 'package:psga_app/features/trips/domain/entities/route_entity.dart';

/// حالات الخريطة
abstract class MapState extends Equatable {
  const MapState();

  @override
  List<Object?> get props => [];
}

/// الحالة الأولية
class MapInitial extends MapState {
  const MapInitial();
}

/// جاري التحميل
class MapLoading extends MapState {
  const MapLoading();
}

/// الخريطة جاهزة
class MapReady extends MapState {
  final LatLng? currentLocation;
  final Set<Marker> markers;
  final Set<Polyline> polylines;
  final MapType mapType;
  final RouteEntity? activeRoute;

  const MapReady({
    this.currentLocation,
    this.markers = const {},
    this.polylines = const {},
    this.mapType = MapType.normal,
    this.activeRoute,
  });

  MapReady copyWith({
    LatLng? currentLocation,
    Set<Marker>? markers,
    Set<Polyline>? polylines,
    MapType? mapType,
    RouteEntity? activeRoute,
  }) {
    return MapReady(
      currentLocation: currentLocation ?? this.currentLocation,
      markers: markers ?? this.markers,
      polylines: polylines ?? this.polylines,
      mapType: mapType ?? this.mapType,
      activeRoute: activeRoute ?? this.activeRoute,
    );
  }

  @override
  List<Object?> get props => [
        currentLocation,
        markers,
        polylines,
        mapType,
        activeRoute,
      ];
}

/// الخريطة في وضع التتبع
class MapTracking extends MapState {
  final LatLng currentLocation;
  final RouteEntity? route;
  final DeviationResult? deviation;
  final List<LatLng> trackingHistory;
  final Set<Marker> markers;
  final Set<Polyline> polylines;
  final MapType mapType;

  const MapTracking({
    required this.currentLocation,
    this.route,
    this.deviation,
    this.trackingHistory = const [],
    this.markers = const {},
    this.polylines = const {},
    this.mapType = MapType.normal,
  });

  MapTracking copyWith({
    LatLng? currentLocation,
    RouteEntity? route,
    DeviationResult? deviation,
    List<LatLng>? trackingHistory,
    Set<Marker>? markers,
    Set<Polyline>? polylines,
    MapType? mapType,
  }) {
    return MapTracking(
      currentLocation: currentLocation ?? this.currentLocation,
      route: route ?? this.route,
      deviation: deviation ?? this.deviation,
      trackingHistory: trackingHistory ?? this.trackingHistory,
      markers: markers ?? this.markers,
      polylines: polylines ?? this.polylines,
      mapType: mapType ?? this.mapType,
    );
  }

  @override
  List<Object?> get props => [
        currentLocation,
        route,
        deviation,
        trackingHistory,
        markers,
        polylines,
        mapType,
      ];
}

/// نتائج البحث
class MapSearchResults extends MapState {
  final List<PlaceEntity> places;

  const MapSearchResults(this.places);

  @override
  List<Object?> get props => [places];
}

/// خطأ في الخريطة
class MapError extends MapState {
  final String message;

  const MapError(this.message);

  @override
  List<Object?> get props => [message];
}

/// تم اكتشاف انحراف
class DeviationDetectedState extends MapState {
  final DeviationResult deviation;
  final LatLng currentLocation;

  const DeviationDetectedState({
    required this.deviation,
    required this.currentLocation,
  });

  @override
  List<Object?> get props => [deviation, currentLocation];
}

/// صلاحية الموقع مرفوضة
class LocationPermissionDenied extends MapState {
  const LocationPermissionDenied();
}

/// خدمة الموقع معطلة
class LocationServiceDisabled extends MapState {
  const LocationServiceDisabled();
}
