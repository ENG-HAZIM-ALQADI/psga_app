import 'package:dartz/dartz.dart';
import 'package:psga_app/core/errors/failures.dart';
import 'package:psga_app/core/usecases/usecase.dart';
import 'package:psga_app/core/utils/logger.dart';
import 'package:psga_app/features/routes/domain/entities/location.dart';
import 'package:psga_app/features/maps/domain/entities/place_entity.dart';
import 'package:psga_app/features/maps/domain/repositories/maps_repository.dart';
import 'package:psga_app/features/maps/domain/entities/place_suggestion.dart';

/// Use case للبحث عن أماكن
/// 
/// يستخدم Repository بدلاً من Service مباشرة (Dependency Inversion)
class SearchPlacesUseCase implements UseCase<List<PlaceEntity>, SearchPlacesParams> {
  final MapsRepository repository;

  const SearchPlacesUseCase({required this.repository});

  @override
  Future<Either<Failure, List<PlaceEntity>>> call(SearchPlacesParams params) async {
    AppLogger.info('[SearchPlacesUseCase] البحث عن: ${params.query}');

    // التحقق من صحة المدخلات
    if (params.query.trim().isEmpty) {
      AppLogger.warning('[SearchPlacesUseCase] نص البحث فارغ');
      return const Left(ValidationFailure('نص البحث مطلوب'));
    }

    if (params.query.trim().length < 2) {
      AppLogger.warning('[SearchPlacesUseCase] نص البحث قصير جداً');
      return const Left(ValidationFailure('نص البحث يجب أن يكون حرفين على الأقل'));
    }

    // البحث عن الأماكن عبر Repository
    return repository.searchPlaces(
      query: params.query,
      location: params.location,
      radius: params.radius,
      type: params.type,
    );
  }
}

/// Use case للبحث عن أماكن قريبة
/// 
/// يستخدم Repository بدلاً من Service مباشرة
class SearchNearbyPlacesUseCase implements UseCase<List<PlaceEntity>, SearchNearbyParams> {
  final MapsRepository repository;

  const SearchNearbyPlacesUseCase({required this.repository});

  @override
  Future<Either<Failure, List<PlaceEntity>>> call(SearchNearbyParams params) async {
    AppLogger.info('[SearchNearbyPlacesUseCase] البحث عن أماكن قريبة');

    // التحقق من صحة الموقع
    if (!_isValidLocation(params.location)) {
      AppLogger.warning('[SearchNearbyPlacesUseCase] الموقع غير صحيح');
      return const Left(ValidationFailure('الموقع غير صحيح'));
    }

    // البحث عن أماكن قريبة عبر Repository
    return repository.searchNearbyPlaces(
      location: params.location,
      radius: params.radius,
      type: params.type,
      keyword: params.keyword,
    );
  }

  bool _isValidLocation(Location location) {
    return location.latitude >= -90 && 
           location.latitude <= 90 &&
           location.longitude >= -180 && 
           location.longitude <= 180;
  }
}

/// Use case للحصول على اقتراحات تلقائية
/// 
/// يستخدم Repository بدلاً من Service مباشرة
class GetPlaceAutocompleteSuggestionsUseCase implements UseCase<List<PlaceSuggestion>, GetSuggestionsParams> {
  final MapsRepository repository;

  const GetPlaceAutocompleteSuggestionsUseCase({required this.repository});

  @override
  Future<Either<Failure, List<PlaceSuggestion>>> call(GetSuggestionsParams params) async {
    if (params.input.trim().isEmpty) {
      return const Right([]);
    }

    AppLogger.info('[GetPlaceAutocompleteSuggestionsUseCase] الحصول على اقتراحات: ${params.input}');

    return repository.getAutocompleteSuggestions(
      input: params.input,
      location: params.location,
      radius: params.radius,
    );
  }
}

/// معاملات البحث عن أماكن
class SearchPlacesParams {
  final String query;
  final Location? location;
  final int radius;
  final PlaceType? type;

  const SearchPlacesParams({
    required this.query,
    this.location,
    this.radius = 5000,
    this.type,
  });
}

/// معاملات البحث عن أماكن قريبة
class SearchNearbyParams {
  final Location location;
  final int radius;
  final PlaceType? type;
  final String? keyword;

  const SearchNearbyParams({
    required this.location,
    this.radius = 5000,
    this.type,
    this.keyword,
  });
}

/// معاملات الحصول على اقتراحات
class GetSuggestionsParams {
  final String input;
  final Location? location;
  final int radius;

  const GetSuggestionsParams({
    required this.input,
    this.location,
    this.radius = 50000,
  });
}
