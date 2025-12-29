import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/logger.dart';
import '../entities/trip_entity.dart';
import '../entities/location_entity.dart';
import '../repositories/trip_repository.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// 🏁 EndTripUseCase - حالة الاستخدام: إنهاء الرحلة (Domain Layer)
/// ═══════════════════════════════════════════════════════════════════════════
/// هذه الفئة مسؤولة عن إغلاق الرحلة الجارية وحفظ نتائجها النهائية.
class EndTripUseCase {
  final TripRepository repository;

  EndTripUseCase(this.repository);

  /// 🔹 استدعاء العملية
  /// [tripId]: معرف الرحلة التي سنغلقها
  /// [endLocation]: الموقع النهائي الذي وصل إليه المستخدم
  Future<Either<Failure, TripEntity>> call({
    required String tripId,
    required LocationEntity endLocation,
  }) async {
    AppLogger.info('[Trip] جاري إنهاء الرحلة...');

    // استدعاء المستودع (Repository) للقيام بالعملية الفعلية
    final result = await repository.endTrip(tripId, endLocation);

    // تسجيل النتيجة في السجلات (Logs) للمساعدة في التتبع
    result.fold(
      (failure) => AppLogger.error('[Trip] فشل إنهاء الرحلة: ${failure.message}'),
      (trip) {
        final duration = trip.duration;
        final durationStr = duration != null
            ? '${duration.inHours}:${(duration.inMinutes % 60).toString().padLeft(2, '0')}'
            : 'غير محدد';
        AppLogger.success('[Trip] انتهاء الرحلة - المدة: $durationStr');
        AppLogger.info('[Trip] المسافة الإجمالية: ${trip.totalDistance.toStringAsFixed(2)} كم');
      },
    );

    return result;
  }
}
