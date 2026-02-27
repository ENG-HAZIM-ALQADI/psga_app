import 'package:psga_app/core/errors/exceptions.dart';
import 'package:psga_app/core/storage/hive_service.dart';
import 'package:psga_app/core/utils/logger.dart';
import 'package:psga_app/features/maps/data/models/direction_model.dart';
import 'package:psga_app/features/maps/data/models/place_model.dart';
import 'package:psga_app/features/routes/domain/entities/location.dart';

/// مصدر البيانات المحلي للخرائط (Hive)
/// 
/// مسؤول عن التخزين المحلي للاتجاهات والأماكن
/// يدعم Offline Mode والتخزين المؤقت (Caching)
abstract class MapsLocalDataSource {
  /// حفظ اتجاهات في الذاكرة المحلية
  Future<void> cacheDirection(DirectionModel direction);

  /// الحصول على اتجاهات محفوظة
  Future<DirectionModel?> getCachedDirection(
    Location origin,
    Location destination,
  );

  /// حفظ أماكن في الذاكرة المحلية
  Future<void> cachePlaces(List<PlaceModel> places, String cacheKey);

  /// الحصول على أماكن محفوظة
  Future<List<PlaceModel>?> getCachedPlaces(String cacheKey);

  /// حفظ مكان محدد
  Future<void> savePlace(PlaceModel place);

  /// الحصول على مكان بواسطة place_id
  Future<PlaceModel?> getPlace(String placeId);

  /// حذف التخزين المؤقت القديم
  Future<void> clearOldCache({int maxAgeDays = 7});

  /// مسح جميع البيانات المحفوظة
  Future<void> clearAllCache();
}

/// تنفيذ مصدر البيانات المحلي
class MapsLocalDataSourceImpl implements MapsLocalDataSource {
  final HiveService hiveService;

  // أسماء الصناديق
  static const String _directionsBoxName = 'cached_directions';
  static const String _placesBoxName = 'cached_places';
  static const String _savedPlacesBoxName = 'saved_places';

  MapsLocalDataSourceImpl({required this.hiveService});

  @override
  Future<void> cacheDirection(DirectionModel direction) async {
    try {
      AppLogger.info('[MapsLocalDataSource] حفظ اتجاهات محلياً');

      final box = await hiveService.openBox(_directionsBoxName);
      
      // استخدام key يعتمد على origin & destination
      final key = _generateDirectionKey(
        direction.origin,
        direction.destination,
      );

      final data = {
        'direction': direction.toJson(),
        'cachedAt': DateTime.now().toIso8601String(),
      };

      await box.put(key, data);
      
      AppLogger.success('[MapsLocalDataSource] تم حفظ الاتجاهات');
    } catch (e, stackTrace) {
      AppLogger.error('[MapsLocalDataSource] فشل حفظ الاتجاهات', e, stackTrace);
      throw CacheException('فشل حفظ الاتجاهات محلياً');
    }
  }

  @override
  Future<DirectionModel?> getCachedDirection(
    Location origin,
    Location destination,
  ) async {
    try {
      AppLogger.info('[MapsLocalDataSource] البحث عن اتجاهات محفوظة');

      final box = await hiveService.openBox(_directionsBoxName);
      final key = _generateDirectionKey(origin, destination);

      final data = box.get(key);
      
      if (data == null) {
        AppLogger.info('[MapsLocalDataSource] لا توجد اتجاهات محفوظة');
        return null;
      }

      // التحقق من عمر التخزين المؤقت
      final cachedAt = DateTime.parse(data['cachedAt'] as String);
      final age = DateTime.now().difference(cachedAt);

      if (age.inHours > 24) {
        AppLogger.warning('[MapsLocalDataSource] الاتجاهات المحفوظة قديمة');
        await box.delete(key);
        return null;
      }

      AppLogger.success('[MapsLocalDataSource] تم العثور على اتجاهات محفوظة');
      return DirectionModel.fromJson(data['direction'] as Map<String, dynamic>);
    } catch (e, stackTrace) {
      AppLogger.error('[MapsLocalDataSource] خطأ في قراءة الاتجاهات', e, stackTrace);
      return null;
    }
  }

  @override
  Future<void> cachePlaces(List<PlaceModel> places, String cacheKey) async {
    try {
      AppLogger.info('[MapsLocalDataSource] حفظ ${places.length} مكان محلياً');

      final box = await hiveService.openBox(_placesBoxName);

      final data = {
        'places': places.map((p) => p.toJson()).toList(),
        'cachedAt': DateTime.now().toIso8601String(),
      };

      await box.put(cacheKey, data);
      
      AppLogger.success('[MapsLocalDataSource] تم حفظ الأماكن');
    } catch (e, stackTrace) {
      AppLogger.error('[MapsLocalDataSource] فشل حفظ الأماكن', e, stackTrace);
      throw CacheException('فشل حفظ الأماكن محلياً');
    }
  }

