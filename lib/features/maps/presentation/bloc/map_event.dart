import 'package:equatable/equatable.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:psga_app/features/maps/domain/entities/place_entity.dart';
import 'package:psga_app/features/trips/domain/entities/route_entity.dart';

/// أحداث الخريطة
abstract class MapEvent extends Equatable {
  const MapEvent();

  @override
  List<Object?> get props => [];
}

/// تهيئة الخريطة
class InitializeMap extends MapEvent {
  const InitializeMap();
}

/// تحميل الموقع الحالي
class LoadCurrentLocation extends MapEvent {
  const LoadCurrentLocation();
}

/// بدء تتبع الموقع
class StartLocationTracking extends MapEvent {
  const StartLocationTracking();
}

/// إيقاف تتبع الموقع
class StopLocationTracking extends MapEvent {
  const StopLocationTracking();
}

/// تحديث الموقع
class UpdateLocation extends MapEvent {
  final LatLng position;

  const UpdateLocation(this.position);

  @override
  List<Object?> get props => [position];
}

/// تعيين المسار
class SetRoute extends MapEvent {
  final RouteEntity route;

  const SetRoute(this.route);

  @override
  List<Object?> get props => [route];
}

/// مسح المسار
class ClearRoute extends MapEvent {
  const ClearRoute();
}

/// البحث عن مكان
class SearchPlace extends MapEvent {
  final String query;

  const SearchPlace(this.query);

  @override
  List<Object?> get props => [query];
}

/// اختيار مكان
class SelectPlace extends MapEvent {
  final PlaceEntity place;

  const SelectPlace(this.place);

  @override
  List<Object?> get props => [place];
}

/// فحص الانحراف
class CheckDeviation extends MapEvent {
  const CheckDeviation();
}

/// تكبير على موقع
class ZoomToLocation extends MapEvent {
  final LatLng location;
  final double zoom;

  const ZoomToLocation(this.location, {this.zoom = 15});

  @override
  List<Object?> get props => [location, zoom];
}

/// تكبير على المسار
class ZoomToRoute extends MapEvent {
  const ZoomToRoute();
}

/// تغيير نوع الخريطة
class ChangeMapType extends MapEvent {
  final MapType mapType;

  const ChangeMapType(this.mapType);

  @override
  List<Object?> get props => [mapType];
}

/// تحديث controller الخريطة
class MapControllerUpdated extends MapEvent {
  final GoogleMapController controller;

  const MapControllerUpdated(this.controller);

  @override
  List<Object?> get props => [controller];
}
