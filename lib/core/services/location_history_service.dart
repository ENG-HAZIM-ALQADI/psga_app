import 'package:hive/hive.dart';
import 'package:psga_app/core/utils/logger.dart';
import 'package:psga_app/core/utils/distance_calculator.dart';
import 'package:psga_app/features/routes/domain/entities/location.dart';

/// خدمة حفظ تاريخ المواقع
class LocationHistoryService {
  static final LocationHistoryService instance = LocationHistoryService._();
  LocationHistoryService._();

  static const String _boxName = 'location_history';
  Box<Map>? _box;

  /// تهيئة الخدمة
  Future<void> initialize() async {
    try {
      _box = await Hive.openBox<Map>(_boxName);
      AppLogger.success('[LocationHistory] تم تهيئة الخدمة');
    } catch (e, stackTrace) {
      AppLogger.error('[LocationHistory] فشل التهيئة', e, stackTrace);
    }
  }

  /// حفظ موقع
  Future<void> saveLocation({
    required String tripId,
    required Location location,
  }) async {
    try {
      if (_box == null) await initialize();

      final key = '${tripId}_${location.timestamp.millisecondsSinceEpoch}';
      await _box!.put(key, {
        'tripId': tripId,
        'latitude': location.latitude,
        'longitude': location.longitude,
        'timestamp': location.timestamp.toIso8601String(),
        'accuracy': location.accuracy,
        'altitude': location.altitude,
        'speed': location.speed,
      });

      AppLogger.debug('[LocationHistory] تم حفظ موقع للرحلة: $tripId');
    } catch (e, stackTrace) {
      AppLogger.error('[LocationHistory] فشل حفظ الموقع', e, stackTrace);
    }
  }

  /// حفظ قائمة مواقع
  Future<void> saveLocations({
    required String tripId,
    required List<Location> locations,
  }) async {
    try {
      if (_box == null) await initialize();

      for (final location in locations) {
        await saveLocation(tripId: tripId, location: location);
      }

      AppLogger.success('[LocationHistory] تم حفظ ${locations.length} موقع');
    } catch (e, stackTrace) {
      AppLogger.error('[LocationHistory] فشل حفظ المواقع', e, stackTrace);
    }
  }

  /// الحصول على مواقع رحلة
  Future<List<Location>> getLocations(String tripId) async {
    try {
      if (_box == null) await initialize();

      final locations = <Location>[];

      for (final entry in _box!.toMap().entries) {
        final key = entry.key as String;
        if (key.startsWith(tripId)) {
          final data = entry.value;
          locations.add(Location(
            latitude: data['latitude'] as double,
            longitude: data['longitude'] as double,
            timestamp: DateTime.parse(data['timestamp'] as String),
            accuracy: data['accuracy'] as double?,
            altitude: data['altitude'] as double?,
            speed: data['speed'] as double?,
          ));
        }
      }

      // ترتيب حسب الوقت
      locations.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      AppLogger.info('[LocationHistory] تم جلب ${locations.length} موقع للرحلة: $tripId');
      return locations;
    } catch (e, stackTrace) {
      AppLogger.error('[LocationHistory] فشل جلب المواقع', e, stackTrace);
      return [];
    }
  }

  /// الحصول على آخر N موقع
  Future<List<Location>> getLastLocations(String tripId, int count) async {
    final all = await getLocations(tripId);
    if (all.length <= count) return all;
    return all.sublist(all.length - count);
  }

  /// حذف مواقع رحلة
  Future<void> deleteLocations(String tripId) async {
    try {
      if (_box == null) await initialize();

      final keysToDelete = <String>[];
      for (final key in _box!.keys) {
        if ((key as String).startsWith(tripId)) {
          keysToDelete.add(key);
        }
      }

      await _box!.deleteAll(keysToDelete);
      AppLogger.info('[LocationHistory] تم حذف ${keysToDelete.length} موقع');
    } catch (e, stackTrace) {
      AppLogger.error('[LocationHistory] فشل حذف المواقع', e, stackTrace);
    }
  }

  /// حساب المسافة الإجمالية
  double calculateTotalDistance(List<Location> locations) {
    final distanceMeters = DistanceCalculator.calculateTotalDistance(locations);
    return distanceMeters / 1000; // بالكيلومترات
  }

  /// حساب متوسط السرعة
  double calculateAverageSpeed(List<Location> locations) {
    return DistanceCalculator.calculateAverageSpeed(locations);
  }

  /// تنظيف المواقع القديمة (أقدم من عدد أيام معين)
  Future<void> cleanOldLocations({int daysOld = 30}) async {
    try {
      if (_box == null) await initialize();

      final cutoffDate = DateTime.now().subtract(Duration(days: daysOld));
      final keysToDelete = <String>[];

      for (final entry in _box!.toMap().entries) {
        final data = entry.value;
        final timestamp = DateTime.parse(data['timestamp'] as String);
        
        if (timestamp.isBefore(cutoffDate)) {
          keysToDelete.add(entry.key as String);
        }
      }

      if (keysToDelete.isNotEmpty) {
        await _box!.deleteAll(keysToDelete);
        AppLogger.info('[LocationHistory] تم حذف ${keysToDelete.length} موقع قديم');
      }
    } catch (e, stackTrace) {
      AppLogger.error('[LocationHistory] فشل تنظيف المواقع', e, stackTrace);
    }
  }

  /// الحصول على عدد المواقع المحفوظة
  Future<int> getLocationCount(String tripId) async {
    final locations = await getLocations(tripId);
    return locations.length;
  }

  /// التنظيف
  Future<void> dispose() async {
    await _box?.close();
    _box = null;
  }
}
