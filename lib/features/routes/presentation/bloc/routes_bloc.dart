import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:psga_app/core/utils/logger.dart';
import 'package:psga_app/features/routes/domain/entities/route.dart';
import 'package:psga_app/features/routes/domain/usecases/create_route_usecase.dart';
import 'package:psga_app/features/routes/domain/usecases/get_user_routes_usecase.dart';
import 'package:psga_app/features/routes/domain/usecases/routes_usecases.dart';
import 'package:psga_app/features/routes/domain/usecases/sync_routes_usecase.dart';
import 'package:psga_app/features/routes/domain/usecases/update_route_status_usecase.dart';
import 'package:psga_app/features/routes/domain/usecases/get_active_routes_usecase.dart';
import 'package:psga_app/features/routes/presentation/bloc/routes_event.dart';
import 'package:psga_app/features/routes/presentation/bloc/routes_state.dart';

/// BLoC لإدارة المسارات
/// ✅ يتبع Clean Architecture: يعتمد على UseCases فقط
class RoutesBloc extends Bloc<RoutesEvent, RoutesState> {
  final CreateRouteUseCase createRoute;
  final GetUserRoutesUseCase getUserRoutes;
  final UpdateRouteUseCase updateRoute;
  final DeleteRouteUseCase deleteRoute;
  final ToggleFavoriteUseCase toggleFavorite;
  final SearchRoutesUseCase searchRoutes;
  final GetFavoriteRoutesUseCase getFavoriteRoutes;
  final SyncRoutesUseCase syncRoutes;
  final UpdateRouteStatusUseCase updateRouteStatus;
  final GetActiveRoutesUseCase getActiveRoutes;

  RoutesBloc({
    required this.createRoute,
    required this.getUserRoutes,
    required this.updateRoute,
    required this.deleteRoute,
    required this.toggleFavorite,
    required this.searchRoutes,
    required this.getFavoriteRoutes,
    required this.syncRoutes,
    required this.updateRouteStatus,
    required this.getActiveRoutes,
  }) : super(const RoutesInitial()) {
    on<LoadRoutesEvent>(_onLoadRoutes);
    on<CreateRouteEvent>(_onCreateRoute);
    on<UpdateRouteEvent>(_onUpdateRoute);
    on<DeleteRouteEvent>(_onDeleteRoute);
    on<ToggleFavoriteEvent>(_onToggleFavorite);
    on<SearchRoutesEvent>(_onSearchRoutes);
    on<FilterRoutesEvent>(_onFilterRoutes);
    on<RefreshRoutesEvent>(_onRefreshRoutes);
    on<SyncRoutesEvent>(_onSyncRoutes);
    on<LoadActiveRoutesEvent>(_onLoadActiveRoutes);
    on<UpdateRouteStatusEvent>(_onUpdateRouteStatus);
    on<LoadFavoriteRoutesEvent>(_onLoadFavoriteRoutes);
  }

