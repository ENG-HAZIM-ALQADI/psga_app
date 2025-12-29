import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/logger.dart';
import '../entities/trip_entity.dart';
import '../entities/location_entity.dart';
import '../entities/deviation_entity.dart';
import '../repositories/trip_repository.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// 📍 UpdateTripLocationUseCase - تحديث الموقع واكتشاف الخطر (Domain Layer)
/// ═══════════════════════════════════════════════════════════════════════════
/// 
/// ❓ ما هو الـ Use Case؟
/// هو "موظف" متخصص في مهمة واحدة فقط. هذا الموظف مهمته: 
/// "تحديث موقع المستخدم والتأكد أنه ما زال على الطريق الصحيح".
///
/// 💡 لماذا نفصل المنطق هنا؟
/// لكي لا نكرر الكود. إذا أردنا تغيير "قانون الانحراف" (مثلاً جعل المسافة 
/// المسموحة 200 متر بدل 100)، سنغيرها هنا فقط وسيتأثر التطبيق بالكامل.
///
/// 📚 شرح للمبتدئين:
/// - static const deviationThreshold: هذا هو "الخط الأحمر". إذا ابتعد المستخدم 
///   أكثر من 100 متر عن الطريق، التطبيق سيعتبره في خطر.
class UpdateTripLocationUseCase {
  final TripRepository repository;
  
  // 📏 المسافة المسموحة (بالأمتار). يمكنك زيادتها إذا كان الـ GPS غير دقيق.
  static const double deviationThreshold = 100.0; 

  UpdateTripLocationUseCase(this.repository);

  /// 🔹 تنفيذ المهمة (Call)
  /// [tripId]: رقم الرحلة التي نحدثها.
  /// [newLocation]: المكان الجديد الذي رصده الهاتف الآن.
  /// [expectedLocation]: المكان الذي كان "يُفترض" أن يكون فيه المستخدم (حسب الخريطة).
  Future<Either<Failure, TripEntity>> call({
    required String tripId,
    required LocationEntity newLocation,
    LocationEntity? expectedLocation,
  }) async {
    // 1️⃣ إخبار السجلات (Logs) أننا استلمنا موقعاً جديداً.
    AppLogger.info('[Trip] تحديث موقع GPS جديد...');

    // 2️⃣ نطلب من المستودع (Repository) حفظ الموقع الجديد في الذاكرة.
    final result = await repository.updateTripLocation(tripId, newLocation);

    // 3️⃣ تحليل النتيجة
    return result.fold(
      (failure) => Left(failure), // لو فشل الحفظ، نرجع الخطأ للواجهة.
      
      (trip) async {
        // 4️⃣ المنطق الذكي: هل المستخدم تائه أو منحرف عن المسار؟
        if (expectedLocation != null) {
          // نحسب المسافة الحقيقية بين موقع المستخدم وبين الطريق المخطط له.
          final distance = newLocation.distanceTo(expectedLocation);

          // 5️⃣ إذا تجاوز "الخط الأحمر" (100 متر)
          if (distance > deviationThreshold) {
            AppLogger.warning('[Trip] تنبيه! المستخدم خرج عن المسار بمسافة $distance متر');

            // نجهز تقرير عن الانحراف (Deviation Report)
            final deviation = DeviationEntity(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              tripId: tripId,
              location: newLocation,
              expectedLocation: expectedLocation,
              distanceFromRoute: distance,
              detectedAt: DateTime.now(),
              severity: DeviationEntity.getSeverityFromDistance(distance), // تحديد الخطورة (خفيف، متوسط، حرج)
              wasAlertSent: false,
            );

            // نطلب من المستودع حفظ هذا الانحراف ليتمكن نظام التنبيهات من معالجته.
            await repository.addDeviation(tripId, deviation);
          }
        }

        // نرجع بيانات الرحلة كاملة ومحدثة ليتم عرضها على الخريطة.
        return Right(trip);
      },
    );
  }
}
