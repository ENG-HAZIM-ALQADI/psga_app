import 'package:equatable/equatable.dart';
import 'package:psga_app/features/routes/domain/entities/route.dart';

/// Base class لجميع Routes States
sealed class RoutesState extends Equatable {
  const RoutesState();

  @override
  List<Object?> get props => [];
}

/// الحالة الأولية
class RoutesInitial extends RoutesState {
  const RoutesInitial();
}

/// جاري التحميل
class RoutesLoading extends RoutesState {
  const RoutesLoading();
}

/// تم التحميل بنجاح
class RoutesLoaded extends RoutesState {
  final List<RouteEntity> routes;
  final List<RouteEntity> filteredRoutes;
  final String? searchQuery;
  final RouteStatus? statusFilter;
  final bool? favoriteFilter;
  final bool isSyncing; // ✅ للإشارة إلى أن المزامنة جارية

  const RoutesLoaded({
    required this.routes,
    required this.filteredRoutes,
    this.searchQuery,
    this.statusFilter,
    this.favoriteFilter,
    this.isSyncing = false,
  });

  @override
  List<Object?> get props => [
        routes,
        filteredRoutes,
        searchQuery,
        statusFilter,
        favoriteFilter,
        isSyncing,
      ];

  /// نسخ مع تعديلات
  RoutesLoaded copyWith({
    List<RouteEntity>? routes,
    List<RouteEntity>? filteredRoutes,
    String? searchQuery,
    RouteStatus? statusFilter,
    bool? favoriteFilter,
    bool? isSyncing,
  }) {
    return RoutesLoaded(
      routes: routes ?? this.routes,
      filteredRoutes: filteredRoutes ?? this.filteredRoutes,
      searchQuery: searchQuery ?? this.searchQuery,
      statusFilter: statusFilter ?? this.statusFilter,
      favoriteFilter: favoriteFilter ?? this.favoriteFilter,
      isSyncing: isSyncing ?? this.isSyncing,
    );
  }

  /// عدد المسارات
  int get totalCount => routes.length;

  /// عدد المسارات المفضلة
  int get favoriteCount => routes.where((r) => r.isFavorite).length;

  /// عدد المسارات النشطة
  int get activeCount => routes.where((r) => r.status == RouteStatus.active).length;
}

/// تم إنشاء مسار
class RouteCreated extends RoutesState {
  final RouteEntity route;

  const RouteCreated({required this.route});

  @override
  List<Object?> get props => [route];
}

/// تم تحديث مسار
class RouteUpdated extends RoutesState {
  final RouteEntity route;

  const RouteUpdated({required this.route});

  @override
  List<Object?> get props => [route];
}

/// تم حذف مسار
class RouteDeleted extends RoutesState {
  final String routeId;

  const RouteDeleted({required this.routeId});

  @override
  List<Object?> get props => [routeId];
}

/// جاري المزامنة
class RoutesSyncing extends RoutesState {
  const RoutesSyncing();
}

/// تمت المزامنة
class RoutesSynced extends RoutesState {
  final int syncedCount;

  const RoutesSynced({required this.syncedCount});

  @override
  List<Object?> get props => [syncedCount];
}

/// خطأ
class RoutesError extends RoutesState {
  final String message;
  final String? errorCode;

  const RoutesError({
    required this.message,
    this.errorCode,
  });

  @override
  List<Object?> get props => [message, errorCode];
}

/// خطأ في عملية معينة (لا يؤثر على القائمة)
class RoutesOperationError extends RoutesState {
  final String message;
  final List<RouteEntity> routes;

  const RoutesOperationError({
    required this.message,
    required this.routes,
  });

  @override
  List<Object?> get props => [message, routes];
}
