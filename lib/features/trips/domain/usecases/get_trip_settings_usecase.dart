import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:psga_app/core/errors/failures.dart';
import 'package:psga_app/core/usecases/usecase.dart';
import 'package:psga_app/features/trips/domain/entities/trip_settings_entity.dart';
import 'package:psga_app/features/trips/domain/repositories/trips_repository.dart';

/// حالة استخدام: جلب إعدادات الرحلات
/// Single Responsibility: مسؤول فقط عن جلب الإعدادات
class GetTripSettingsUseCase implements UseCase<TripSettingsEntity, GetTripSettingsParams> {
  final TripsRepository repository;

  GetTripSettingsUseCase(this.repository);

  @override
  Future<Either<Failure, TripSettingsEntity>> call(GetTripSettingsParams params) async {
    return await repository.getTripSettings(params.userId);
  }
}

/// معاملات جلب إعدادات الرحلات
class GetTripSettingsParams extends Equatable {
  final String userId;

  const GetTripSettingsParams({required this.userId});

  @override
  List<Object> get props => [userId];
}
