import 'package:equatable/equatable.dart';
import 'package:geolocator/geolocator.dart';

/// أحداث الموقع
abstract class LocationEvent extends Equatable {
  const LocationEvent();

  @override
  List<Object?> get props => [];
}

/// طلب صلاحية الموقع
class RequestLocationPermission extends LocationEvent {
  const RequestLocationPermission();
}

/// الحصول على الموقع الحالي
class GetCurrentLocation extends LocationEvent {
  const GetCurrentLocation();
}

/// بدء التتبع
class StartTracking extends LocationEvent {
  const StartTracking();
}

/// إيقاف التتبع
class StopTracking extends LocationEvent {
  const StopTracking();
}

/// تحديث الموقع
class LocationUpdated extends LocationEvent {
  final Position position;

  const LocationUpdated(this.position);

  @override
  List<Object?> get props => [position];
}

/// فتح إعدادات الموقع
class OpenLocationSettings extends LocationEvent {
  const OpenLocationSettings();
}

/// فتح إعدادات التطبيق
class OpenAppSettings extends LocationEvent {
  const OpenAppSettings();
}