  @override
  Future<List<PlaceModel>?> getCachedPlaces(String cacheKey) async {
    try {
      AppLogger.info('[MapsLocalDataSource] البحث عن أماكن محفوظة');

      final box = await hiveService.openBox(_placesBoxName);
      final data = box.get(cacheKey);
      
      if (data == null) {
        AppLogger.info('[MapsLocalDataSource] لا توجد أماكن محفوظة');
        return null;
      }

      // التحقق من عمر التخزين المؤقت
      final cachedAt = DateTime.parse(data['cachedAt'] as String);
      final age = DateTime.now().difference(cachedAt);

      if (age.inHours > 24) {
        AppLogger.warning('[MapsLocalDataSource] الأماكن المحفوظة قديمة');
        await box.delete(cacheKey);
        return null;
      }

      final placesList = data['places'] as List<dynamic>;
      final places = placesList
          .map((p) => PlaceModel.fromJson(p as Map<String, dynamic>))
          .toList();

      AppLogger.success('[MapsLocalDataSource] تم العثور على ${places.length} مكان');
      return places;
    } catch (e, stackTrace) {
      AppLogger.error('[MapsLocalDataSource] خطأ في قراءة الأماكن', e, stackTrace);
      return null;
    }
  }

  @override
  Future<void> savePlace(PlaceModel place) async {
    try {
      AppLogger.info('[MapsLocalDataSource] حفظ مكان: ${place.name}');

      final box = await hiveService.openBox(_savedPlacesBoxName);
      
      final data = {
        'place': place.toJson(),
        'savedAt': DateTime.now().toIso8601String(),
      };

      await box.put(place.id, data);
      
      AppLogger.success('[MapsLocalDataSource] تم حفظ المكان');
    } catch (e, stackTrace) {
      AppLogger.error('[MapsLocalDataSource] فشل حفظ المكان', e, stackTrace);
      throw CacheException('فشل حفظ المكان');
    }
  }

  @override
  Future<PlaceModel?> getPlace(String placeId) async {
    try {
      AppLogger.info('[MapsLocalDataSource] البحث عن مكان: $placeId');

      final box = await hiveService.openBox(_savedPlacesBoxName);
      final data = box.get(placeId);
      
      if (data == null) {
        AppLogger.info('[MapsLocalDataSource] المكان غير موجود');
        return null;
      }

      AppLogger.success('[MapsLocalDataSource] تم العثور على المكان');
      return PlaceModel.fromJson(data['place'] as Map<String, dynamic>);
    } catch (e, stackTrace) {
      AppLogger.error('[MapsLocalDataSource] خطأ في قراءة المكان', e, stackTrace);
      return null;
    }
  }

  @override
  Future<void> clearOldCache({int maxAgeDays = 7}) async {
    try {
      AppLogger.info('[MapsLocalDataSource] حذف التخزين المؤقت القديم');

      final now = DateTime.now();
      int deletedCount = 0;

      // حذف الاتجاهات القديمة
      final directionsBox = await hiveService.openBox(_directionsBoxName);
      final directionsKeys = directionsBox.keys.toList();
      
      for (final key in directionsKeys) {
        final data = directionsBox.get(key);
        if (data != null) {
          final cachedAt = DateTime.parse(data['cachedAt'] as String);
          if (now.difference(cachedAt).inDays > maxAgeDays) {
            await directionsBox.delete(key);
            deletedCount++;
          }
        }
      }

      // حذف الأماكن القديمة
      final placesBox = await hiveService.openBox(_placesBoxName);
      final placesKeys = placesBox.keys.toList();
      
      for (final key in placesKeys) {
        final data = placesBox.get(key);
        if (data != null) {
          final cachedAt = DateTime.parse(data['cachedAt'] as String);
          if (now.difference(cachedAt).inDays > maxAgeDays) {
            await placesBox.delete(key);
            deletedCount++;
          }
        }
      }

      AppLogger.success('[MapsLocalDataSource] تم حذف $deletedCount عنصر قديم');
    } catch (e, stackTrace) {
      AppLogger.error('[MapsLocalDataSource] فشل حذف التخزين القديم', e, stackTrace);
    }
  }

  @override
  Future<void> clearAllCache() async {
    try {
      AppLogger.info('[MapsLocalDataSource] حذف جميع البيانات المحفوظة');

      await hiveService.deleteBox(_directionsBoxName);
      await hiveService.deleteBox(_placesBoxName);
      await hiveService.deleteBox(_savedPlacesBoxName);

      AppLogger.success('[MapsLocalDataSource] تم حذف جميع البيانات');
    } catch (e, stackTrace) {
      AppLogger.error('[MapsLocalDataSource] فشل حذف البيانات', e, stackTrace);
      throw CacheException('فشل حذف البيانات المحفوظة');
    }
  }

  /// توليد key للاتجاهات
  String _generateDirectionKey(Location origin, Location destination) {
    final originKey = '${origin.latitude.toStringAsFixed(4)},${origin.longitude.toStringAsFixed(4)}';
    final destKey = '${destination.latitude.toStringAsFixed(4)},${destination.longitude.toStringAsFixed(4)}';
    return 'dir_${originKey}_to_$destKey';
  }
}

/// Extension لتحويل DirectionModel إلى JSON
extension DirectionModelJson on DirectionModel {
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'origin': {
        'lat': origin.latitude,
        'lon': origin.longitude,
      },
      'destination': {
        'lat': destination.latitude,
        'lon': destination.longitude,
      },
      'totalDistance': totalDistance,
      'totalDuration': totalDuration,
      'totalDistanceValue': totalDistanceValue,
      'totalDurationValue': totalDurationValue,
      'polyline': polyline,
      // يمكن إضافة المزيد من الحقول حسب الحاجة
    };
  }
}
