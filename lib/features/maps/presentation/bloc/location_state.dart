import 'package:equatable/equatable.dart';
import 'package:geolocator/geolocator.dart';

/// حالات الموقع
abstract class LocationState extends Equatable {
  const LocationState();

  @override
  List<Object?> get props => [];
}

/// الحالة الأولية
class LocationInitial extends LocationState {
  const LocationInitial();
}

/// جاري التحميل
class LocationLoading extends LocationState {
  const LocationLoading();
}

/// الموقع محمّل
class LocationLoaded extends LocationState {
  final Position position;
  final String? address;

  const LocationLoaded({
    required this.position,
    this.address,
  });

  LocationLoaded copyWith({
    Position? position,
    String? address,
  }) {
    return LocationLoaded(
      position: position ?? this.position,
      address: address ?? this.address,
    );
  }

  @override
  List<Object?> get props => [position, address];
}

/// جاري التتبع
class LocationTracking extends LocationState {
  final Position currentPosition;
  final List<Position> positions;
  final String? currentAddress;

  const LocationTracking({
    required this.currentPosition,
    this.positions = const [],
    this.currentAddress,
  });

  LocationTracking copyWith({
    Position? currentPosition,
    List<Position>? positions,
    String? currentAddress,
  }) {
    return LocationTracking(
      currentPosition: currentPosition ?? this.currentPosition,
      positions: positions ?? this.positions,
      currentAddress: currentAddress ?? this.currentAddress,
    );
  }

  @override
  List<Object?> get props => [currentPosition, positions, currentAddress];
}

/// خطأ في الموقع
class LocationError extends LocationState {
  final String message;

  const LocationError(this.message);

  @override
  List<Object?> get props => [message];
}

/// صلاحية مطلوبة
class PermissionRequired extends LocationState {
  final bool isPermanentlyDenied;

  const PermissionRequired({this.isPermanentlyDenied = false});

  @override
  List<Object?> get props => [isPermanentlyDenied];
}

/// خدمة الموقع معطلة
class LocationServiceDisabledState extends LocationState {
  const LocationServiceDisabledState();
}
