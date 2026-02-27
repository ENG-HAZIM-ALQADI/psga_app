import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:psga_app/core/errors/failures.dart';
import 'package:psga_app/core/usecases/usecase.dart';
import 'package:psga_app/features/trips/domain/entities/trip_entity.dart';
import 'package:psga_app/features/trips/domain/repositories/trips_repository.dart';

/// حالة استخدام: إيقاف رحلة مؤقتاً
class PauseTripUseCase implements UseCase<TripEntity, PauseTripParams> {
  final TripsRepository repository;

  PauseTripUseCase(this.repository);

  @override
  Future<Either<Failure, TripEntity>> call(PauseTripParams params) async {
    if (params.tripId.isEmpty) {
      return const Left(ValidationFailure('معرف الرحلة مطلوب'));
    }

    return repository.pauseTrip(params.tripId);
  }
}

/// معاملات إيقاف الرحلة
class PauseTripParams extends Equatable {
  final String tripId;

  const PauseTripParams({required this.tripId});

  @override
  List<Object> get props => [tripId];
}
