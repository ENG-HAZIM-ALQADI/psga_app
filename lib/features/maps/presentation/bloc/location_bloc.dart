import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:psga_app/core/utils/logger.dart';
import 'package:psga_app/features/maps/data/services/geocoding_service.dart';
import 'package:psga_app/features/maps/data/services/location_service.dart';
import 'location_event.dart';
import 'location_state.dart';

/// إدارة حالة الموقع
class LocationBloc extends Bloc<LocationEvent, LocationState> {
  final LocationService _locationService;
  final GeocodingService _geocodingService;

  StreamSubscription<Position>? _positionSubscription;
  final List<Position> _positionHistory = [];

  LocationBloc({
    LocationService? locationService,
    GeocodingService? geocodingService,
  })  : _locationService = locationService ?? LocationService(),
        _geocodingService = geocodingService ?? GeocodingService(),
        super(const LocationInitial()) {
    on<RequestLocationPermission>(_onRequestPermission);
    on<GetCurrentLocation>(_onGetCurrentLocation);
    on<StartTracking>(_onStartTracking);
    on<StopTracking>(_onStopTracking);
    on<LocationUpdated>(_onLocationUpdated);
    on<OpenLocationSettings>(_onOpenLocationSettings);
    on<OpenAppSettings>(_onOpenAppSettings);
  }

  /// طلب صلاحية الموقع
  Future<void> _onRequestPermission(
    RequestLocationPermission event,
    Emitter<LocationState> emit,
  ) async {
    emit(const LocationLoading());
    AppLogger.info('[LocationBloc] طلب صلاحيات الموقع');

    final isEnabled = await _locationService.isLocationServiceEnabled();
    if (!isEnabled) {
      emit(const LocationServiceDisabledState());
      return;
    }

    final hasPermission = await _locationService.checkPermissions();
    if (!hasPermission) {
      LocationPermission permission = await Geolocator.checkPermission();
      emit(PermissionRequired(
        isPermanentlyDenied: permission == LocationPermission.deniedForever,
      ));
      return;
    }

    AppLogger.success('[LocationBloc] الصلاحيات ممنوحة');
    add(const GetCurrentLocation());
  }

  /// الحصول على الموقع الحالي
  Future<void> _onGetCurrentLocation(
    GetCurrentLocation event,
    Emitter<LocationState> emit,
  ) async {
    emit(const LocationLoading());
    AppLogger.info('[LocationBloc] الحصول على الموقع الحالي');

    final position = await _locationService.getCurrentPosition();
    if (position == null) {
      emit(const LocationError('فشل في الحصول على الموقع'));
      return;
    }

    final address = await _geocodingService.getAddressFromCoordinates(
      position.latitude,
      position.longitude,
    );

    AppLogger.info(
        '[LocationBloc] الموقع: ${position.latitude}, ${position.longitude}');
    emit(LocationLoaded(position: position, address: address));
  }

  /// بدء التتبع
  Future<void> _onStartTracking(
    StartTracking event,
    Emitter<LocationState> emit,
  ) async {
    AppLogger.info('[LocationBloc] بدء تتبع الموقع');
    _positionHistory.clear();

    await _locationService.startTracking();

    _positionSubscription = _locationService.positionStream.listen(
      (position) {
        add(LocationUpdated(position));
      },
    );

    final currentPosition = await _locationService.getCurrentPosition();
    if (currentPosition != null) {
      _positionHistory.add(currentPosition);

      final address = await _geocodingService.getAddressFromCoordinates(
        currentPosition.latitude,
        currentPosition.longitude,
      );

      emit(LocationTracking(
        currentPosition: currentPosition,
        positions: List.from(_positionHistory),
        currentAddress: address,
      ));
    }
  }

  /// إيقاف التتبع
  Future<void> _onStopTracking(
    StopTracking event,
    Emitter<LocationState> emit,
  ) async {
    AppLogger.info('[LocationBloc] إيقاف تتبع الموقع');

    await _positionSubscription?.cancel();
    _positionSubscription = null;
    await _locationService.stopTracking();

    if (state is LocationTracking) {
      final trackingState = state as LocationTracking;
      emit(LocationLoaded(
        position: trackingState.currentPosition,
        address: trackingState.currentAddress,
      ));
    }
  }

  /// تحديث الموقع
  Future<void> _onLocationUpdated(
    LocationUpdated event,
    Emitter<LocationState> emit,
  ) async {
    _positionHistory.add(event.position);

    String? address;
    if (_positionHistory.length % 5 == 0) {
      address = await _geocodingService.getAddressFromCoordinates(
        event.position.latitude,
        event.position.longitude,
      );
    }

    emit(LocationTracking(
      currentPosition: event.position,
      positions: List.from(_positionHistory),
      currentAddress: address ?? (state is LocationTracking
          ? (state as LocationTracking).currentAddress
          : null),
    ));
  }

  /// فتح إعدادات الموقع
  Future<void> _onOpenLocationSettings(
    OpenLocationSettings event,
    Emitter<LocationState> emit,
  ) async {
    await _locationService.openLocationSettings();
  }

  /// فتح إعدادات التطبيق
  Future<void> _onOpenAppSettings(
    OpenAppSettings event,
    Emitter<LocationState> emit,
  ) async {
    await _locationService.openAppSettings();
  }

  /// تنظيف الموارد - إغلاق جميع الـ streams بشكل آمن
  @override
  Future<void> close() async {
    await _positionSubscription?.cancel();
    await _locationService.stopTracking();
    return super.close();
  }
}
