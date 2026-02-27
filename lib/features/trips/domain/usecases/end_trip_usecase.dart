import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:psga_app/core/errors/failures.dart';
import 'package:psga_app/core/usecases/usecase.dart';
import 'package:psga_app/features/trips/domain/entities/trip_entity.dart';
import 'package:psga_app/features/trips/domain/repositories/trips_repository.dart';

/// حالة استخدام: إنهاء رحلة
class EndTripUseCase implements UseCase<TripEntity, EndTripParams> {
  final TripsRepository repository;

  EndTripUseCase(this.repository);

  @override
  Future<Either<Failure, TripEntity>> call(EndTripParams params) async {
    if (params.tripId.isEmpty) {
      return const Left(ValidationFailure('معرف الرحلة مطلوب'));
    }

    return repository.endTrip(params.tripId);
  }
}

/// معاملات إنهاء الرحلة
class EndTripParams extends Equatable {
  final String tripId;

  const EndTripParams({required this.tripId});

  @override
  List<Object> get props => [tripId];
}
