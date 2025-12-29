import 'dart:async';
import 'dart:ui';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:psga_app/core/utils/logger.dart';
import 'package:psga_app/features/maps/data/services/deviation_detector.dart';
import 'package:psga_app/features/maps/data/services/geocoding_service.dart';
import 'package:psga_app/features/maps/data/services/location_service.dart';
import 'package:psga_app/features/maps/domain/entities/place_entity.dart';
import 'package:psga_app/features/trips/domain/entities/location_entity.dart';
import 'map_event.dart';
import 'map_state.dart';

/// إدارة حالة الخريطة
class MapBloc extends Bloc<MapEvent, MapState> {
  final LocationService _locationService;
  final GeocodingService _geocodingService;
  final DeviationDetector _deviationDetector;

  GoogleMapController? _mapController;
  StreamSubscription<Position>? _locationSubscription;
  final List<LatLng> _trackingHistory = [];

  MapBloc({
    LocationService? locationService,
    GeocodingService? geocodingService,
    DeviationDetector? deviationDetector,
  })  : _locationService = locationService ?? LocationService(),
        _geocodingService = geocodingService ?? GeocodingService(),
        _deviationDetector = deviationDetector ?? DeviationDetector(),
        super(const MapInitial()) {
    on<InitializeMap>(_onInitializeMap);
    on<LoadCurrentLocation>(_onLoadCurrentLocation);
    on<StartLocationTracking>(_onStartLocationTracking);
    on<StopLocationTracking>(_onStopLocationTracking);
    on<UpdateLocation>(_onUpdateLocation);
    on<SetRoute>(_onSetRoute);
    on<ClearRoute>(_onClearRoute);
    on<SearchPlace>(_onSearchPlace);
    on<SelectPlace>(_onSelectPlace);
    on<CheckDeviation>(_onCheckDeviation);
    on<ZoomToLocation>(_onZoomToLocation);
    on<ZoomToRoute>(_onZoomToRoute);
    on<ChangeMapType>(_onChangeMapType);
    on<MapControllerUpdated>(_onMapControllerUpdated);
  }

  /// تهيئة الخريطة
  Future<void> _onInitializeMap(
    InitializeMap event,
    Emitter<MapState> emit,
  ) async {
    emit(const MapLoading());
    AppLogger.info('[MapBloc] تهيئة الخريطة');

    final hasPermission = await _locationService.checkPermissions();
    if (!hasPermission) {
      final isEnabled = await _locationService.isLocationServiceEnabled();
      if (!isEnabled) {
        emit(const LocationServiceDisabled());
      } else {
        emit(const LocationPermissionDenied());
      }
      return;
    }

    final position = await _locationService.getCurrentPosition();
    if (position != null) {
      emit(MapReady(
        currentLocation: LatLng(position.latitude, position.longitude),
      ));
    } else {
      emit(const MapReady());
    }
  }

  /// تحميل الموقع الحالي
  Future<void> _onLoadCurrentLocation(
    LoadCurrentLocation event,
    Emitter<MapState> emit,
  ) async {
    final position = await _locationService.getCurrentPosition();
    if (position != null) {
      final currentLocation = LatLng(position.latitude, position.longitude);

      if (state is MapReady) {
        emit((state as MapReady).copyWith(currentLocation: currentLocation));
      } else if (state is MapTracking) {
        emit((state as MapTracking).copyWith(currentLocation: currentLocation));
      } else {
        emit(MapReady(currentLocation: currentLocation));
      }

      _animateToLocation(currentLocation);
    }
  }

