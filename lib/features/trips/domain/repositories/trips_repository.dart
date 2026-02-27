import 'package:dartz/dartz.dart';
import 'package:psga_app/core/errors/failures.dart';
import 'package:psga_app/features/routes/domain/entities/location.dart';
import 'package:psga_app/features/trips/domain/entities/deviation.dart';
import 'package:psga_app/features/trips/domain/entities/trip_entity.dart';
import 'package:psga_app/features/trips/domain/entities/trip_settings_entity.dart';

/// عقد مستودع الرحلات
abstract class TripsRepository {
  /// بدء رحلة جديدة
  Future<Either<Failure, TripEntity>> startTrip({
    required String userId,
    required String routeId,
    dynamic modifiedRoute, // المسار المعدل (اختياري) - يستخدم عند البدء من موقع مختلف
  });

  /// إنهاء رحلة
  Future<Either<Failure, TripEntity>> endTrip(String tripId);

  /// إيقاف رحلة مؤقتاً
  Future<Either<Failure, TripEntity>> pauseTrip(String tripId);

  /// استئناف رحلة
  Future<Either<Failure, TripEntity>> resumeTrip(String tripId);

  /// إلغاء رحلة
  Future<Either<Failure, TripEntity>> cancelTrip(String tripId);

  /// تحديث موقع الرحلة
  Future<Either<Failure, TripEntity>> updateLocation({
    required String tripId,
    required Location location,
  });

  /// الحصول على الرحلة النشطة للمستخدم
  Future<Either<Failure, TripEntity?>> getActiveTrip(String userId);

  /// الحصول على سجل الرحلات
  Future<Either<Failure, List<TripEntity>>> getTripHistory({
    required String userId,
    int? limit,
    DateTime? startDate,
    DateTime? endDate,
  });

  /// الحصول على تفاصيل رحلة
  Future<Either<Failure, TripEntity>> getTripById(String tripId);

  /// الحصول على انحرافات رحلة
  Future<Either<Failure, List<Deviation>>> getTripDeviations(String tripId);

  /// مزامنة رحلة مع السيرفر
  Future<Either<Failure, void>> syncTrip(String tripId);

  /// حذف رحلة
  Future<Either<Failure, void>> deleteTrip(String tripId);
  Future<Either<Failure, void>> clearAllTrips(String userId);

  /// الحصول على معلومات مسار بواسطة ID
  /// Interface Segregation: دالة منفصلة للحصول على معلومات المسار
  Future<Either<Failure, dynamic>> getRouteById(String routeId);

  /// حفظ إعدادات الرحلات
  Future<Either<Failure, void>> saveTripSettings(TripSettingsEntity settings);

  /// جلب إعدادات الرحلات
  Future<Either<Failure, TripSettingsEntity>> getTripSettings(String userId);
  
  /// حفظ مسار معدل محلياً (عند البدء من موقع مختلف)
  /// Single Responsibility: حفظ المسار المعدل في التخزين المحلي فقط
  Future<Either<Failure, void>> saveModifiedRoute(dynamic route);
  
  /// مزامنة المسار المعدل مع Firebase
  /// Single Responsibility: مزامنة المسار المعدل مع السحابة
  Future<Either<Failure, void>> syncModifiedRouteToFirebase(dynamic route);
}