  /// تحميل المسارات
  Future<void> _onLoadRoutes(
    LoadRoutesEvent event,
    Emitter<RoutesState> emit,
  ) async {
    try {
      AppLogger.info('[RoutesBloc] تحميل المسارات للمستخدم: ${event.userId}');
      emit(const RoutesLoading());

      final result = await getUserRoutes(GetUserRoutesParams(userId: event.userId));

      result.fold(
        (failure) {
          AppLogger.error('[RoutesBloc] فشل تحميل المسارات', failure);
          emit(RoutesError(message: failure.message));
        },
        (routes) {
          AppLogger.success('[RoutesBloc] تم تحميل ${routes.length} مسار');
          emit(RoutesLoaded(
            routes: routes,
            filteredRoutes: routes,
          ));
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('[RoutesBloc] خطأ غير متوقع', e, stackTrace);
      emit(const RoutesError(message: 'routesLoadError'));
    }
  }

  /// إنشاء مسار جديد
  Future<void> _onCreateRoute(
    CreateRouteEvent event,
    Emitter<RoutesState> emit,
  ) async {
    try {
      AppLogger.info('[RoutesBloc] إنشاء مسار: ${event.route.name}');

      final result = await createRoute(CreateRouteParams(route: event.route));

      result.fold(
        (failure) {
          AppLogger.error('[RoutesBloc] فشل إنشاء المسار', failure);
          emit(RoutesError(message: failure.message));
        },
        (route) {
          AppLogger.success('[RoutesBloc] تم إنشاء المسار بنجاح');
          
          // حفظ الـ state السابق
          final previousState = state;
          
          // إصدار RouteCreated للـ UI
          emit(RouteCreated(route: route));
          
          // ✅ تحديث القائمة بدلاً من إعادة التحميل
          if (previousState is RoutesLoaded) {
            final updatedRoutes = [...previousState.routes, route];
            emit(previousState.copyWith(
              routes: updatedRoutes,
              filteredRoutes: _applyFilters(
                updatedRoutes,
                previousState.searchQuery,
                previousState.statusFilter,
                previousState.favoriteFilter,
              ),
            ));
          } else {
            // إذا لم يكن هناك state سابق، أعد التحميل
            add(LoadRoutesEvent(userId: route.userId));
          }
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('[RoutesBloc] خطأ غير متوقع', e, stackTrace);
      emit(const RoutesError(message: 'routeCreateError'));
    }
  }

  /// تحديث مسار
  Future<void> _onUpdateRoute(
    UpdateRouteEvent event,
    Emitter<RoutesState> emit,
  ) async {
    try {
      AppLogger.info('[RoutesBloc] تحديث مسار: ${event.route.id}');

      final result = await updateRoute(UpdateRouteParams(route: event.route));

      result.fold(
        (failure) {
          AppLogger.error('[RoutesBloc] فشل تحديث المسار', failure);
          if (state is RoutesLoaded) {
            emit(RoutesOperationError(
              message: failure.message,
              routes: (state as RoutesLoaded).routes,
            ));
          } else {
            emit(RoutesError(message: failure.message));
          }
        },
        (route) {
          AppLogger.success('[RoutesBloc] تم تحديث المسار بنجاح');
          
          // حفظ الـ state السابق
          final previousState = state;
          
          // إصدار RouteUpdated للـ UI
          emit(RouteUpdated(route: route));
          
          // ✅ تحديث القائمة باستخدام previousState
          if (previousState is RoutesLoaded) {
            final updatedRoutes = previousState.routes.map((r) {
              return r.id == route.id ? route : r;
            }).toList();
            
            emit(previousState.copyWith(
              routes: updatedRoutes,
              filteredRoutes: _applyFilters(
                updatedRoutes,
                previousState.searchQuery,
                previousState.statusFilter,
                previousState.favoriteFilter,
              ),
            ));
          }
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('[RoutesBloc] خطأ غير متوقع', e, stackTrace);
      emit(const RoutesError(message: 'routeUpdateError'));
    }
  }

  /// حذف مسار
  Future<void> _onDeleteRoute(
    DeleteRouteEvent event,
    Emitter<RoutesState> emit,
  ) async {
    try {
      AppLogger.info('[RoutesBloc] حذف مسار: ${event.routeId}');

      final result = await deleteRoute(DeleteRouteParams(routeId: event.routeId));

      result.fold(
        (failure) {
          AppLogger.error('[RoutesBloc] فشل حذف المسار', failure);
          if (state is RoutesLoaded) {
            emit(RoutesOperationError(
              message: failure.message,
              routes: (state as RoutesLoaded).routes,
            ));
          } else {
            emit(RoutesError(message: failure.message));
          }
        },
        (_) {
          AppLogger.success('[RoutesBloc] تم حذف المسار بنجاح');
          
          // ✅ حفظ الـ state الحالي قبل emit
          final previousState = state;
          
          // إصدار RouteDeleted للـ UI
          emit(RouteDeleted(routeId: event.routeId));
          
          // ✅ تحديث القائمة باستخدام previousState
          if (previousState is RoutesLoaded) {
            final updatedRoutes = previousState.routes
                .where((r) => r.id != event.routeId)
                .toList();
            
            emit(previousState.copyWith(
              routes: updatedRoutes,
              filteredRoutes: _applyFilters(
                updatedRoutes,
                previousState.searchQuery,
                previousState.statusFilter,
                previousState.favoriteFilter,
              ),
            ));
          } else {
            // إذا لم يكن هناك state سابق، أعد تحميل المسارات
            AppLogger.info('[RoutesBloc] لا يوجد state سابق، إعادة التحميل');
            // يمكن أن نضيف event لإعادة التحميل هنا إذا لزم الأمر
          }
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('[RoutesBloc] خطأ غير متوقع', e, stackTrace);
      emit(const RoutesError(message: 'routeDeleteError'));
    }
  }

  /// تبديل المفضلة
  Future<void> _onToggleFavorite(
    ToggleFavoriteEvent event,
    Emitter<RoutesState> emit,
  ) async {
    try {
      AppLogger.info('[RoutesBloc] تبديل المفضلة: ${event.routeId}');

      final result = await toggleFavorite(ToggleFavoriteParams(routeId: event.routeId));

      result.fold(
        (failure) {
          AppLogger.error('[RoutesBloc] فشل تبديل المفضلة', failure);
          final previousState = state;
          if (previousState is RoutesLoaded) {
            emit(RoutesOperationError(
              message: failure.message,
              routes: previousState.routes,
            ));
          }
        },
        (route) {
          AppLogger.success('[RoutesBloc] تم تبديل المفضلة بنجاح');
          
          // ✅ حفظ الـ state السابق
          final previousState = state;
          
          // ✅ تحديث القائمة باستخدام previousState
          if (previousState is RoutesLoaded) {
            final updatedRoutes = previousState.routes.map((r) {
              return r.id == route.id ? route : r;
            }).toList();
            
            emit(previousState.copyWith(
              routes: updatedRoutes,
              filteredRoutes: _applyFilters(
                updatedRoutes,
                previousState.searchQuery,
                previousState.statusFilter,
                previousState.favoriteFilter,
              ),
            ));
          }
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('[RoutesBloc] خطأ غير متوقع', e, stackTrace);
    }
  }

  /// البحث في المسارات
  Future<void> _onSearchRoutes(
    SearchRoutesEvent event,
    Emitter<RoutesState> emit,
  ) async {
    if (state is! RoutesLoaded) return;

    try {
      final currentState = state as RoutesLoaded;
      
      final filteredRoutes = _applyFilters(
        currentState.routes,
        event.query,
        currentState.statusFilter,
        currentState.favoriteFilter,
      );

      emit(currentState.copyWith(
        filteredRoutes: filteredRoutes,
        searchQuery: event.query.isEmpty ? null : event.query,
      ));
    } catch (e) {
      AppLogger.error('[RoutesBloc] خطأ في البحث', e);
    }
  }

  /// فلترة المسارات
  Future<void> _onFilterRoutes(
    FilterRoutesEvent event,
    Emitter<RoutesState> emit,
  ) async {
    if (state is! RoutesLoaded) return;

    try {
      final currentState = state as RoutesLoaded;
      
      final filteredRoutes = _applyFilters(
        currentState.routes,
        currentState.searchQuery,
        event.status,
        event.isFavorite,
      );

      emit(currentState.copyWith(
        filteredRoutes: filteredRoutes,
        statusFilter: event.status,
        favoriteFilter: event.isFavorite,
      ));
    } catch (e) {
      AppLogger.error('[RoutesBloc] خطأ في الفلترة', e);
    }
  }

  /// إعادة تحميل المسارات
  Future<void> _onRefreshRoutes(
    RefreshRoutesEvent event,
    Emitter<RoutesState> emit,
  ) async {
    add(LoadRoutesEvent(userId: event.userId));
  }

  /// تطبيق الفلاتر
  List<RouteEntity> _applyFilters(
    List<RouteEntity> routes,
    String? searchQuery,
    RouteStatus? status,
    bool? isFavorite,
  ) {
    var filtered = routes;

    // تطبيق البحث
    if (searchQuery != null && searchQuery.isNotEmpty) {
      filtered = filtered.where((route) {
        final nameLower = route.name.toLowerCase();
        final queryLower = searchQuery.toLowerCase();
        final descriptionLower = route.description?.toLowerCase() ?? '';
        
        return nameLower.contains(queryLower) ||
            descriptionLower.contains(queryLower);
      }).toList();
    }

    // تطبيق فلتر الحالة
    if (status != null) {
      filtered = filtered.where((route) => route.status == status).toList();
    }

    // تطبيق فلتر المفضلة
    if (isFavorite != null) {
      filtered = filtered.where((route) => route.isFavorite == isFavorite).toList();
    }

    return filtered;
  }

  /// ✅ مزامنة المسارات
  Future<void> _onSyncRoutes(
    SyncRoutesEvent event,
    Emitter<RoutesState> emit,
  ) async {
    try {
      AppLogger.info('[RoutesBloc] بدء مزامنة المسارات للمستخدم: ${event.userId}');
      
      // إظهار loading indicator
      if (state is RoutesLoaded) {
        emit((state as RoutesLoaded).copyWith(isSyncing: true));
      }

      final result = await syncRoutes(SyncRoutesParams(userId: event.userId));

      result.fold(
        (failure) {
          AppLogger.error('[RoutesBloc] فشلت المزامنة', failure);
          if (state is RoutesLoaded) {
            emit(RoutesOperationError(
              message: 'فشلت المزامنة: ${failure.message}',
              routes: (state as RoutesLoaded).routes,
            ));
          }
        },
        (_) {
          AppLogger.success('[RoutesBloc] تمت المزامنة بنجاح');
          // إعادة تحميل المسارات بعد المزامنة
          add(LoadRoutesEvent(userId: event.userId));
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('[RoutesBloc] خطأ غير متوقع في المزامنة', e, stackTrace);
    }
  }

  /// ✅ تحميل المسارات النشطة
  Future<void> _onLoadActiveRoutes(
    LoadActiveRoutesEvent event,
    Emitter<RoutesState> emit,
  ) async {
    try {
      AppLogger.info('[RoutesBloc] تحميل المسارات النشطة للمستخدم: ${event.userId}');
      emit(const RoutesLoading());

      final result = await getActiveRoutes(GetActiveRoutesParams(userId: event.userId));

      result.fold(
        (failure) {
          AppLogger.error('[RoutesBloc] فشل تحميل المسارات النشطة', failure);
          emit(RoutesError(message: failure.message));
        },
        (routes) {
          AppLogger.success('[RoutesBloc] تم تحميل ${routes.length} مسار نشط');
          emit(RoutesLoaded(
            routes: routes,
            filteredRoutes: routes,
          ));
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('[RoutesBloc] خطأ غير متوقع', e, stackTrace);
      emit(const RoutesError(message: 'activeRoutesLoadError'));
    }
  }

  /// ✅ تحديث حالة المسار
  Future<void> _onUpdateRouteStatus(
    UpdateRouteStatusEvent event,
    Emitter<RoutesState> emit,
  ) async {
    try {
      AppLogger.info('[RoutesBloc] تحديث حالة المسار: ${event.routeId} إلى ${event.status}');

      final result = await updateRouteStatus(
        UpdateRouteStatusParams(routeId: event.routeId, status: event.status),
      );

      result.fold(
        (failure) {
          AppLogger.error('[RoutesBloc] فشل تحديث الحالة', failure);
          if (state is RoutesLoaded) {
            emit(RoutesOperationError(
              message: failure.message,
              routes: (state as RoutesLoaded).routes,
            ));
          } else {
            emit(RoutesError(message: failure.message));
          }
        },
        (route) {
          AppLogger.success('[RoutesBloc] تم تحديث الحالة بنجاح');
          
          final previousState = state;
          emit(RouteUpdated(route: route));
          
          if (previousState is RoutesLoaded) {
            final updatedRoutes = previousState.routes.map((r) {
              return r.id == route.id ? route : r;
            }).toList();
            
            emit(previousState.copyWith(
              routes: updatedRoutes,
              filteredRoutes: _applyFilters(
                updatedRoutes,
                previousState.searchQuery,
                previousState.statusFilter,
                previousState.favoriteFilter,
              ),
            ));
          }
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('[RoutesBloc] خطأ غير متوقع', e, stackTrace);
      emit(const RoutesError(message: 'routeStatusUpdateError'));
    }
  }

  /// ✅ تحميل المسارات المفضلة
  Future<void> _onLoadFavoriteRoutes(
    LoadFavoriteRoutesEvent event,
    Emitter<RoutesState> emit,
  ) async {
    try {
      AppLogger.info('[RoutesBloc] تحميل المسارات المفضلة للمستخدم: ${event.userId}');
      emit(const RoutesLoading());

      final result = await getFavoriteRoutes(GetFavoriteRoutesParams(userId: event.userId));

      result.fold(
        (failure) {
          AppLogger.error('[RoutesBloc] فشل تحميل المفضلة', failure);
          emit(RoutesError(message: failure.message));
        },
        (routes) {
          AppLogger.success('[RoutesBloc] تم تحميل ${routes.length} مسار مفضل');
          emit(RoutesLoaded(
            routes: routes,
            filteredRoutes: routes,
          ));
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('[RoutesBloc] خطأ غير متوقع', e, stackTrace);
      emit(const RoutesError(message: 'favoritesLoadError'));
    }
  }
}
