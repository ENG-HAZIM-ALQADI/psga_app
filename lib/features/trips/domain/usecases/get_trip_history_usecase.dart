import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:psga_app/core/errors/failures.dart';
import 'package:psga_app/core/usecases/usecase.dart';
import 'package:psga_app/features/trips/domain/entities/trip_entity.dart';
import 'package:psga_app/features/trips/domain/repositories/trips_repository.dart';

/// حالة استخدام: الحصول على سجل الرحلات
class GetTripHistoryUseCase implements UseCase<List<TripEntity>, GetTripHistoryParams> {
  final TripsRepository repository;

  GetTripHistoryUseCase(this.repository);

  @override
  Future<Either<Failure, List<TripEntity>>> call(GetTripHistoryParams params) async {
    if (params.userId.isEmpty) {
      return const Left(ValidationFailure('معرف المستخدم مطلوب'));
    }

    return repository.getTripHistory(
      userId: params.userId,
      limit: params.limit,
      startDate: params.startDate,
      endDate: params.endDate,
    );
  }
}

/// معاملات الحصول على سجل الرحلات
class GetTripHistoryParams extends Equatable {
  final String userId;
  final int? limit;
  final DateTime? startDate;
  final DateTime? endDate;

  const GetTripHistoryParams({
    required this.userId,
    this.limit,
    this.startDate,
    this.endDate,
  });

  @override
  List<Object?> get props => [userId, limit, startDate, endDate];
}
