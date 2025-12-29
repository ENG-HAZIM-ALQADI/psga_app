import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:psga_app/core/utils/logger.dart';
import 'location_service.dart';

/// خدمة تتبع الموقع في الخلفية
class BackgroundLocationService {
  static final BackgroundLocationService _instance =
      BackgroundLocationService._internal();
  factory BackgroundLocationService() => _instance;
  BackgroundLocationService._internal();

  final LocationService _locationService = LocationService();
  bool _isBackgroundTrackingActive = false;
  StreamSubscription<Position>? _backgroundSubscription;
  final StreamController<Position> _backgroundPositionController =
      StreamController<Position>.broadcast();

  bool get isBackgroundTrackingActive => _isBackgroundTrackingActive;
  Stream<Position> get backgroundPositionStream =>
      _backgroundPositionController.stream;

  /// بدء تتبع الموقع في الخلفية
  Future<bool> startBackgroundTracking() async {
    if (_isBackgroundTrackingActive) {
      AppLogger.info('[BgLocation] التتبع في الخلفية يعمل بالفعل');
      return true;
    }

    AppLogger.info('[BgLocation] بدء التتبع في الخلفية');

    final hasPermission = await _locationService.checkPermissions();
    if (!hasPermission) {
      AppLogger.error('[BgLocation] الصلاحيات غير متوفرة');
      return false;
    }

    try {
      _isBackgroundTrackingActive = true;

      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      );

      _backgroundSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        (Position position) {
          _backgroundPositionController.add(position);
          AppLogger.info(
              '[BgLocation] تحديث الموقع: ${position.latitude}, ${position.longitude}');
        },
        onError: (error) {
          AppLogger.error('[BgLocation] خطأ في التتبع: $error');
        },
      );

      AppLogger.success('[BgLocation] تم بدء التتبع في الخلفية بنجاح');
      return true;
    } catch (e) {
      AppLogger.error('[BgLocation] خطأ في بدء التتبع: $e');
      _isBackgroundTrackingActive = false;
      return false;
    }
  }

  /// إيقاف تتبع الموقع في الخلفية
  Future<void> stopBackgroundTracking() async {
    AppLogger.info('[BgLocation] إيقاف التتبع في الخلفية');

    _isBackgroundTrackingActive = false;
    await _backgroundSubscription?.cancel();
    _backgroundSubscription = null;

    AppLogger.success('[BgLocation] تم إيقاف التتبع في الخلفية');
  }

  /// الحصول على آخر موقع معروف
  Future<Position?> getLastKnownPosition() async {
    try {
      return await Geolocator.getLastKnownPosition();
    } catch (e) {
      AppLogger.error('[BgLocation] خطأ في الحصول على آخر موقع: $e');
      return null;
    }
  }

  /// تنظيف الموارد
  void dispose() {
    _backgroundSubscription?.cancel();
    _backgroundPositionController.close();
  }
}
