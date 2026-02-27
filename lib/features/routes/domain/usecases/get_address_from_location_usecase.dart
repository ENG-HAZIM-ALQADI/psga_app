import 'package:dartz/dartz.dart';
import 'package:psga_app/core/errors/failures.dart';
import 'package:psga_app/core/usecases/usecase.dart';
import 'package:psga_app/core/utils/logger.dart';
import 'package:psga_app/features/routes/domain/entities/location.dart';
import 'package:psga_app/core/services/geocoding_service.dart';

/// Use case للحصول على عنوان من موقع (Reverse Geocoding)
class GetAddressFromLocationUseCase implements UseCase<String?, GetAddressParams> {
  final GeocodingService _geocodingService;

  GetAddressFromLocationUseCase({GeocodingService? geocodingService})
      : _geocodingService = geocodingService ?? GeocodingService.instance;

  @override
  Future<Either<Failure, String?>> call(GetAddressParams params) async {
    try {
      AppLogger.info('[GetAddressFromLocationUseCase] الحصول على العنوان: ${params.location.latitude}, ${params.location.longitude}');

      // التحقق من صحة الموقع
      if (!_isValidLocation(params.location)) {
        return const Left(ValidationFailure('الموقع غير صحيح'));
      }

      // الحصول على العنوان
      final address = await _geocodingService.getAddressFromLocation(params.location);

      if (address == null) {
        AppLogger.warning('[GetAddressFromLocationUseCase] لم يتم العثور على عنوان');
        
        if (params.returnCoordinatesAsFallback) {
          final fallback = '${params.location.latitude.toStringAsFixed(6)}, ${params.location.longitude.toStringAsFixed(6)}';
          AppLogger.info('[GetAddressFromLocationUseCase] استخدام الإحداثيات: $fallback');
          return Right(fallback);
        }
        
        return const Right(null);
      }

      AppLogger.success('[GetAddressFromLocationUseCase] العنوان: $address');
      return Right(address);
    } catch (e, stackTrace) {
      AppLogger.error('[GetAddressFromLocationUseCase] خطأ غير متوقع', e, stackTrace);
      
      if (params.returnCoordinatesAsFallback) {
        final fallback = '${params.location.latitude.toStringAsFixed(6)}, ${params.location.longitude.toStringAsFixed(6)}';
        return Right(fallback);
      }
      
      return Left(ServerFailure('حدث خطأ أثناء الحصول على العنوان: ${e.toString()}'));
    }
  }

  bool _isValidLocation(Location location) {
    return location.latitude >= -90 && 
           location.latitude <= 90 &&
           location.longitude >= -180 && 
           location.longitude <= 180;
  }
}

/// معاملات الحصول على العنوان
class GetAddressParams {
  final Location location;
  final bool returnCoordinatesAsFallback;

  const GetAddressParams({
    required this.location,
    this.returnCoordinatesAsFallback = true,
  });
}
