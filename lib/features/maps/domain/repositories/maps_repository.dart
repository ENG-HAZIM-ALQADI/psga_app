import 'package:dartz/dartz.dart';
import 'package:psga_app/core/errors/failures.dart';
import 'package:psga_app/features/maps/domain/entities/direction_entity.dart';
import 'package:psga_app/features/maps/domain/entities/place_entity.dart';
import 'package:psga_app/features/routes/domain/entities/location.dart';
import 'package:psga_app/features/maps/domain/entities/place_suggestion.dart';

/// عقد Repository للخرائط والأماكن
/// 
/// يحدد العمليات المتاحة دون التعرض لتفاصيل التنفيذ
/// يطبق Dependency Inversion Principle
abstract class MapsRepository {
  // ==================== Directions ====================
  
  /// الحصول على الاتجاهات بين موقعين
  /// 
  /// [origin] نقطة البداية
  /// [destination] نقطة الوصول
  /// [waypoints] نقاط وسيطة اختيارية
  /// [travelMode] وضع السفر (driving, walking, etc.)
  Future<Either<Failure, DirectionEntity>> getDirections({
    required Location origin,
    required Location destination,
    List<Location>? waypoints,
    String travelMode = 'driving',
  });

  /// الحصول على نقاط الطريق من polyline
  Future<Either<Failure, List<Location>>> getPolylinePoints({
    required Location origin,
    required Location destination,
  });

  /// حساب مسارات بديلة
  Future<Either<Failure, List<DirectionEntity>>> getAlternativeRoutes({
    required Location origin,
    required Location destination,
  });

  // ==================== Places ====================
  
  /// البحث عن أماكن بالنص
  Future<Either<Failure, List<PlaceEntity>>> searchPlaces({
    required String query,
    Location? location,
    int radius = 5000,
    PlaceType? type,
  });

  /// البحث عن أماكن قريبة
  Future<Either<Failure, List<PlaceEntity>>> searchNearbyPlaces({
    required Location location,
    int radius = 5000,
    PlaceType? type,
    String? keyword,
  });

  /// الحصول على اقتراحات تلقائية (Autocomplete)
  Future<Either<Failure, List<PlaceSuggestion>>> getAutocompleteSuggestions({
    required String input,
    Location? location,
    int radius = 50000,
  });

  /// الحصول على تفاصيل مكان من place_id
  Future<Either<Failure, PlaceEntity>> getPlaceDetails({
    required String placeId,
    Location? currentLocation,
  });

  /// البحث عن أماكن حسب الفئة
  Future<Either<Failure, List<PlaceEntity>>> searchByCategory({
    required PlaceType category,
    required Location location,
    int radius = 5000,
  });

  /// الحصول على أماكن الطوارئ القريبة
  Future<Either<Failure, Map<PlaceType, List<PlaceEntity>>>> getEmergencyPlaces({
    required Location location,
    int radius = 10000,
  });

  /// الحصول على أقرب مكان من نوع معين
  Future<Either<Failure, PlaceEntity>> getNearestPlace({
    required Location location,
    required PlaceType type,
    int radius = 5000,
  });
}
