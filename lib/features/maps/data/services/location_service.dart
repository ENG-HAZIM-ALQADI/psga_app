import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:psga_app/core/utils/logger.dart';

/// خدمة الموقع الجغرافي - تدير جميع عمليات الموقع والتتبع
/// 
/// توفر هذه الخدمة:
/// - طلب وفحص صلاحيات الموقع
/// - الحصول على الموقع الحالي بدقة عالية
/// - تتبع الموقع المستمر مع التحديثات الفورية
/// - التعامل مع أخطاء خدمة الموقع
/// 
/// تستخدم Singleton pattern لضمان وجود نسخة واحدة فقط
class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  Position? _currentPosition;
  bool _isTracking = false;
  StreamSubscription<Position>? _positionSubscription;
  final StreamController<Position> _positionStreamController =
      StreamController<Position>.broadcast();

  final LocationSettings _locationSettings = const LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 10,
  );

  Position? get currentPosition => _currentPosition;
  bool get isTracking => _isTracking;
  Stream<Position> get positionStream => _positionStreamController.stream;

  /// التحقق من صلاحيات الموقع وطلبها إذا لزم الأمر
  Future<bool> checkPermissions() async {
    AppLogger.info('[Location] التحقق من الصلاحيات...');

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      AppLogger.error('[Location] خدمة الموقع معطلة');
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        AppLogger.error('[Location] الصلاحيات مرفوضة');
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      AppLogger.error('[Location] الصلاحيات مرفوضة بشكل دائم');
      return false;
    }

    AppLogger.success('[Location] الصلاحيات ممنوحة');
    return true;
  }

  /// الحصول على الموقع الحالي بدقة عالية
  Future<Position?> getCurrentPosition() async {
    try {
      final hasPermission = await checkPermissions();
      if (!hasPermission) return null;

      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      AppLogger.info(
          '[Location] الموقع الحالي: ${_currentPosition!.latitude}, ${_currentPosition!.longitude}');
      return _currentPosition;
    } catch (e) {
      AppLogger.error('[Location] خطأ في الحصول على الموقع: $e');
      return null;
    }
  }

  /// بدء تتبع الموقع المستمر
  Future<void> startTracking() async {
    if (_isTracking) {
      AppLogger.info('[Location] التتبع يعمل بالفعل');
      return;
    }

    final hasPermission = await checkPermissions();
    if (!hasPermission) return;

    AppLogger.info('[Tracking] بدء تتبع الموقع');
    _isTracking = true;

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: _locationSettings,
    ).listen(
      (Position position) {
        _currentPosition = position;
        _positionStreamController.add(position);
        AppLogger.info(
            '[Location] تحديث الموقع: ${position.latitude}, ${position.longitude}');
      },
      onError: (error) {
        AppLogger.error('[Location] خطأ في تتبع الموقع: $error');
      },
    );
  }

  /// إيقاف تتبع الموقع
  Future<void> stopTracking() async {
    AppLogger.info('[Tracking] إيقاف تتبع الموقع');
    _isTracking = false;
    await _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  /// حساب المسافة بين نقطتين بالأمتار
  double getDistanceBetween(Position p1, Position p2) {
    return Geolocator.distanceBetween(
      p1.latitude,
      p1.longitude,
      p2.latitude,
      p2.longitude,
    );
  }

  /// حساب المسافة بين إحداثيات
  double getDistanceBetweenCoords(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    return Geolocator.distanceBetween(lat1, lng1, lat2, lng2);
  }

  /// التحقق من تفعيل خدمة الموقع
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// فتح إعدادات الموقع في الجهاز
  Future<bool> openLocationSettings() async {
    return await Geolocator.openLocationSettings();
  }

  /// فتح إعدادات التطبيق
  Future<bool> openAppSettings() async {
    return await Geolocator.openAppSettings();
  }

  /// تنظيف الموارد
  void dispose() {
    _positionSubscription?.cancel();
    _positionStreamController.close();
  }
}
