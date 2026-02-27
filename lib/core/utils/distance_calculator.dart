import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';
import 'package:psga_app/features/routes/domain/entities/location.dart';

/// أداة حساب المسافات والمواقع
/// 
/// توفر وظائف موحدة لحساب المسافات والاتجاهات بين المواقع
/// باستخدام Haversine formula ومكتبة Geolocator
class DistanceCalculator {
  DistanceCalculator._();

  // ثوابت
  static const double earthRadiusMeters = 6371000.0; // نصف قطر الأرض بالمتر
  static const double pi = math.pi;

  /// حساب المسافة بين موقعين باستخدام Geolocator (دقة عالية)
  /// 
  /// يستخدم Geolocator.distanceBetween للحصول على أفضل دقة
  /// Returns: المسافة بالمتر
  static double calculateDistance(Location from, Location to) {
    return Geolocator.distanceBetween(
      from.latitude,
      from.longitude,
      to.latitude,
      to.longitude,
    );
  }

  /// حساب المسافة باستخدام Haversine formula (بديل للحالات التي لا تتطلب Geolocator)
  /// 
  /// Returns: المسافة بالمتر
  static double calculateDistanceHaversine(Location from, Location to) {
    final lat1Rad = _toRadians(from.latitude);
    final lat2Rad = _toRadians(to.latitude);
    final dLat = _toRadians(to.latitude - from.latitude);
    final dLon = _toRadians(to.longitude - from.longitude);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1Rad) *
            math.cos(lat2Rad) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadiusMeters * c;
  }

  /// حساب المسافة الإجمالية لمسار من مواقع متعددة
  /// 
  /// Returns: المسافة بالمتر
  static double calculateTotalDistance(List<Location> locations) {
    if (locations.length < 2) return 0.0;

    double total = 0.0;
    for (int i = 1; i < locations.length; i++) {
      total += calculateDistance(locations[i - 1], locations[i]);
    }

    return total;
  }

  /// حساب الاتجاه (Bearing) بين موقعين
  /// 
  /// Returns: الاتجاه بالدرجات (0-360)
  static double calculateBearing(Location from, Location to) {
    return Geolocator.bearingBetween(
      from.latitude,
      from.longitude,
      to.latitude,
      to.longitude,
    );
  }

  /// حساب السرعة بين موقعين
  /// 
  /// Returns: السرعة بالمتر/ثانية
  static double calculateSpeed(Location from, Location to) {
    final distance = calculateDistance(from, to); // بالمتر
    final duration = to.timestamp.difference(from.timestamp).inSeconds;

    if (duration == 0) return 0.0;

    return distance / duration;
  }

  /// حساب متوسط السرعة لمسار
  /// 
  /// Returns: السرعة بالكيلومتر/ساعة
  static double calculateAverageSpeed(List<Location> locations) {
    if (locations.length < 2) return 0.0;

    final distance = calculateTotalDistance(locations); // بالمتر
    final duration =
        locations.last.timestamp.difference(locations.first.timestamp).inSeconds;

    if (duration == 0) return 0.0;

    // تحويل إلى كم/س
    return (distance / duration) * 3.6;
  }

  /// حساب نقطة وجهة بناءً على موقع، مسافة واتجاه
  /// 
  /// [origin] الموقع الأصلي
  /// [distanceMeters] المسافة بالمتر
  /// [bearingDegrees] الاتجاه بالدرجات
  /// 
  /// Returns: الموقع الجديد
  static Location calculateDestinationPoint({
    required Location origin,
    required double distanceMeters,
    required double bearingDegrees,
  }) {
    final lat1Rad = _toRadians(origin.latitude);
    final lon1Rad = _toRadians(origin.longitude);
    final bearingRad = _toRadians(bearingDegrees);

    final angularDistance = distanceMeters / earthRadiusMeters;

    final lat2Rad = math.asin(
      math.sin(lat1Rad) * math.cos(angularDistance) +
          math.cos(lat1Rad) *
              math.sin(angularDistance) *
              math.cos(bearingRad),
    );

    final lon2Rad = lon1Rad +
        math.atan2(
          math.sin(bearingRad) *
              math.sin(angularDistance) *
              math.cos(lat1Rad),
          math.cos(angularDistance) - math.sin(lat1Rad) * math.sin(lat2Rad),
        );

    return Location(
      latitude: _toDegrees(lat2Rad),
      longitude: _toDegrees(lon2Rad),
      timestamp: DateTime.now(),
    );
  }

  /// حساب نقطة المنتصف بين موقعين
  static Location calculateMidpoint(Location location1, Location location2) {
    final lat = (location1.latitude + location2.latitude) / 2;
    final lon = (location1.longitude + location2.longitude) / 2;

    return Location(
      latitude: lat,
      longitude: lon,
      timestamp: DateTime.now(),
    );
  }

  /// حساب أقرب نقطة على خط بين نقطتين
  /// 
  /// [point] النقطة المراد إيجاد أقرب نقطة لها
  /// [lineStart] بداية الخط
  /// [lineEnd] نهاية الخط
  /// 
  /// Returns: أقرب نقطة على الخط
  static Location findClosestPointOnLine({
    required Location point,
    required Location lineStart,
    required Location lineEnd,
  }) {
    final dx = lineEnd.longitude - lineStart.longitude;
    final dy = lineEnd.latitude - lineStart.latitude;

    if (dx == 0 && dy == 0) {
      return lineStart;
    }

    final t = ((point.longitude - lineStart.longitude) * dx +
            (point.latitude - lineStart.latitude) * dy) /
        (dx * dx + dy * dy);

    final clampedT = t.clamp(0.0, 1.0);

    return Location(
      latitude: lineStart.latitude + clampedT * dy,
      longitude: lineStart.longitude + clampedT * dx,
      timestamp: DateTime.now(),
    );
  }

  /// التحقق من وجود موقع داخل دائرة
  /// 
  /// Returns: true إذا كان الموقع داخل الدائرة
  static bool isLocationInsideCircle({
    required Location location,
    required Location center,
    required double radiusMeters,
  }) {
    final distance = calculateDistance(location, center);
    return distance <= radiusMeters;
  }

  /// حساب حدود (Bounds) لمجموعة مواقع
  /// 
  /// Returns: LocationBounds تحتوي على أقصى وأدنى النقاط
  static LocationBounds calculateBounds(List<Location> locations) {
    if (locations.isEmpty) {
      throw ArgumentError('قائمة المواقع فارغة');
    }

    double minLat = locations.first.latitude;
    double maxLat = locations.first.latitude;
    double minLng = locations.first.longitude;
    double maxLng = locations.first.longitude;

    for (final location in locations) {
      if (location.latitude < minLat) minLat = location.latitude;
      if (location.latitude > maxLat) maxLat = location.latitude;
      if (location.longitude < minLng) minLng = location.longitude;
      if (location.longitude > maxLng) maxLng = location.longitude;
    }

    return LocationBounds(
      southwest: Location(
        latitude: minLat,
        longitude: minLng,
        timestamp: DateTime.now(),
      ),
      northeast: Location(
        latitude: maxLat,
        longitude: maxLng,
        timestamp: DateTime.now(),
      ),
    );
  }

  // ==================== تنسيق وتحويلات ====================

  /// تحويل السرعة من م/ث إلى كم/س
  static double convertSpeedToKmh(double speedMs) {
    return speedMs * 3.6;
  }

  /// تحويل السرعة من كم/س إلى م/ث
  static double convertSpeedToMs(double speedKmh) {
    return speedKmh / 3.6;
  }

  /// تنسيق المسافة للعرض
  /// 
  /// Returns: نص منسق (مثل "150 م" أو "2.5 كم")
  static String formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)} م';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)} كم';
    }
  }

  /// تنسيق السرعة للعرض
  /// 
  /// Returns: نص منسق (مثل "60 كم/س")
  static String formatSpeed(double speedKmh) {
    return '${speedKmh.toStringAsFixed(0)} كم/س';
  }

  /// تنسيق الموقع للعرض
  /// 
  /// Returns: نص منسق (مثل "24.123456, 46.123456")
  static String formatLocation(Location location, {int decimals = 6}) {
    return '${location.latitude.toStringAsFixed(decimals)}, ${location.longitude.toStringAsFixed(decimals)}';
  }

  // ==================== وظائف مساعدة خاصة ====================

  /// تحويل درجات إلى راديان
  static double _toRadians(double degrees) {
    return degrees * pi / 180.0;
  }

  /// تحويل راديان إلى درجات
  static double _toDegrees(double radians) {
    return radians * 180.0 / pi;
  }
}

