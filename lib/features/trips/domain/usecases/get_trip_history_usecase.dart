import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/logger.dart';
import '../entities/trip_entity.dart';
import '../repositories/trip_repository.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// 📜 GetTripHistoryUseCase - "أمين سجل الرحلات" (Domain Layer)
/// ═══════════════════════════════════════════════════════════════════════════
/// 
/// ❓ ما هي وظيفة هذا الملف؟
/// مهمته جلب قائمة الرحلات السابقة للمستخدم وترتيبها بطريقة تجعل القراءة سهلة 
/// (من الأحدث إلى الأقدم).
///
/// 💡 شرح للمبتدئين:
/// - List.from(trips)..sort: نحن نأخذ نسخة من القائمة ونرتبها. الترتيب يكون 
///   حسب الـ `startTime` لنعرض آخر رحلة قام بها المستخدم في أعلى القائمة.

class GetTripHistoryUseCase {
  final TripRepository repository;

  GetTripHistoryUseCase(this.repository);

  /// 🔹 جلب السجل (Call)
  /// [userId]: من هو المستخدم الذي نريد جلب رحلاته؟
  /// [limit]: هل تريد آخر 10 رحلات؟ أم كل الرحلات؟
  /// [from] و [to]: فلترة الرحلات بين تاريخين معينين.
  Future<Either<Failure, List<TripEntity>>> call({
    required String userId,
    int? limit,
    DateTime? from,
    DateTime? to,
  }) async {
    AppLogger.info('[Trip] طلب جلب سجل الرحلات السابقة للمستخدم: $userId');

    // 1️⃣ نطلب البيانات الخام من المستودع (Repository).
    final result = await repository.getTripHistory(
      userId,
      limit: limit,
      from: from,
      to: to,
    );

    // 2️⃣ نقوم بترتيب البيانات قبل إرسالها للواجهة (Sorting).
    return result.map((trips) {
      // ننشئ نسخة جديدة ونرتبها (من الأحدث للأقدم).
      final sortedTrips = List<TripEntity>.from(trips)
        ..sort((a, b) => b.startTime.compareTo(a.startTime));

      AppLogger.info('[Trip] نجح تحميل ${sortedTrips.length} رحلة وتم ترتيبها زمنياً');
      return sortedTrips;
    });
  }
}
