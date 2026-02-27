import 'package:dartz/dartz.dart';
import 'package:psga_app/core/errors/exceptions.dart';
import 'package:psga_app/core/errors/failures.dart';
import 'package:psga_app/core/utils/logger.dart';
import 'package:psga_app/features/maps/data/datasources/remote/maps_remote_data_source.dart';
import 'package:psga_app/features/maps/data/datasources/local/maps_local_data_source.dart';
import 'package:psga_app/features/maps/domain/entities/direction_entity.dart';
import 'package:psga_app/features/maps/domain/entities/place_entity.dart';
import 'package:psga_app/features/maps/domain/repositories/maps_repository.dart';
import 'package:psga_app/features/routes/domain/entities/location.dart';
import 'package:psga_app/features/maps/domain/entities/place_suggestion.dart';
import 'package:psga_app/core/services/connectivity_service.dart';

/// تنفيذ Repository للخرائط مع دعم التخزين المحلي
/// 
/// يربط Domain Layer مع Data Layer
/// يدعم Offline Mode والتخزين المؤقت
/// يطبق Dependency Inversion Principle
class MapsRepositoryImpl implements MapsRepository {
  final MapsRemoteDataSource remoteDataSource;
  final MapsLocalDataSource localDataSource;
  final ConnectivityService connectivityService;

  MapsRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.connectivityService,
  });

  @override
  Future<Either<Failure, DirectionEntity>> getDirections({
    required Location origin,
    required Location destination,
    List<Location>? waypoints,
    String travelMode = 'driving',
  }) async {
    try {
      AppLogger.info('[MapsRepository] جاري الحصول على الاتجاهات');

      // محاولة الحصول على اتجاهات محفوظة أولاً
      if (!connectivityService.isConnected) {
        AppLogger.warning('[MapsRepository] لا يوجد اتصال - البحث محلياً');
        
        final cachedDirection = await localDataSource.getCachedDirection(
          origin,
          destination,
        );
        
        if (cachedDirection != null) {
          AppLogger.success('[MapsRepository] تم العثور على اتجاهات محفوظة');
          return Right(cachedDirection.toEntity());
        }
        
        return const Left(NetworkFailure('لا يوجد اتصال بالإنترنت ولا توجد اتجاهات محفوظة'));
      }

      // جلب من الشبكة
      final directionModel = await remoteDataSource.getDirections(
        origin: origin,
        destination: destination,
        waypoints: waypoints,
        travelMode: travelMode,
      );

      // حفظ في الذاكرة المحلية
      await localDataSource.cacheDirection(directionModel);

      AppLogger.success('[MapsRepository] تم الحصول على الاتجاهات بنجاح');
      return Right(directionModel.toEntity());
    } on ServerException catch (e) {
      AppLogger.error('[MapsRepository] خطأ من الخادم', e.message);
      
      // محاولة الحصول من الذاكرة المحلية
      final cachedDirection = await localDataSource.getCachedDirection(
        origin,
        destination,
      );
      
      if (cachedDirection != null) {
        AppLogger.info('[MapsRepository] استخدام اتجاهات محفوظة بسبب خطأ الخادم');
        return Right(cachedDirection.toEntity());
      }
      
      return Left(ServerFailure(e.message));
    } catch (e, stackTrace) {
      AppLogger.error('[MapsRepository] خطأ غير متوقع', e, stackTrace);
      return const Left(ServerFailure('حدث خطأ غير متوقع'));
    }
  }

  @override
  Future<Either<Failure, List<Location>>> getPolylinePoints({
    required Location origin,
    required Location destination,
  }) async {
    try {
      AppLogger.info('[MapsRepository] جاري الحصول على نقاط الطريق');

      final directionModel = await remoteDataSource.getDirections(
        origin: origin,
        destination: destination,
      );

      AppLogger.success('[MapsRepository] تم الحصول على ${directionModel.polylinePoints.length} نقطة');
      return Right(directionModel.polylinePoints);
    } on ServerException catch (e) {
      AppLogger.error('[MapsRepository] خطأ من الخادم', e.message);
      return Left(ServerFailure(e.message));
    } catch (e, stackTrace) {
      AppLogger.error('[MapsRepository] خطأ غير متوقع', e, stackTrace);
      return const Left(ServerFailure('حدث خطأ غير متوقع'));
    }
  }

  @override
  Future<Either<Failure, List<DirectionEntity>>> getAlternativeRoutes({
    required Location origin,
    required Location destination,
  }) async {
    try {
      AppLogger.info('[MapsRepository] البحث عن مسارات بديلة');

      // حالياً نحصل على مسار واحد فقط
      // يمكن توسيع هذا للحصول على عدة مسارات بأوضاع مختلفة
      final directionModel = await remoteDataSource.getDirections(
        origin: origin,
        destination: destination,
      );

      AppLogger.success('[MapsRepository] تم إيجاد مسار واحد');
      return Right([directionModel.toEntity()]);
    } on ServerException catch (e) {
      AppLogger.error('[MapsRepository] خطأ من الخادم', e.message);
      return Left(ServerFailure(e.message));
    } catch (e, stackTrace) {
      AppLogger.error('[MapsRepository] خطأ غير متوقع', e, stackTrace);
      return const Left(ServerFailure('حدث خطأ غير متوقع'));
    }
  }

  @override
  Future<Either<Failure, List<PlaceEntity>>> searchPlaces({
    required String query,
    Location? location,
    int radius = 5000,
    PlaceType? type,
  }) async {
    try {
      AppLogger.info('[MapsRepository] البحث عن: $query');

      final cacheKey = 'search_$query${type?.name ?? 'all'}_$radius';

      // محاولة الحصول من الذاكرة المحلية أولاً
      if (!connectivityService.isConnected) {
        AppLogger.warning('[MapsRepository] لا يوجد اتصال - البحث محلياً');
        
        final cachedPlaces = await localDataSource.getCachedPlaces(cacheKey);
        
        if (cachedPlaces != null && cachedPlaces.isNotEmpty) {
          AppLogger.success('[MapsRepository] تم العثور على ${cachedPlaces.length} مكان محفوظ');
          return Right(cachedPlaces.map((m) => m.toEntity()).toList());
        }
        
        return const Left(NetworkFailure('لا يوجد اتصال بالإنترنت ولا توجد نتائج محفوظة'));
      }

      // جلب من الشبكة
      final placeModels = await remoteDataSource.searchPlaces(
        query: query,
        location: location,
        radius: radius,
        type: type,
      );

      // حفظ في الذاكرة المحلية
      if (placeModels.isNotEmpty) {
        await localDataSource.cachePlaces(placeModels, cacheKey);
      }

      final entities = placeModels.map((model) => model.toEntity()).toList();
      AppLogger.success('[MapsRepository] تم العثور على ${entities.length} نتيجة');
      
      return Right(entities);
    } on ServerException catch (e) {
      AppLogger.error('[MapsRepository] خطأ من الخادم', e.message);
      
      // محاولة الحصول من الذاكرة المحلية
      final cacheKey = 'search_$query${type?.name ?? 'all'}_$radius';
      final cachedPlaces = await localDataSource.getCachedPlaces(cacheKey);
      
      if (cachedPlaces != null && cachedPlaces.isNotEmpty) {
        AppLogger.info('[MapsRepository] استخدام نتائج محفوظة بسبب خطأ الخادم');
        return Right(cachedPlaces.map((m) => m.toEntity()).toList());
      }
      
      return Left(ServerFailure(e.message));
    } catch (e, stackTrace) {
      AppLogger.error('[MapsRepository] خطأ غير متوقع', e, stackTrace);
      return const Left(ServerFailure('حدث خطأ غير متوقع'));
    }
  }

  @override
  Future<Either<Failure, List<PlaceEntity>>> searchNearbyPlaces({
    required Location location,
    int radius = 5000,
    PlaceType? type,
    String? keyword,
  }) async {
    try {
      AppLogger.info('[MapsRepository] البحث عن أماكن قريبة');

      final placeModels = await remoteDataSource.searchNearbyPlaces(
        location: location,
        radius: radius,
        type: type,
        keyword: keyword,
      );

      final entities = placeModels.map((model) => model.toEntity()).toList();
      AppLogger.success('[MapsRepository] تم العثور على ${entities.length} مكان قريب');
      
      return Right(entities);
    } on ServerException catch (e) {
      AppLogger.error('[MapsRepository] خطأ من الخادم', e.message);
      return Left(ServerFailure(e.message));
    } catch (e, stackTrace) {
      AppLogger.error('[MapsRepository] خطأ غير متوقع', e, stackTrace);
      return const Left(ServerFailure('حدث خطأ غير متوقع'));
    }
  }

  @override
  Future<Either<Failure, List<PlaceSuggestion>>> getAutocompleteSuggestions({
    required String input,
    Location? location,
    int radius = 50000,
  }) async {
    try {
      if (input.trim().isEmpty) {
        return const Right([]);
      }

      AppLogger.info('[MapsRepository] الحصول على اقتراحات: $input');

      final suggestions = await remoteDataSource.getAutocompleteSuggestions(
        input: input,
        location: location,
        radius: radius,
      );

      AppLogger.success('[MapsRepository] ${suggestions.length} اقتراح');
      return Right(suggestions);
    } on ServerException catch (e) {
      AppLogger.error('[MapsRepository] خطأ من الخادم', e.message);
      return Left(ServerFailure(e.message));
    } catch (e, stackTrace) {
      AppLogger.error('[MapsRepository] خطأ غير متوقع', e, stackTrace);
      return const Left(ServerFailure('حدث خطأ غير متوقع'));
    }
  }

  @override
  Future<Either<Failure, PlaceEntity>> getPlaceDetails({
    required String placeId,
    Location? currentLocation,
  }) async {
    try {
      AppLogger.info('[MapsRepository] الحصول على تفاصيل: $placeId');

      final placeModel = await remoteDataSource.getPlaceDetails(
        placeId: placeId,
        currentLocation: currentLocation,
      );

      AppLogger.success('[MapsRepository] تم الحصول على التفاصيل بنجاح');
      return Right(placeModel.toEntity());
    } on ServerException catch (e) {
      AppLogger.error('[MapsRepository] خطأ من الخادم', e.message);
      return Left(ServerFailure(e.message));
    } catch (e, stackTrace) {
      AppLogger.error('[MapsRepository] خطأ غير متوقع', e, stackTrace);
      return const Left(ServerFailure('حدث خطأ غير متوقع'));
    }
  }

  @override
  Future<Either<Failure, List<PlaceEntity>>> searchByCategory({
    required PlaceType category,
    required Location location,
    int radius = 5000,
  }) async {
    return searchNearbyPlaces(
      location: location,
      radius: radius,
      type: category,
    );
  }

  @override
  Future<Either<Failure, Map<PlaceType, List<PlaceEntity>>>> getEmergencyPlaces({
    required Location location,
    int radius = 10000,
  }) async {
    try {
      AppLogger.info('[MapsRepository] البحث عن أماكن الطوارئ');

      final emergencyTypes = [
        PlaceType.hospital,
        PlaceType.police,
        PlaceType.pharmacy,
      ];

      final results = <PlaceType, List<PlaceEntity>>{};

      for (final type in emergencyTypes) {
        final placesResult = await searchNearbyPlaces(
          location: location,
          radius: radius,
          type: type,
        );

        placesResult.fold(
          (failure) {
            AppLogger.warning('[MapsRepository] فشل البحث عن ${type.name}');
          },
          (places) {
            if (places.isNotEmpty) {
              results[type] = places;
            }
          },
        );
      }

      AppLogger.success('[MapsRepository] تم إيجاد ${results.length} فئة طوارئ');
      return Right(results);
    } catch (e, stackTrace) {
      AppLogger.error('[MapsRepository] خطأ غير متوقع', e, stackTrace);
      return const Left(ServerFailure('حدث خطأ غير متوقع'));
    }
  }

  @override
  Future<Either<Failure, PlaceEntity>> getNearestPlace({
    required Location location,
    required PlaceType type,
    int radius = 5000,
  }) async {
    try {
      AppLogger.info('[MapsRepository] البحث عن أقرب ${type.name}');

      final placesResult = await searchNearbyPlaces(
        location: location,
        radius: radius,
        type: type,
      );

      return placesResult.fold(
        (failure) => Left(failure),
        (places) {
          if (places.isEmpty) {
            return const Left(NotFoundFailure('لا توجد أماكن قريبة من هذا النوع'));
          }

          // ترتيب حسب المسافة والحصول على الأقرب
          places.sort((a, b) {
            if (a.distance == null) return 1;
            if (b.distance == null) return -1;
            return a.distance!.compareTo(b.distance!);
          });

          AppLogger.success('[MapsRepository] تم إيجاد أقرب مكان: ${places.first.name}');
          return Right(places.first);
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('[MapsRepository] خطأ غير متوقع', e, stackTrace);
      return const Left(ServerFailure('حدث خطأ غير متوقع'));
    }
  }
}
