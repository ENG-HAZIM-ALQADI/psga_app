import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:psga_app/core/utils/logger.dart';
import 'package:psga_app/core/utils/distance_calculator.dart';
import 'package:psga_app/features/routes/domain/entities/location.dart';

/// وضع التتبع
enum LocationTrackingMode {
  foreground, // التتبع في المقدمة
  background, // التتبع في الخلفية
  oneTime, // حصول على الموقع مرة واحدة
}

/// خدمة تحديد الموقع الموحدة
/// 
/// تدعم التتبع في المقدمة والخلفية، والحصول على الموقع مرة واحدة
class LocationService {
  static final LocationService _instance = LocationService._();
  factory LocationService() => _instance;
  LocationService._();

  static LocationService get instance => _instance;

  // Stream Controllers
  StreamController<Location>? _locationController;
  StreamSubscription<Position>? _positionSubscription;
  
  // الحالة
  bool _isTracking = false;
  LocationTrackingMode? _currentMode;
  Location? _lastLocation;

  /// Stream للاستماع للموقع
  Stream<Location> get locationStream {
    _locationController ??= StreamController<Location>.broadcast();
    return _locationController!.stream;
  }

  /// هل التتبع نشط؟
  bool get isTracking => _isTracking;

  /// وضع التتبع الحالي
  LocationTrackingMode? get currentMode => _currentMode;

  /// آخر موقع تم تسجيله
  Location? get lastLocation => _lastLocation;

  /// التحقق من الأذونات وطلبها إذا لزم
  Future<bool> checkPermissions() async {
    try {
      AppLogger.info('[Location] التحقق من الأذونات');

      // التحقق من تفعيل خدمة الموقع
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        AppLogger.warning('[Location] خدمة الموقع معطلة');
        return false;
      }

      // التحقق من الأذونات
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          AppLogger.warning('[Location] تم رفض الأذونات');
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        AppLogger.error(
          '[Location] الأذونات مرفوضة نهائياً',
          'Permission Denied Forever',
        );
        return false;
      }