  /// بدء تتبع الموقع
  Future<void> _onStartLocationTracking(
    StartLocationTracking event,
    Emitter<MapState> emit,
  ) async {
    AppLogger.info('[MapBloc] بدء تتبع الموقع');
    _trackingHistory.clear();

    await _locationService.startTracking();

    _locationSubscription = _locationService.positionStream.listen(
      (position) {
        add(UpdateLocation(LatLng(position.latitude, position.longitude)));
      },
    );

    final position = await _locationService.getCurrentPosition();
    if (position != null) {
      final currentLocation = LatLng(position.latitude, position.longitude);
      _trackingHistory.add(currentLocation);

      emit(MapTracking(
        currentLocation: currentLocation,
        trackingHistory: List.from(_trackingHistory),
      ));
    }
  }

  /// إيقاف تتبع الموقع
  Future<void> _onStopLocationTracking(
    StopLocationTracking event,
    Emitter<MapState> emit,
  ) async {
    AppLogger.info('[MapBloc] إيقاف تتبع الموقع');

    await _locationSubscription?.cancel();
    _locationSubscription = null;
    await _locationService.stopTracking();

    if (state is MapTracking) {
      final trackingState = state as MapTracking;
      emit(MapReady(
        currentLocation: trackingState.currentLocation,
        markers: trackingState.markers,
        polylines: trackingState.polylines,
        mapType: trackingState.mapType,
      ));
    }
  }

  /// تحديث الموقع
  Future<void> _onUpdateLocation(
    UpdateLocation event,
    Emitter<MapState> emit,
  ) async {
    _trackingHistory.add(event.position);

    if (state is MapTracking) {
      final trackingState = state as MapTracking;

      DeviationResult? deviation;
      if (_deviationDetector.hasRoute()) {
        deviation = _deviationDetector.checkDeviation(event.position);
      }

      final updatedPolylines = _buildTrackingPolylines(trackingState);

      emit(trackingState.copyWith(
        currentLocation: event.position,
        trackingHistory: List.from(_trackingHistory),
        deviation: deviation,
        polylines: updatedPolylines,
      ));

      _animateToLocation(event.position);
    }
  }

  /// تعيين المسار
  Future<void> _onSetRoute(
    SetRoute event,
    Emitter<MapState> emit,
  ) async {
    AppLogger.info('[MapBloc] تعيين المسار: ${event.route.name}');

    final routePoints = event.route.waypoints
        .map((w) => LatLng(w.location.latitude, w.location.longitude))
        .toList();

    _deviationDetector.setRoute(routePoints);

    final polylines = <Polyline>{
      Polyline(
        polylineId: const PolylineId('route'),
        points: routePoints,
        color: const Color(0xFF2196F3),
        width: 5,
      ),
    };

    final markers = _buildRouteMarkers(event.route);

    if (state is MapReady) {
      emit((state as MapReady).copyWith(
        polylines: polylines,
        markers: markers,
        activeRoute: event.route,
      ));
    } else if (state is MapTracking) {
      emit((state as MapTracking).copyWith(
        polylines: polylines,
        markers: markers,
        route: event.route,
      ));
    }
  }

  /// مسح المسار
  Future<void> _onClearRoute(
    ClearRoute event,
    Emitter<MapState> emit,
  ) async {
    AppLogger.info('[MapBloc] مسح المسار');
    _deviationDetector.clearRoute();

    if (state is MapReady) {
      emit((state as MapReady).copyWith(
        polylines: {},
        markers: {},
        activeRoute: null,
      ));
    } else if (state is MapTracking) {
      emit((state as MapTracking).copyWith(
        polylines: {},
        markers: {},
        route: null,
      ));
    }
  }

  /// البحث عن مكان (مع debounce تلقائي)
  Future<void> _onSearchPlace(
    SearchPlace event,
    Emitter<MapState> emit,
  ) async {
    if (event.query.isEmpty) {
      return;
    }

    AppLogger.info('[MapBloc] البحث عن: ${event.query}');
    final suggestions = await _geocodingService.searchPlaces(event.query);

    final places = suggestions
        .where((s) => s.latitude != null && s.longitude != null)
        .map((s) => PlaceEntity(
              placeId: s.placeId,
              name: s.mainText,
              address: s.description,
              location: LocationEntity(
                latitude: s.latitude!,
                longitude: s.longitude!,
                timestamp: DateTime.now(),
              ),
            ))
        .toList();

    emit(MapSearchResults(places));
  }

