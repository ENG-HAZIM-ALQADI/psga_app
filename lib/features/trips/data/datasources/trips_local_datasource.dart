import 'package:psga_app/core/errors/exceptions.dart';
import 'package:psga_app/core/storage/hive_service.dart';
import 'package:psga_app/core/utils/logger.dart';
import 'package:psga_app/features/trips/data/models/trip_model.dart';
import 'package:psga_app/features/trips/domain/entities/trip_entity.dart';

/// مصدر بيانات الرحلات من Hive
abstract class TripsLocalDataSource {
  Future<void> cacheTrip(TripModel trip);
  Future<TripModel?> getCachedActiveTrip(String userId);
  Future<List<TripModel>> getCachedTripHistory(String userId);
  Future<TripModel?> getCachedTripById(String tripId);
  Future<void> deleteTrip(String tripId);
  Future<void> clearCache();
}

/// تنفيذ مصدر بيانات الرحلات من Hive
class TripsLocalDataSourceImpl implements TripsLocalDataSource {
  final HiveService hiveService;
  // استخدام نفس اسم الـ box المفتوح في HiveService
  static const String _boxName = 'trips';

  TripsLocalDataSourceImpl({required this.hiveService});

  @override
  Future<void> cacheTrip(TripModel trip) async {
    try {
      AppLogger.info('[TripsLocal] حفظ رحلة: ${trip.id}');
      // حفظ Model مباشرة في Typed Box
      await hiveService.put<TripModel>(_boxName, trip.id, trip);
      AppLogger.success('[TripsLocal] تم حفظ الرحلة');
    } catch (e, stackTrace) {
      AppLogger.error('[TripsLocal] خطأ في الحفظ', e, stackTrace);
      throw CacheException('فشل حفظ الرحلة');
    }
  }

  @override
  Future<TripModel?> getCachedActiveTrip(String userId) async {
    try {
      AppLogger.info('[TripsLocal] جلب الرحلة النشطة');

      // جلب جميع الرحلات من Typed Box
      final allTrips = hiveService.getAll<TripModel>(_boxName);
      if (allTrips.isEmpty) return null;

      // البحث عن رحلة نشطة للمستخدم
      for (final trip in allTrips) {
        if (trip.userId == userId &&
            (trip.status == TripStatus.active ||
                trip.status == TripStatus.paused)) {
          return trip;
        }
      }

      return null;
    } catch (e, stackTrace) {
      AppLogger.error('[TripsLocal] خطأ في الجلب', e, stackTrace);
      throw CacheException('فشل جلب الرحلة');
    }
  }

  @override
  Future<List<TripModel>> getCachedTripHistory(String userId) async {
    try {
      AppLogger.info('[TripsLocal] جلب سجل الرحلات');

      // جلب جميع الرحلات من Typed Box
      final allTrips = hiveService.getAll<TripModel>(_boxName);
      if (allTrips.isEmpty) return [];

      // فلترة رحلات المستخدم
      final trips = allTrips.where((trip) => trip.userId == userId).toList();

      // ترتيب حسب التاريخ
      trips.sort((a, b) => b.startTime.compareTo(a.startTime));
      return trips;
    } catch (e, stackTrace) {
      AppLogger.error('[TripsLocal] خطأ في جلب السجل', e, stackTrace);
      throw CacheException('فشل جلب السجل');
    }
  }

  @override
  Future<TripModel?> getCachedTripById(String tripId) async {
    try {
      AppLogger.info('[TripsLocal] جلب رحلة: $tripId');
      
      // جلب Model مباشرة من Typed Box
      final trip = hiveService.get<TripModel>(_boxName, tripId);
      return trip;
    } catch (e, stackTrace) {
      AppLogger.error('[TripsLocal] خطأ في الجلب', e, stackTrace);
      throw CacheException('فشل جلب الرحلة');
    }
  }

  @override
  Future<void> deleteTrip(String tripId) async {
    try {
      AppLogger.info('[TripsLocal] حذف رحلة: $tripId');
      await hiveService.delete(_boxName, tripId);
      AppLogger.success('[TripsLocal] تم حذف الرحلة');
    } catch (e, stackTrace) {
      AppLogger.error('[TripsLocal] خطأ في الحذف', e, stackTrace);
      throw CacheException('فشل حذف الرحلة');
    }
  }

  @override
  Future<void> clearCache() async {
    try {
      AppLogger.info('[TripsLocal] مسح الذاكرة المؤقتة');
      final allKeys = hiveService.getKeys(_boxName);
      for (final key in allKeys) {
        await hiveService.delete(_boxName, key);
      }
      AppLogger.success('[TripsLocal] تم المسح');
    } catch (e, stackTrace) {
      AppLogger.error('[TripsLocal] خطأ في المسح', e, stackTrace);
      throw CacheException('فشل مسح الذاكرة');
    }
  }
}
