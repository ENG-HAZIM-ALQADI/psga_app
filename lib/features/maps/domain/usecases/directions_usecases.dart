import 'package:dartz/dartz.dart';
import 'package:psga_app/core/errors/failures.dart';
import 'package:psga_app/core/usecases/usecase.dart';
import 'package:psga_app/core/utils/logger.dart';
import 'package:psga_app/features/routes/domain/entities/location.dart';
import 'package:psga_app/features/maps/domain/entities/direction_entity.dart';
import 'package:psga_app/features/maps/domain/entities/place_entity.dart';
import 'package:psga_app/features/maps/domain/repositories/maps_repository.dart';

/// Use case للحصول على الاتجاهات بين نقطتين
/// 
/// مسؤول فقط عن الحصول على الاتجاهات (Single Responsibility)
class GetDirectionsUseCase implements UseCase<DirectionEntity, GetDirectionsParams> {
  final MapsRepository repository;

  const GetDirectionsUseCase({required this.repository});

  @override
  Future<Either<Failure, DirectionEntity>> call(GetDirectionsParams params) async {
    AppLogger.info(
      '[GetDirectionsUseCase] حساب المسار من (${params.origin.latitude}, ${params.origin.longitude}) '
      'إلى (${params.destination.latitude}, ${params.destination.longitude})',
    );

    // التحقق من صحة المدخلات
    if (!_isValidLocation(params.origin)) {
      AppLogger.warning('[GetDirectionsUseCase] موقع البداية غير صحيح');
      return const Left(ValidationFailure('موقع البداية غير صحيح'));
    }

    if (!_isValidLocation(params.destination)) {
      AppLogger.warning('[GetDirectionsUseCase] موقع الوصول غير صحيح');
      return const Left(ValidationFailure('موقع الوصول غير صحيح'));
    }

    // الحصول على الاتجاهات عبر Repository
    return repository.getDirections(
      origin: params.origin,
      destination: params.destination,
      waypoints: params.waypoints,
      travelMode: params.travelMode,
    );
  }

  bool _isValidLocation(Location location) {
    return location.latitude >= -90 && 
           location.latitude <= 90 &&
           location.longitude >= -180 && 
           location.longitude <= 180;
  }
}

/// Use case للحصول على نقاط الطريق (Polyline Points)
class GetPolylinePointsUseCase implements UseCase<List<Location>, GetPolylineParams> {
  final MapsRepository repository;

  const GetPolylinePointsUseCase({required this.repository});

  @override
  Future<Either<Failure, List<Location>>> call(GetPolylineParams params) async {
    AppLogger.info('[GetPolylinePointsUseCase] جاري الحصول على نقاط الطريق');

    // التحقق من صحة المدخلات
    if (!_isValidLocation(params.origin) || !_isValidLocation(params.destination)) {
      AppLogger.warning('[GetPolylinePointsUseCase] المواقع غير صحيحة');
      return const Left(ValidationFailure('المواقع غير صحيحة'));
    }

    return repository.getPolylinePoints(
      origin: params.origin,
      destination: params.destination,
    );
  }

  bool _isValidLocation(Location location) {
    return location.latitude >= -90 && 
           location.latitude <= 90 &&
           location.longitude >= -180 && 
           location.longitude <= 180;
  }
}

/// Use case للحصول على مسارات بديلة
class GetAlternativeRoutesUseCase implements UseCase<List<DirectionEntity>, GetAlternativeRoutesParams> {
  final MapsRepository repository;

  const GetAlternativeRoutesUseCase({required this.repository});

  @override
  Future<Either<Failure, List<DirectionEntity>>> call(GetAlternativeRoutesParams params) async {
    AppLogger.info('[GetAlternativeRoutesUseCase] البحث عن مسارات بديلة');

    // التحقق من صحة المدخلات
    if (!_isValidLocation(params.origin) || !_isValidLocation(params.destination)) {
      AppLogger.warning('[GetAlternativeRoutesUseCase] المواقع غير صحيحة');
      return const Left(ValidationFailure('المواقع غير صحيحة'));
    }

    return repository.getAlternativeRoutes(
      origin: params.origin,
      destination: params.destination,
    );
  }

  bool _isValidLocation(Location location) {
    return location.latitude >= -90 && 
           location.latitude <= 90 &&
           location.longitude >= -180 && 
           location.longitude <= 180;
  }
}

/// Use case للحصول على أقرب مكان من نوع معين
class GetNearestPlaceUseCase implements UseCase<PlaceEntity, GetNearestPlaceParams> {
  final MapsRepository repository;

  const GetNearestPlaceUseCase({required this.repository});

  @override
  Future<Either<Failure, PlaceEntity>> call(GetNearestPlaceParams params) async {
    AppLogger.info('[GetNearestPlaceUseCase] البحث عن أقرب ${params.type.name}');

    if (!_isValidLocation(params.location)) {
      AppLogger.warning('[GetNearestPlaceUseCase] الموقع غير صحيح');
      return const Left(ValidationFailure('الموقع غير صحيح'));
    }

    return repository.getNearestPlace(
      location: params.location,
      type: params.type,
      radius: params.radius,
    );
  }

  bool _isValidLocation(Location location) {
    return location.latitude >= -90 && 
           location.latitude <= 90 &&
           location.longitude >= -180 && 
           location.longitude <= 180;
  }
}

// ==================== Parameters Classes ====================

/// معاملات الحصول على الاتجاهات
class GetDirectionsParams {
  final Location origin;
  final Location destination;
  final List<Location>? waypoints;
  final String travelMode;

  const GetDirectionsParams({
    required this.origin,
    required this.destination,
    this.waypoints,
    this.travelMode = 'driving',
  });
}

/// معاملات الحصول على نقاط الطريق
class GetPolylineParams {
  final Location origin;
  final Location destination;

  const GetPolylineParams({
    required this.origin,
    required this.destination,
  });
}

/// معاملات الحصول على مسارات بديلة
class GetAlternativeRoutesParams {
  final Location origin;
  final Location destination;

  const GetAlternativeRoutesParams({
    required this.origin,
    required this.destination,
  });
}

/// معاملات الحصول على أقرب مكان
class GetNearestPlaceParams {
  final Location location;
  final PlaceType type;
  final int radius;

  const GetNearestPlaceParams({
    required this.location,
    required this.type,
    this.radius = 5000,
  });
}
