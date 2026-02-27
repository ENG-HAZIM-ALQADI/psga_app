import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:psga_app/core/utils/logger.dart';
import 'package:psga_app/core/services/offline_maps_manager.dart';
import 'package:psga_app/features/maps/domain/usecases/directions_usecases.dart';
import 'package:psga_app/features/maps/domain/usecases/places_usecases.dart';
import 'package:psga_app/features/maps/presentation/bloc/maps/maps_event.dart';
import 'package:psga_app/features/maps/presentation/bloc/maps/maps_state.dart';

/// BLoC لإدارة حالة الخرائط والاتجاهات والأماكن
/// 
/// يدير جميع العمليات المتعلقة بالخرائط بما في ذلك:
/// - الاتجاهات والمسارات
/// - البحث عن الأماكن
/// - تنزيل الخرائط للاستخدام الأوفلاين
class MapsBloc extends Bloc<MapsEvent, MapsState> {
  // Use Cases - Directions
  final GetDirectionsUseCase getDirectionsUseCase;
  final GetAlternativeRoutesUseCase getAlternativeRoutesUseCase;
  
  // Use Cases - Places
  final SearchPlacesUseCase searchPlacesUseCase;
  final SearchNearbyPlacesUseCase searchNearbyPlacesUseCase;
  final GetPlaceAutocompleteSuggestionsUseCase getPlaceAutocompleteSuggestionsUseCase;
  final GetNearestPlaceUseCase getNearestPlaceUseCase;
  
  // Offline Maps Manager
  final OfflineMapsManager offlineMapsManager;

  MapsBloc({
    required this.getDirectionsUseCase,
    required this.getAlternativeRoutesUseCase,
    required this.searchPlacesUseCase,
    required this.searchNearbyPlacesUseCase,
    required this.getPlaceAutocompleteSuggestionsUseCase,
    required this.getNearestPlaceUseCase,
    required this.offlineMapsManager,
  }) : super(const MapsInitial()) {
    on<GetDirectionsEvent>(_onGetDirections);
    on<GetAlternativeRoutesEvent>(_onGetAlternativeRoutes);
    on<ClearDirectionsEvent>(_onClearDirections);
    
    on<SearchPlacesEvent>(_onSearchPlaces);
    on<SearchNearbyPlacesEvent>(_onSearchNearbyPlaces);
    on<GetPlaceDetailsEvent>(_onGetPlaceDetails);
    on<GetNearestPlaceEvent>(_onGetNearestPlace);
    on<GetEmergencyPlacesEvent>(_onGetEmergencyPlaces);
    on<ClearPlacesEvent>(_onClearPlaces);
    
    on<DownloadMapRegionEvent>(_onDownloadMapRegion);
    on<GetSavedRegionsEvent>(_onGetSavedRegions);
    on<DeleteRegionEvent>(_onDeleteRegion);
    on<ClearAllMapsEvent>(_onClearAllMaps);
    on<UpdateDownloadProgressEvent>(_onUpdateDownloadProgress);
  }

  // ==================== Directions Handlers ====================

