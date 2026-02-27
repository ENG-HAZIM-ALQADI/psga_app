import 'package:equatable/equatable.dart';
import 'package:psga_app/features/routes/domain/entities/route.dart';

/// Base class لجميع Routes Events
sealed class RoutesEvent extends Equatable {
  const RoutesEvent();

  @override
  List<Object?> get props => [];
}

/// تحميل المسارات
class LoadRoutesEvent extends RoutesEvent {
  final String userId;

  const LoadRoutesEvent({required this.userId});

  @override
  List<Object?> get props => [userId];
}

/// إنشاء مسار جديد
class CreateRouteEvent extends RoutesEvent {
  final RouteEntity route;

  const CreateRouteEvent({required this.route});

  @override
  List<Object?> get props => [route];
}

/// تحديث مسار
class UpdateRouteEvent extends RoutesEvent {
  final RouteEntity route;

  const UpdateRouteEvent({required this.route});

  @override
  List<Object?> get props => [route];
}

/// حذف مسار
class DeleteRouteEvent extends RoutesEvent {
  final String routeId;

  const DeleteRouteEvent({required this.routeId});

  @override
  List<Object?> get props => [routeId];
}

/// تبديل المفضلة
class ToggleFavoriteEvent extends RoutesEvent {
  final String routeId;

  const ToggleFavoriteEvent({required this.routeId});

  @override
  List<Object?> get props => [routeId];
}

/// البحث في المسارات
class SearchRoutesEvent extends RoutesEvent {
  final String query;

  const SearchRoutesEvent({required this.query});

  @override
  List<Object?> get props => [query];
}

/// فلترة المسارات
class FilterRoutesEvent extends RoutesEvent {
  final RouteStatus? status;
  final bool? isFavorite;

  const FilterRoutesEvent({
    this.status,
    this.isFavorite,
  });

  @override
  List<Object?> get props => [status, isFavorite];
}

/// إعادة تحميل المسارات
class RefreshRoutesEvent extends RoutesEvent {
  final String userId;

  const RefreshRoutesEvent({required this.userId});

  @override
  List<Object?> get props => [userId];
}

/// مزامنة المسارات
class SyncRoutesEvent extends RoutesEvent {
  final String userId;

  const SyncRoutesEvent({required this.userId});

  @override
  List<Object?> get props => [userId];
}

/// تحميل المسارات النشطة فقط
class LoadActiveRoutesEvent extends RoutesEvent {
  final String userId;

  const LoadActiveRoutesEvent({required this.userId});

  @override
  List<Object?> get props => [userId];
}

/// تحديث حالة المسار
class UpdateRouteStatusEvent extends RoutesEvent {
  final String routeId;
  final RouteStatus status;

  const UpdateRouteStatusEvent({
    required this.routeId,
    required this.status,
  });

  @override
  List<Object?> get props => [routeId, status];
}

/// تحميل المسارات المفضلة فقط
class LoadFavoriteRoutesEvent extends RoutesEvent {
  final String userId;

  const LoadFavoriteRoutesEvent({required this.userId});

  @override
  List<Object?> get props => [userId];
}
