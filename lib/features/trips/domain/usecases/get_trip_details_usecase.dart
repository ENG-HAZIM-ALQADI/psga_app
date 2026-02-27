import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:psga_app/core/errors/failures.dart';
import 'package:psga_app/core/usecases/usecase.dart';
import 'package:psga_app/features/trips/domain/entities/trip_entity.dart';
import 'package:psga_app/features/trips/domain/repositories/trips_repository.dart';

/// حالة استخدام: الحصول على تفاصيل رحلة
class GetTripDetailsUseCase implements UseCase<TripEntity, GetTripDetailsParams> {
  final TripsRepository repository;

  GetTripDetailsUseCase(this.repository);

  @override
  Future<Either<Failure, TripEntity>> call(GetTripDetailsParams params) async {
    if (params.tripId.isEmpty) {
      return const Left(ValidationFailure('معرف الرحلة مطلوب'));
    }

    return repository.getTripById(params.tripId);
  }
}

/// معاملات الحصول على تفاصيل الرحلة
class GetTripDetailsParams extends Equatable {
  final String tripId;

  const GetTripDetailsParams({required this.tripId});

  @override
  List<Object> get props => [tripId];
}