/// حدود موقع (Bounds)
class LocationBounds {
  final Location southwest; // الركن الجنوبي الغربي
  final Location northeast; // الركن الشمالي الشرقي

  LocationBounds({
    required this.southwest,
    required this.northeast,
  });

  /// مركز الحدود
  Location get center {
    final lat = (southwest.latitude + northeast.latitude) / 2;
    final lng = (southwest.longitude + northeast.longitude) / 2;

    return Location(
      latitude: lat,
      longitude: lng,
      timestamp: DateTime.now(),
    );
  }

  /// التحقق من احتواء موقع
  bool contains(Location location) {
    return location.latitude >= southwest.latitude &&
        location.latitude <= northeast.latitude &&
        location.longitude >= southwest.longitude &&
        location.longitude <= northeast.longitude;
  }

  /// حساب عرض الحدود بالمتر
  double get widthMeters {
    return DistanceCalculator.calculateDistance(
      Location(
        latitude: southwest.latitude,
        longitude: southwest.longitude,
        timestamp: DateTime.now(),
      ),
      Location(
        latitude: southwest.latitude,
        longitude: northeast.longitude,
        timestamp: DateTime.now(),
      ),
    );
  }

  /// حساب ارتفاع الحدود بالمتر
  double get heightMeters {
    return DistanceCalculator.calculateDistance(
      Location(
        latitude: southwest.latitude,
        longitude: southwest.longitude,
        timestamp: DateTime.now(),
      ),
      Location(
        latitude: northeast.latitude,
        longitude: southwest.longitude,
        timestamp: DateTime.now(),
      ),
    );
  }

  /// توسيع الحدود بنسبة مئوية
  LocationBounds expand(double percentage) {
    final expandLat = (northeast.latitude - southwest.latitude) * percentage / 200;
    final expandLng = (northeast.longitude - southwest.longitude) * percentage / 200;

    return LocationBounds(
      southwest: Location(
        latitude: southwest.latitude - expandLat,
        longitude: southwest.longitude - expandLng,
        timestamp: DateTime.now(),
      ),
      northeast: Location(
        latitude: northeast.latitude + expandLat,
        longitude: northeast.longitude + expandLng,
        timestamp: DateTime.now(),
      ),
    );
  }
}