  Future<void> _onGetDirections(
    GetDirectionsEvent event,
    Emitter<MapsState> emit,
  ) async {
    try {
      AppLogger.info('[MapsBloc] جاري الحصول على الاتجاهات');
      emit(const MapsLoading(message: 'calculatingRoute'));

      final result = await getDirectionsUseCase(
        GetDirectionsParams(
          origin: event.origin,
          destination: event.destination,
          waypoints: event.waypoints,
          travelMode: event.travelMode,
        ),
      );

      result.fold(
        (failure) {
          AppLogger.error('[MapsBloc] فشل الحصول على الاتجاهات', failure.message);
          emit(MapsError(message: failure.message, errorType: 'directions'));
        },
        (direction) {
          AppLogger.success('[MapsBloc] تم الحصول على الاتجاهات');
          emit(DirectionsLoaded(direction: direction));
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('[MapsBloc] خطأ غير متوقع', e, stackTrace);
      emit(const MapsError(message: 'routeCalcError'));
    }
  }

  Future<void> _onGetAlternativeRoutes(
    GetAlternativeRoutesEvent event,
    Emitter<MapsState> emit,
  ) async {
    try {
      AppLogger.info('[MapsBloc] جاري البحث عن مسارات بديلة');
      emit(const MapsLoading(message: 'searchingAlternatives'));

      final result = await getAlternativeRoutesUseCase(
        GetAlternativeRoutesParams(
          origin: event.origin,
          destination: event.destination,
        ),
      );

      result.fold(
        (failure) {
          AppLogger.error('[MapsBloc] فشل الحصول على مسارات بديلة', failure.message);
          emit(MapsError(message: failure.message, errorType: 'alternatives'));
        },
        (routes) {
          AppLogger.success('[MapsBloc] تم إيجاد ${routes.length} مسار');
          if (routes.isNotEmpty) {
            emit(DirectionsLoaded(
              direction: routes.first,
              alternatives: routes.length > 1 ? routes.sublist(1) : null,
            ));
          } else {
            emit(const MapsEmpty(message: 'noRoutesFound'));
          }
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('[MapsBloc] خطأ غير متوقع', e, stackTrace);
      emit(const MapsError(message: 'alternativeSearchError'));
    }
  }

  Future<void> _onClearDirections(
    ClearDirectionsEvent event,
    Emitter<MapsState> emit,
  ) async {
    AppLogger.info('[MapsBloc] مسح الاتجاهات');
    emit(const MapsInitial());
  }

  // ==================== Places Handlers ====================

  Future<void> _onSearchPlaces(
    SearchPlacesEvent event,
    Emitter<MapsState> emit,
  ) async {
    try {
      AppLogger.info('[MapsBloc] البحث عن: ${event.query}');
      emit(const MapsLoading(message: 'searching'));

      final result = await searchPlacesUseCase(
        SearchPlacesParams(
          query: event.query,
          location: event.location,
          radius: event.radius,
          type: event.type,
        ),
      );

      result.fold(
        (failure) {
          AppLogger.error('[MapsBloc] فشل البحث', failure.message);
          emit(MapsError(message: failure.message, errorType: 'search'));
        },
        (places) {
          AppLogger.success('[MapsBloc] تم العثور على ${places.length} نتيجة');
          if (places.isNotEmpty) {
            emit(PlacesLoaded(places: places, searchQuery: event.query));
          } else {
            emit(const MapsEmpty(message: 'noSearchResults'));
          }
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('[MapsBloc] خطأ غير متوقع', e, stackTrace);
      emit(const MapsError(message: 'searchError'));
    }
  }

  Future<void> _onSearchNearbyPlaces(
    SearchNearbyPlacesEvent event,
    Emitter<MapsState> emit,
  ) async {
    try {
      AppLogger.info('[MapsBloc] البحث عن أماكن قريبة');
      emit(const MapsLoading(message: 'searchingNearby'));

      final result = await searchNearbyPlacesUseCase(
        SearchNearbyParams(
          location: event.location,
          radius: event.radius,
          type: event.type,
          keyword: event.keyword,
        ),
      );

      result.fold(
        (failure) {
          AppLogger.error('[MapsBloc] فشل البحث', failure.message);
          emit(MapsError(message: failure.message, errorType: 'nearby'));
        },
        (places) {
          AppLogger.success('[MapsBloc] تم العثور على ${places.length} مكان');
          if (places.isNotEmpty) {
            emit(PlacesLoaded(places: places));
          } else {
            emit(const MapsEmpty(message: 'noNearbyPlaces'));
          }
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('[MapsBloc] خطأ غير متوقع', e, stackTrace);
      emit(const MapsError(message: 'searchError'));
    }
  }

  Future<void> _onGetPlaceDetails(
    GetPlaceDetailsEvent event,
    Emitter<MapsState> emit,
  ) async {
    try {
      AppLogger.info('[MapsBloc] الحصول على تفاصيل المكان');
      emit(const MapsLoading(message: 'loadingDetails'));

      // استخدام repository مباشرة لأنه لا يوجد UseCase مخصص
      // يمكن إضافة UseCase إذا لزم الأمر
      
      AppLogger.warning('[MapsBloc] GetPlaceDetails UseCase غير متوفر بعد');
      emit(const MapsError(message: 'featureUnderDevelopment'));
    } catch (e, stackTrace) {
      AppLogger.error('[MapsBloc] خطأ غير متوقع', e, stackTrace);
      emit(const MapsError(message: 'loadingError'));
    }
  }

  Future<void> _onGetNearestPlace(
    GetNearestPlaceEvent event,
    Emitter<MapsState> emit,
  ) async {
    try {
      AppLogger.info('[MapsBloc] البحث عن أقرب ${event.type.name}');
      emit(const MapsLoading(message: 'searching'));

      final result = await getNearestPlaceUseCase(
        GetNearestPlaceParams(
          location: event.location,
          type: event.type,
          radius: event.radius,
        ),
      );

      result.fold(
        (failure) {
          AppLogger.error('[MapsBloc] فشل البحث', failure.message);
          emit(MapsError(message: failure.message, errorType: 'nearest'));
        },
        (place) {
          AppLogger.success('[MapsBloc] تم العثور على: ${place.name}');
          emit(PlaceDetailsLoaded(place));
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('[MapsBloc] خطأ غير متوقع', e, stackTrace);
      emit(const MapsError(message: 'searchError'));
    }
  }

  Future<void> _onGetEmergencyPlaces(
    GetEmergencyPlacesEvent event,
    Emitter<MapsState> emit,
  ) async {
    try {
      AppLogger.info('[MapsBloc] البحث عن أماكن الطوارئ');
      emit(const MapsLoading(message: 'searchingEmergency'));

      // استخدام repository مباشرة
      AppLogger.warning('[MapsBloc] GetEmergencyPlaces UseCase غير متوفر بعد');
      emit(const MapsError(message: 'featureUnderDevelopment'));
    } catch (e, stackTrace) {
      AppLogger.error('[MapsBloc] خطأ غير متوقع', e, stackTrace);
      emit(const MapsError(message: 'searchError'));
    }
  }

  Future<void> _onClearPlaces(
    ClearPlacesEvent event,
    Emitter<MapsState> emit,
  ) async {
    AppLogger.info('[MapsBloc] مسح نتائج البحث');
    emit(const MapsInitial());
  }

  // ==================== Offline Maps Handlers ====================

  Future<void> _onDownloadMapRegion(
    DownloadMapRegionEvent event,
    Emitter<MapsState> emit,
  ) async {
    try {
      AppLogger.info('[MapsBloc] بدء تنزيل منطقة الخريطة');
      emit(const DownloadingMaps(progress: 0.0, status: 'preparingDownload'));

      final success = await offlineMapsManager.downloadMapRegion(
        center: event.center,
        radiusKm: event.radiusKm,
        zoomLevels: event.zoomLevels,
        onProgress: (progress, status) {
          add(UpdateDownloadProgressEvent(progress: progress, status: status));
        },
      );

      if (success) {
        AppLogger.success('[MapsBloc] تم تنزيل المنطقة بنجاح');
        emit(const MapsDownloaded(regionId: 'region_id'));
      } else {
        AppLogger.error('[MapsBloc] فشل تنزيل المنطقة');
        emit(const MapsError(message: 'regionDownloadFailed'));
      }
    } catch (e, stackTrace) {
      AppLogger.error('[MapsBloc] خطأ غير متوقع', e, stackTrace);
      emit(const MapsError(message: 'downloadError'));
    }
  }

  Future<void> _onGetSavedRegions(
    GetSavedRegionsEvent event,
    Emitter<MapsState> emit,
  ) async {
    try {
      AppLogger.info('[MapsBloc] جاري تحميل المناطق المحفوظة');
      
      final regions = await offlineMapsManager.getSavedRegions();
      
      AppLogger.success('[MapsBloc] تم تحميل ${regions.length} منطقة');
      emit(SavedRegionsLoaded(regions));
    } catch (e, stackTrace) {
      AppLogger.error('[MapsBloc] خطأ غير متوقع', e, stackTrace);
      emit(const MapsError(message: 'loadingError'));
    }
  }

  Future<void> _onDeleteRegion(
    DeleteRegionEvent event,
    Emitter<MapsState> emit,
  ) async {
    try {
      AppLogger.info('[MapsBloc] حذف منطقة: ${event.regionId}');
      
      final success = await offlineMapsManager.deleteRegion(event.regionId);
      
      if (success) {
        AppLogger.success('[MapsBloc] تم حذف المنطقة');
        // إعادة تحميل القائمة
        add(const GetSavedRegionsEvent());
      } else {
        emit(const MapsError(message: 'regionDeleteFailed'));
      }
    } catch (e, stackTrace) {
      AppLogger.error('[MapsBloc] خطأ غير متوقع', e, stackTrace);
      emit(const MapsError(message: 'deleteError'));
    }
  }

  Future<void> _onClearAllMaps(
    ClearAllMapsEvent event,
    Emitter<MapsState> emit,
  ) async {
    try {
      AppLogger.info('[MapsBloc] حذف جميع الخرائط');
      
      final success = await offlineMapsManager.clearAllMaps();
      
      if (success) {
        AppLogger.success('[MapsBloc] تم حذف جميع الخرائط');
        emit(const SavedRegionsLoaded([]));
      } else {
        emit(const MapsError(message: 'mapsDeleteFailed'));
      }
    } catch (e, stackTrace) {
      AppLogger.error('[MapsBloc] خطأ غير متوقع', e, stackTrace);
      emit(const MapsError(message: 'deleteError'));
    }
  }

  Future<void> _onUpdateDownloadProgress(
    UpdateDownloadProgressEvent event,
    Emitter<MapsState> emit,
  ) async {
    emit(DownloadingMaps(
      progress: event.progress,
      status: event.status,
    ));
  }
}
