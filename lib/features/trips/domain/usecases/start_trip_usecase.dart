import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:psga_app/core/errors/failures.dart';
import 'package:psga_app/core/usecases/usecase.dart';
import 'package:psga_app/features/trips/domain/entities/trip_entity.dart';
import 'package:psga_app/features/trips/domain/repositories/trips_repository.dart';

/// حالة استخدام: بدء رحلة جديدة
class StartTripUseCase implements UseCase<TripEntity, StartTripParams> {
  final TripsRepository repository;

  StartTripUseCase(this.repository);

  @override
  Future<Either<Failure, TripEntity>> call(StartTripParams params) async {
    // التحقق من الإدخال
    if (params.userId.isEmpty) {
      return const Left(ValidationFailure('معرف المستخدم مطلوب'));
    }

    if (params.routeId.isEmpty) {
      return const Left(ValidationFailure('معرف المسار مطلوب'));
    }

    // التحقق من عدم وجود رحلة نشطة
    final activeTrip = await repository.getActiveTrip(params.userId);

    return activeTrip.fold(
      (failure) => Left(failure),
      (trip) async {
        if (trip != null) {
          // ✅ إنهاء تلقائي للرحلات القديمة المتوقفة (Stuck trips > 24 ساعة)
          final isStuckTrip = DateTime.now().difference(trip.startTime).inHours >= 24;

          if (params.forceEndActiveTrip || isStuckTrip) {
            // إنهاء الرحلة النشطة (الجديدة أو القديمة المتوقفة)
            await repository.endTrip(trip.id);
          } else {
            // إرجاع الرحلة النشطة للسماح للمستخدم بالاختيار
            return Left(
              ActiveTripExistsFailure(
                'يوجد رحلة نشطة بالفعل',
                activeTripId: trip.id,
              ),
            );
          }
        }

        // بدء الرحلة
        return repository.startTrip(
          userId: params.userId,
          routeId: params.routeId,
          modifiedRoute: params.modifiedRoute,
        );
      },
    );
  }
}

/// معاملات بدء الرحلة
class StartTripParams extends Equatable {
  final String userId;
  final String routeId;
  final bool forceEndActiveTrip; // إنهاء الرحلة النشطة تلقائياً
  final dynamic modifiedRoute; // المسار المعدل (اختياري) - يستخدم عند البدء من موقع مختلف

  const StartTripParams({
    required this.userId,
    required this.routeId,
    this.forceEndActiveTrip = false,
    this.modifiedRoute,
  });

  @override
  List<Object?> get props => [userId, routeId, forceEndActiveTrip, modifiedRoute];
}
