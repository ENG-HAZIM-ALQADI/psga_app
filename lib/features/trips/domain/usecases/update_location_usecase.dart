import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:psga_app/core/errors/failures.dart';
import 'package:psga_app/core/usecases/usecase.dart';
import 'package:psga_app/features/routes/domain/entities/location.dart';
import 'package:psga_app/features/trips/domain/entities/trip_entity.dart';
import 'package:psga_app/features/trips/domain/repositories/trips_repository.dart';

/// حالة استخدام: تحديث موقع الرحلة
class UpdateLocationUseCase implements UseCase<TripEntity, UpdateLocationParams> {
  final TripsRepository repository;

  UpdateLocationUseCase(this.repository);

  @override
  Future<Either<Failure, TripEntity>> call(UpdateLocationParams params) async {
    if (params.tripId.isEmpty) {
      return const Left(ValidationFailure('معرف الرحلة مطلوب'));
    }

    return repository.updateLocation(
      tripId: params.tripId,
      location: params.location,
    );
  }
}

/// معاملات تحديث الموقع
class UpdateLocationParams extends Equatable {
  final String tripId;
  final Location location;

  const UpdateLocationParams({
    required this.tripId,
    required this.location,
  });

  @override
  List<Object> get props => [tripId, location];
}
