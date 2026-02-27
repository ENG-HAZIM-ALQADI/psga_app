import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:psga_app/core/errors/failures.dart';
import 'package:psga_app/core/usecases/usecase.dart';
import 'package:psga_app/features/trips/domain/entities/trip_settings_entity.dart';
import 'package:psga_app/features/trips/domain/repositories/trips_repository.dart';

/// حالة استخدام: حفظ إعدادات الرحلات
/// Single Responsibility: مسؤول فقط عن حفظ الإعدادات
class SaveTripSettingsUseCase implements UseCase<void, SaveTripSettingsParams> {
  final TripsRepository repository;

  SaveTripSettingsUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(SaveTripSettingsParams params) async {
    // التحقق من صحة القيم
    if (params.settings.startLocationThreshold < 10) {
      return const Left(ValidationFailure('عتبة الموقع يجب أن تكون 10 متر على الأقل'));
    }

    if (params.settings.startLocationThreshold > 500) {
      return const Left(ValidationFailure('عتبة الموقع يجب ألا تتجاوز 500 متر'));
    }

    if (params.settings.lowDeviationThreshold >= params.settings.mediumDeviationThreshold) {
      return const Left(ValidationFailure('عتبة الانحراف المنخفض يجب أن تكون أقل من المتوسط'));
    }

    if (params.settings.mediumDeviationThreshold >= params.settings.highDeviationThreshold) {
      return const Left(ValidationFailure('عتبة الانحراف المتوسط يجب أن تكون أقل من العالي'));
    }

    return await repository.saveTripSettings(params.settings);
  }
}

/// معاملات حفظ إعدادات الرحلات
class SaveTripSettingsParams extends Equatable {
  final TripSettingsEntity settings;

  const SaveTripSettingsParams({required this.settings});

  @override
  List<Object> get props => [settings];
}
