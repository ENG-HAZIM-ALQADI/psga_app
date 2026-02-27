import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:psga_app/core/services/location_service.dart';
import 'package:psga_app/features/routes/domain/entities/location.dart';
import 'package:psga_app/core/utils/logger.dart';

// Events
abstract class LocationEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class StartLocationTracking extends LocationEvent {}
class StopLocationTracking extends LocationEvent {}
class GetCurrentLocation extends LocationEvent {}
class LocationUpdated extends LocationEvent {
  final Location location;
  LocationUpdated(this.location);
  @override
  List<Object?> get props => [location];
}

// States
abstract class LocationState extends Equatable {
  @override
  List<Object?> get props => [];
}

class LocationInitial extends LocationState {}
class LocationLoading extends LocationState {}

class LocationLoaded extends LocationState {
  final Location location;
  final bool isTracking;
  
  LocationLoaded({
    required this.location,
    this.isTracking = false,
  });
  
  @override
  List<Object?> get props => [location, isTracking];
  
  LocationLoaded copyWith({Location? location, bool? isTracking}) {
    return LocationLoaded(
      location: location ?? this.location,
      isTracking: isTracking ?? this.isTracking,
    );
  }
}

class LocationError extends LocationState {
  final String message;
  LocationError(this.message);
  @override
  List<Object?> get props => [message];
}

class LocationPermissionDenied extends LocationState {}

// Bloc
class LocationBloc extends Bloc<LocationEvent, LocationState> {
  final LocationService _locationService = LocationService.instance;
  StreamSubscription<Location>? _locationSubscription;

  LocationBloc() : super(LocationInitial()) {
    on<StartLocationTracking>(_onStartTracking);
    on<StopLocationTracking>(_onStopTracking);
    on<GetCurrentLocation>(_onGetCurrentLocation);
    on<LocationUpdated>(_onLocationUpdated);
  }

  Future<void> _onStartTracking(
    StartLocationTracking event,
    Emitter<LocationState> emit,
  ) async {
    try {
      AppLogger.info('[LocationBloc] بدء التتبع');
      
      final success = await _locationService.startTracking(
        mode: LocationTrackingMode.foreground,
        intervalSeconds: 5,
        distanceFilter: 10,
      );
      
      if (!success) {
        emit(LocationPermissionDenied());
        return;
      }

      // الاستماع للموقع
      _locationSubscription = _locationService.locationStream.listen(
        (location) => add(LocationUpdated(location)),
      );

      // الحصول على الموقع الحالي
      final currentLocation = await _locationService.getCurrentLocation();
      if (currentLocation != null) {
        emit(LocationLoaded(location: currentLocation, isTracking: true));
      }
    } catch (e) {
      AppLogger.error('[LocationBloc] خطأ في بدء التتبع', e);
      emit(LocationError('فشل بدء التتبع'));
    }
  }

  Future<void> _onStopTracking(
    StopLocationTracking event,
    Emitter<LocationState> emit,
  ) async {
    try {
      AppLogger.info('[LocationBloc] إيقاف التتبع');
      
      await _locationSubscription?.cancel();
      await _locationService.stopTracking();
      
      if (state is LocationLoaded) {
        final currentState = state as LocationLoaded;
        emit(currentState.copyWith(isTracking: false));
      }
    } catch (e) {
      AppLogger.error('[LocationBloc] خطأ في إيقاف التتبع', e);
    }
  }

  Future<void> _onGetCurrentLocation(
    GetCurrentLocation event,
    Emitter<LocationState> emit,
  ) async {
    try {
      emit(LocationLoading());
      
      final location = await _locationService.getCurrentLocation();
      
      if (location != null) {
        emit(LocationLoaded(location: location));
      } else {
        emit(LocationError('فشل الحصول على الموقع'));
      }
    } catch (e) {
      emit(LocationError('فشل الحصول على الموقع'));
    }
  }

  void _onLocationUpdated(
    LocationUpdated event,
    Emitter<LocationState> emit,
  ) {
    if (state is LocationLoaded) {
      final currentState = state as LocationLoaded;
      emit(currentState.copyWith(location: event.location));
    } else {
      emit(LocationLoaded(location: event.location, isTracking: true));
    }
  }

  @override
  Future<void> close() {
    _locationSubscription?.cancel();
    return super.close();
  }
}