  /// اختيار مكان
  Future<void> _onSelectPlace(
    SelectPlace event,
    Emitter<MapState> emit,
  ) async {
    final location = LatLng(
      event.place.location.latitude,
      event.place.location.longitude,
    );

    final marker = Marker(
      markerId: MarkerId(event.place.placeId),
      position: location,
      infoWindow: InfoWindow(
        title: event.place.name,
        snippet: event.place.address,
      ),
    );

    emit(MapReady(
      currentLocation: location,
      markers: {marker},
    ));

    _animateToLocation(location, zoom: 16);
  }

  /// فحص الانحراف
  Future<void> _onCheckDeviation(
    CheckDeviation event,
    Emitter<MapState> emit,
  ) async {
    if (state is MapTracking) {
      final trackingState = state as MapTracking;
      final deviation =
          _deviationDetector.checkDeviation(trackingState.currentLocation);

      if (deviation.isDeviated) {
        emit(DeviationDetectedState(
          deviation: deviation,
          currentLocation: trackingState.currentLocation,
        ));
      }
    }
  }

  /// تكبير على موقع
  Future<void> _onZoomToLocation(
    ZoomToLocation event,
    Emitter<MapState> emit,
  ) async {
    _animateToLocation(event.location, zoom: event.zoom);
  }

  /// تكبير على المسار
  Future<void> _onZoomToRoute(
    ZoomToRoute event,
    Emitter<MapState> emit,
  ) async {
    if (_deviationDetector.hasRoute()) {
      final bounds = _calculateBounds(_deviationDetector.routePoints);
      _mapController?.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 50),
      );
    }
  }

  /// تغيير نوع الخريطة
  Future<void> _onChangeMapType(
    ChangeMapType event,
    Emitter<MapState> emit,
  ) async {
    if (state is MapReady) {
      emit((state as MapReady).copyWith(mapType: event.mapType));
    } else if (state is MapTracking) {
      emit((state as MapTracking).copyWith(mapType: event.mapType));
    }
  }

  /// تحديث controller الخريطة
  Future<void> _onMapControllerUpdated(
    MapControllerUpdated event,
    Emitter<MapState> emit,
  ) async {
    _mapController = event.controller;
  }

  /// تحريك الخريطة إلى موقع
  void _animateToLocation(LatLng location, {double zoom = 15}) {
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: location, zoom: zoom),
      ),
    );
  }

  /// بناء polylines للتتبع
  Set<Polyline> _buildTrackingPolylines(MapTracking state) {
    final polylines = <Polyline>{...state.polylines};

    polylines.add(Polyline(
      polylineId: const PolylineId('tracking'),
      points: _trackingHistory,
      color: const Color(0xFF4CAF50),
      width: 4,
    ));

    return polylines;
  }

  /// بناء علامات المسار
  Set<Marker> _buildRouteMarkers(route) {
    final markers = <Marker>{};

    if (route.waypoints.isNotEmpty) {
      final start = route.waypoints.first;
      markers.add(Marker(
        markerId: const MarkerId('start'),
        position: LatLng(start.location.latitude, start.location.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: const InfoWindow(title: 'نقطة البداية'),
      ));

      if (route.waypoints.length > 1) {
        final end = route.waypoints.last;
        markers.add(Marker(
          markerId: const MarkerId('end'),
          position: LatLng(end.location.latitude, end.location.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: const InfoWindow(title: 'نقطة النهاية'),
        ));
      }
    }

    return markers;
  }

  /// حساب حدود مجموعة نقاط
  LatLngBounds _calculateBounds(List<LatLng> points) {
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

  @override
  Future<void> close() {
    _locationSubscription?.cancel();
    _mapController?.dispose();
    return super.close();
  }
}
