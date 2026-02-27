import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:psga_app/core/errors/failures.dart';
import 'package:psga_app/core/usecases/usecase.dart';
import 'package:psga_app/features/trips/domain/entities/trip_entity.dart';
import 'package:psga_app/features/trips/domain/repositories/trips_repository.dart';

/// حالة استخدام: استئناف رحلة
class ResumeTripUseCase implements UseCase<TripEntity, ResumeTripParams> {
  final TripsRepository repository;

  ResumeTripUseCase(this.repository);

  @override
  Future<Either<Failure, TripEntity>> call(ResumeTripParams params) async {
    if (params.tripId.isEmpty) {
      return const Left(ValidationFailure('معرف الرحلة مطلوب'));
    }

    return repository.resumeTrip(params.tripId);
  }
}

/// معاملات استئناف الرحلة
class ResumeTripParams extends Equatable {
  final String tripId;

  const ResumeTripParams({required this.tripId});

  @override
  List<Object> get props => [tripId];
}