      AppLogger.success('[Location] الأذونات ممنوحة');
      return true;
    } catch (e, stackTrace) {
      AppLogger.error('[Location] خطأ في التحقق من الأذونات', e, stackTrace);
      return false;
    }
  }

  /// الحصول على الموقع الحالي مرة واحدة
  Future<Location?> getCurrentLocation() async {
    try {
      final hasPermission = await checkPermissions();
      if (!hasPermission) {
        return null;
      }

      AppLogger.info('[Location] جلب الموقع الحالي');

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final location = _positionToLocation(position);

      _lastLocation = location;
      AppLogger.success(
        '[Location] تم جلب الموقع: ${location.latitude}, ${location.longitude}',
      );
      return location;
    } catch (e, stackTrace) {
      AppLogger.error('[Location] خطأ في جلب الموقع', e, stackTrace);
      return null;
    }
  }

  /// بدء تتبع الموقع
  /// 
  /// [mode] وضع التتبع (foreground أو background)
  /// [intervalSeconds] فترة التحديث بالثواني
  /// [distanceFilter] الحد الأدنى للمسافة للتحديث (بالمتر)
  /// [accuracy] دقة الموقع
  Future<bool> startTracking({
    LocationTrackingMode mode = LocationTrackingMode.foreground,
    int intervalSeconds = 5,
    int distanceFilter = 10,
    LocationAccuracy accuracy = LocationAccuracy.high,
  }) async {
    if (_isTracking) {
      AppLogger.warning('[Location] التتبع نشط بالفعل');
      return true;
    }

    try {
      final hasPermission = await checkPermissions();
      if (!hasPermission) {
        return false;
      }

      AppLogger.info('[Location] بدء التتبع - الوضع: ${mode.name}');

      _currentMode = mode;
      
      // إنشاء controller إذا لم يكن موجود
      _locationController ??= StreamController<Location>.broadcast();

      // إعدادات الموقع بناءً على الوضع
      LocationSettings locationSettings;
      
      if (mode == LocationTrackingMode.background) {
        // إعدادات التتبع في الخلفية
        locationSettings = AndroidSettings(
          accuracy: accuracy,
          distanceFilter: distanceFilter,
          forceLocationManager: false,
          intervalDuration: Duration(seconds: intervalSeconds),
          foregroundNotificationConfig: const ForegroundNotificationConfig(
            notificationText: 'تتبع موقعك أثناء الرحلة',
            notificationTitle: 'PSGA - رحلة نشطة',
            enableWakeLock: true,
            notificationIcon: AndroidResource(name: 'ic_notification'),
          ),
        );
      } else {
        // إعدادات التتبع في المقدمة
        locationSettings = LocationSettings(
          accuracy: accuracy,
          distanceFilter: distanceFilter,
          timeLimit: Duration(seconds: intervalSeconds),
        );
      }

      // بدء الاستماع
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        _onPositionUpdate,
        onError: _onError,
        cancelOnError: false,
      );

      _isTracking = true;
      AppLogger.success('[Location] بدأ التتبع بنجاح');

      return true;
    } catch (e, stackTrace) {
      AppLogger.error('[Location] فشل بدء التتبع', e, stackTrace);
      return false;
    }
  }

  /// إيقاف تتبع الموقع
  Future<void> stopTracking() async {
    if (!_isTracking) {
      return;
    }

    try {
      AppLogger.info('[Location] إيقاف التتبع');

      await _positionSubscription?.cancel();
      _positionSubscription = null;
      _isTracking = false;
      _currentMode = null;

      AppLogger.success('[Location] تم إيقاف التتبع');
    } catch (e, stackTrace) {
      AppLogger.error('[Location] خطأ في إيقاف التتبع', e, stackTrace);
    }
  }

  /// معالج تحديث الموقع
  void _onPositionUpdate(Position position) {
    try {
      final location = _positionToLocation(position);

      _lastLocation = location;
      _locationController?.add(location);

      AppLogger.debug(
        '[Location] موقع جديد: ${location.latitude}, ${location.longitude} (دقة: ${location.accuracy}م)',
      );
    } catch (e, stackTrace) {
      AppLogger.error('[Location] خطأ في معالجة الموقع', e, stackTrace);
    }
  }

  /// معالج الأخطاء
  void _onError(dynamic error) {
    AppLogger.error('[Location] خطأ في Stream', error);
    _locationController?.addError(error);
  }

  /// تحويل Position إلى Location
  Location _positionToLocation(Position position) {
    return Location(
      latitude: position.latitude,
      longitude: position.longitude,
      timestamp: position.timestamp,
      accuracy: position.accuracy,
      altitude: position.altitude,
      speed: position.speed,
    );
  }

  /// إغلاق الخدمة
  Future<void> dispose() async {
    await stopTracking();
    await _locationController?.close();
    _locationController = null;
  }

  // ==================== وظائف المسافة والسرعة ====================
  // تم نقلها إلى DistanceCalculator utility

  /// حساب المسافة بين نقطتين (بالمتر)
  double calculateDistance(Location from, Location to) {
    return DistanceCalculator.calculateDistance(from, to);
  }

  /// حساب الاتجاه بين نقطتين (بالدرجات)
  double calculateBearing(Location from, Location to) {
    return DistanceCalculator.calculateBearing(from, to);
  }

  /// التحقق من دقة الموقع
  bool isLocationAccurate(Location location, {double maxAccuracy = 50.0}) {
    if (location.accuracy == null) return false;
    return location.accuracy! <= maxAccuracy;
  }

  /// حساب السرعة بين موقعين (بالمتر/ثانية)
  double calculateSpeed(Location from, Location to) {
    return DistanceCalculator.calculateSpeed(from, to);
  }

  /// تحويل السرعة من م/ث إلى كم/س
  double convertSpeedToKmh(double speedMs) {
    return DistanceCalculator.convertSpeedToKmh(speedMs);
  }

  /// التحقق من أن المستخدم يتحرك
  bool isMoving(Location from, Location to, {double minSpeedKmh = 5.0}) {
    final speedMs = calculateSpeed(from, to);
    final speedKmh = convertSpeedToKmh(speedMs);
    return speedKmh >= minSpeedKmh;
  }

  /// حساب نقطة على المسافة والاتجاه
  Location calculateDestinationPoint(
    Location origin,
    double distanceMeters,
    double bearingDegrees,
  ) {
    return DistanceCalculator.calculateDestinationPoint(
      origin: origin,
      distanceMeters: distanceMeters,
      bearingDegrees: bearingDegrees,
    );
  }

  /// التحقق من وجود موقع داخل دائرة
  bool isLocationInsideCircle({
    required Location location,
    required Location center,
    required double radiusMeters,
  }) {
    return DistanceCalculator.isLocationInsideCircle(
      location: location,
      center: center,
      radiusMeters: radiusMeters,
    );
  }

  /// حساب نقطة المنتصف بين موقعين
  Location calculateMidpoint(Location location1, Location location2) {
    return DistanceCalculator.calculateMidpoint(location1, location2);
  }

  /// حساب الحدود (Bounds) لمجموعة مواقع
  LocationBounds calculateBounds(List<Location> locations) {
    return DistanceCalculator.calculateBounds(locations);
  }

  /// تنسيق الموقع للعرض
  String formatLocation(Location location, {int decimals = 6}) {
    return DistanceCalculator.formatLocation(location, decimals: decimals);
  }
}

