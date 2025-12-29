import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/logger.dart';
import '../repositories/route_repository.dart';
import '../repositories/trip_repository.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// 🗑️ DeleteRouteUseCase - "مسؤول الحذف الذكي" (Domain Layer)
/// ═══════════════════════════════════════════════════════════════════════════
/// 
/// ❓ لماذا نحتاج "مسؤول حذف" متخصص؟
/// قد تعتقد أن الحذف سهل، ولكن في تطبيق أمان مثل PSGA، الحذف يحتاج حذراً.
/// لا نريد أن يحذف المستخدم طريقاً هو "يمشي عليه الآن" (Active Trip).
///
/// 💡 شرح للمبتدئين:
/// - التعاون بين المستودعات: هذا الكلاس يكلم `TripRepository` ليعرف حالة الرحلات، 
///   ويكلم `RouteRepository` لينفذ الحذف. هذا هو "تنسيق العمل".

class DeleteRouteUseCase {
  final RouteRepository routeRepository;
  final TripRepository tripRepository;

  DeleteRouteUseCase({
    required this.routeRepository,
    required this.tripRepository,
  });

  /// 🔹 تنفيذ الحذف (Call)
  /// [routeId]: معرف المسار المراد حذفه.
  /// [userId]: معرف المستخدم للتأكد من ملكيته للمسار.
  Future<Either<Failure, void>> call(String routeId, String userId) async {
    AppLogger.info('[Routes] جاري فحص إمكانية حذف المسار: $routeId');

    // 1️⃣ الخطوة الأمنية: هل المستخدم في وسط رحلة الآن؟
    final activeTripResult = await tripRepository.getActiveTrip(userId);

    return activeTripResult.fold(
      (failure) => Left(failure), // لو حدث خطأ في النظام، نتوقف.
      
      (activeTrip) async {
        // 2️⃣ التحقق الحرج: هل المسار المطلوب حذفه هو نفسه المستخدم حالياً؟
        if (activeTrip != null && activeTrip.routeId == routeId) {
          AppLogger.warning('[Routes] منع الحذف: المستخدم يحاول حذف مسار هو قيد الاستخدام حالياً!');
          return const Left(ValidationFailure(message: 'عذراً، لا يمكنك حذف هذا المسار لأنك تخوض رحلة نشطة عليه الآن'));
        }

        // 3️⃣ إذا كان الطريق "غير مستخدم حالياً"، ننفذ الحذف بأمان.
        final result = await routeRepository.deleteRoute(routeId);

        result.fold(
          (failure) => AppLogger.error('[Routes] فشل الحذف النهائي: ${failure.message}'),
          (_) => AppLogger.success('[Routes] تم حذف المسار بنجاح من جهازك'),
        );

        return result;
      },
    );
  }
}
