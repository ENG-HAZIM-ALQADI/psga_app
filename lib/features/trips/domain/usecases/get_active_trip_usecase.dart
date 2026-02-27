import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:psga_app/core/errors/failures.dart';
import 'package:psga_app/core/usecases/usecase.dart';
import 'package:psga_app/features/trips/domain/entities/trip_entity.dart';
import 'package:psga_app/features/trips/domain/repositories/trips_repository.dart';

/// حالة استخدام: الحصول على الرحلة النشطة
class GetActiveTripUseCase implements UseCase<TripEntity?, GetActiveTripParams> {
  final TripsRepository repository;

  GetActiveTripUseCase(this.repository);

  @override
  Future<Either<Failure, TripEntity?>> call(GetActiveTripParams params) async {
    if (params.userId.isEmpty) {
      return const Left(ValidationFailure('معرف المستخدم مطلوب'));
    }

    return repository.getActiveTrip(params.userId);
  }
}

/// معاملات الحصول على الرحلة النشطة
class GetActiveTripParams extends Equatable {
  final String userId;

  const GetActiveTripParams({required this.userId});

  @override
  List<Object> get props => [userId];
}
