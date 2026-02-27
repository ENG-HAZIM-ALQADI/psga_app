import 'package:equatable/equatable.dart';
import 'package:psga_app/features/maps/domain/entities/direction_entity.dart';
import 'package:psga_app/features/maps/domain/entities/place_entity.dart';

/// حالات الخرائط
abstract class MapsState extends Equatable {
  const MapsState();

  @override
  List<Object?> get props => [];
}

/// الحالة الأولية
class MapsInitial extends MapsState {
  const MapsInitial();
}

/// جاري التحميل
class MapsLoading extends MapsState {
  final String? message;

  const MapsLoading({this.message});

  @override
  List<Object?> get props => [message];
}

// ==================== Directions States ====================

/// تم تحميل الاتجاهات
class DirectionsLoaded extends MapsState {
  final DirectionEntity direction;
  final List<DirectionEntity>? alternatives;

  const DirectionsLoaded({
    required this.direction,
    this.alternatives,
  });

  @override
  List<Object?> get props => [direction, alternatives];

  DirectionsLoaded copyWith({
    DirectionEntity? direction,
    List<DirectionEntity>? alternatives,
  }) {
    return DirectionsLoaded(
      direction: direction ?? this.direction,
      alternatives: alternatives ?? this.alternatives,
    );
  }
}

// ==================== Places States ====================

/// تم تحميل الأماكن
class PlacesLoaded extends MapsState {
  final List<PlaceEntity> places;
  final String? searchQuery;

  const PlacesLoaded({
    required this.places,
    this.searchQuery,
  });

  @override
  List<Object?> get props => [places, searchQuery];

  PlacesLoaded copyWith({
    List<PlaceEntity>? places,
    String? searchQuery,
  }) {
    return PlacesLoaded(
      places: places ?? this.places,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

/// تم تحميل تفاصيل مكان
class PlaceDetailsLoaded extends MapsState {
  final PlaceEntity place;

  const PlaceDetailsLoaded(this.place);

  @override
  List<Object?> get props => [place];
}

/// تم تحميل أماكن الطوارئ
class EmergencyPlacesLoaded extends MapsState {
  final Map<PlaceType, List<PlaceEntity>> emergencyPlaces;

  const EmergencyPlacesLoaded(this.emergencyPlaces);

  @override
  List<Object?> get props => [emergencyPlaces];
}

// ==================== Offline Maps States ====================

/// جاري تنزيل الخرائط
class DownloadingMaps extends MapsState {
  final double progress;
  final String status;

  const DownloadingMaps({
    required this.progress,
    required this.status,
  });

  @override
  List<Object?> get props => [progress, status];
}

/// تم تنزيل الخرائط
class MapsDownloaded extends MapsState {
  final String regionId;
  final String message;

  const MapsDownloaded({
    required this.regionId,
    this.message = 'تم تنزيل المنطقة بنجاح',
  });

  @override
  List<Object?> get props => [regionId, message];
}

/// تم تحميل المناطق المحفوظة
class SavedRegionsLoaded extends MapsState {
  final List<Map<String, dynamic>> regions;

  const SavedRegionsLoaded(this.regions);

  @override
  List<Object?> get props => [regions];
}

// ==================== Combined State ====================

/// حالة مركبة تحتوي على كل البيانات
class MapsDataLoaded extends MapsState {
  final DirectionEntity? direction;
  final List<PlaceEntity>? places;
  final PlaceEntity? selectedPlace;
  final Map<PlaceType, List<PlaceEntity>>? emergencyPlaces;
  final List<Map<String, dynamic>>? savedRegions;

  const MapsDataLoaded({
    this.direction,
    this.places,
    this.selectedPlace,
    this.emergencyPlaces,
    this.savedRegions,
  });

  @override
  List<Object?> get props => [
        direction,
        places,
        selectedPlace,
        emergencyPlaces,
        savedRegions,
      ];

  MapsDataLoaded copyWith({
    DirectionEntity? direction,
    List<PlaceEntity>? places,
    PlaceEntity? selectedPlace,
    Map<PlaceType, List<PlaceEntity>>? emergencyPlaces,
    List<Map<String, dynamic>>? savedRegions,
  }) {
    return MapsDataLoaded(
      direction: direction ?? this.direction,
      places: places ?? this.places,
      selectedPlace: selectedPlace ?? this.selectedPlace,
      emergencyPlaces: emergencyPlaces ?? this.emergencyPlaces,
      savedRegions: savedRegions ?? this.savedRegions,
    );
  }
}

// ==================== Error State ====================

/// حالة خطأ
class MapsError extends MapsState {
  final String message;
  final String? errorType;

  const MapsError({
    required this.message,
    this.errorType,
  });

  @override
  List<Object?> get props => [message, errorType];
}

/// حالة فارغة (لا توجد نتائج)
class MapsEmpty extends MapsState {
  final String message;

  const MapsEmpty({
    this.message = 'لا توجد نتائج',
  });

  @override
  List<Object?> get props => [message];
}
