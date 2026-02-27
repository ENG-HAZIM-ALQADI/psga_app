import 'package:dartz/dartz.dart';
import 'package:psga_app/core/errors/failures.dart';
import 'package:psga_app/core/usecases/usecase.dart';
import 'package:psga_app/core/utils/logger.dart';
import 'package:psga_app/features/routes/domain/entities/route.dart';
import 'package:psga_app/features/routes/domain/repositories/routes_repository.dart';

// ==================== Get Route ====================

/// UseCase للحصول على مسار محدد بمعرفه
/// يتبع Single Responsibility: جلب مسار واحد فقط
class GetRouteUseCase implements UseCase<RouteEntity, GetRouteParams> {
  final RoutesRepository repository;
  GetRouteUseCase(this.repository);

  @override
  Future<Either<Failure, RouteEntity>> call(GetRouteParams params) async {
    try {
      AppLogger.info('[GetRouteUseCase] جاري الحصول على المسار: ${params.routeId}');
      
      // ✅ التحقق من صحة المدخلات
      if (params.routeId.trim().isEmpty) {
        AppLogger.error('[GetRouteUseCase] معرف المسار فارغ');
        return const Left(ValidationFailure('معرف المسار مطلوب'));
      }
      
      final result = await repository.getRoute(params.routeId);
      
      result.fold(
        (failure) {
          AppLogger.error('[GetRouteUseCase] فشل الحصول على المسار', failure);
        },
        (route) {
          AppLogger.success('[GetRouteUseCase] تم جلب المسار: ${route.name}');
        },
      );
      
      return result;
    } catch (e, stackTrace) {
      AppLogger.error('[GetRouteUseCase] خطأ غير متوقع', e, stackTrace);
      return Left(UnknownFailure('فشل الحصول على المسار: ${e.toString()}'));
    }
  }
}

class GetRouteParams {
  final String routeId;
  const GetRouteParams({required this.routeId});
}

// ==================== Update Route ====================

/// UseCase لتحديث مسار موجود
/// يتبع Single Responsibility: تحديث بيانات المسار فقط
class UpdateRouteUseCase implements UseCase<RouteEntity, UpdateRouteParams> {
  final RoutesRepository repository;
  UpdateRouteUseCase(this.repository);

  @override
  Future<Either<Failure, RouteEntity>> call(UpdateRouteParams params) async {
    try {
      AppLogger.info('[UpdateRouteUseCase] تحديث المسار: ${params.route.id}');
      
      // ✅ التحقق الشامل من صحة المدخلات
      final validationError = _validateRoute(params.route);
      if (validationError != null) {
        AppLogger.error('[UpdateRouteUseCase] خطأ في التحقق: $validationError');
        return Left(ValidationFailure(validationError));
      }
      
      final result = await repository.updateRoute(params.route);
      
      result.fold(
        (failure) {
          AppLogger.error('[UpdateRouteUseCase] فشل تحديث المسار', failure);
        },
        (route) {
          AppLogger.success('[UpdateRouteUseCase] تم تحديث المسار بنجاح: ${route.name}');
        },
      );
      
      return result;
    } catch (e, stackTrace) {
      AppLogger.error('[UpdateRouteUseCase] خطأ غير متوقع', e, stackTrace);
      return Left(UnknownFailure('فشل تحديث المسار: ${e.toString()}'));
    }
  }

  /// ✅ التحقق من صحة المسار
  String? _validateRoute(RouteEntity route) {
    if (route.id.trim().isEmpty) {
      return 'معرف المسار مطلوب';
    }
    
    if (route.name.trim().isEmpty) {
      return 'اسم المسار مطلوب';
    }
    
    if (route.name.length > 100) {
      return 'اسم المسار يجب ألا يتجاوز 100 حرف';
    }

    if (route.userId.trim().isEmpty) {
      return 'معرف المستخدم مطلوب';
    }

    if (route.waypoints.isEmpty) {
      return 'المسار يجب أن يحتوي على نقطة واحدة على الأقل';
    }

    if (route.waypoints.length < 2) {
      return 'المسار يجب أن يحتوي على نقطتين على الأقل';
    }

    return null;
  }
}

class UpdateRouteParams {
  final RouteEntity route;
  const UpdateRouteParams({required this.route});
}

// ==================== Delete Route ====================

/// UseCase لحذف مسار
/// يتبع Single Responsibility: حذف مسار فقط
class DeleteRouteUseCase implements UseCase<void, DeleteRouteParams> {
  final RoutesRepository repository;
  DeleteRouteUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(DeleteRouteParams params) async {
    try {
      AppLogger.info('[DeleteRouteUseCase] حذف المسار: ${params.routeId}');
      
      // ✅ التحقق من صحة المدخلات
      if (params.routeId.trim().isEmpty) {
        AppLogger.error('[DeleteRouteUseCase] معرف المسار فارغ');
        return const Left(ValidationFailure('معرف المسار مطلوب'));
      }
      
      final result = await repository.deleteRoute(params.routeId);
      
      result.fold(
        (failure) {
          AppLogger.error('[DeleteRouteUseCase] فشل حذف المسار', failure);
        },
        (_) {
          AppLogger.success('[DeleteRouteUseCase] تم حذف المسار بنجاح');
        },
      );
      
      return result;
    } catch (e, stackTrace) {
      AppLogger.error('[DeleteRouteUseCase] خطأ غير متوقع', e, stackTrace);
      return Left(UnknownFailure('فشل حذف المسار: ${e.toString()}'));
    }
  }
}

class DeleteRouteParams {
  final String routeId;
  const DeleteRouteParams({required this.routeId});
}

// ==================== Toggle Favorite ====================

/// UseCase لتبديل حالة المفضلة للمسار
/// يتبع Single Responsibility: تبديل المفضلة فقط
class ToggleFavoriteUseCase
    implements UseCase<RouteEntity, ToggleFavoriteParams> {
  final RoutesRepository repository;
  ToggleFavoriteUseCase(this.repository);

  @override
  Future<Either<Failure, RouteEntity>> call(ToggleFavoriteParams params) async {
    try {
      AppLogger.info('[ToggleFavoriteUseCase] تبديل المفضلة: ${params.routeId}');
      
      // ✅ التحقق من صحة المدخلات
      if (params.routeId.trim().isEmpty) {
        AppLogger.error('[ToggleFavoriteUseCase] معرف المسار فارغ');
        return const Left(ValidationFailure('معرف المسار مطلوب'));
      }
      
      final result = await repository.toggleFavorite(params.routeId);
      
      result.fold(
        (failure) {
          AppLogger.error('[ToggleFavoriteUseCase] فشل تبديل المفضلة', failure);
        },
        (route) {
          final status = route.isFavorite ? 'مفضل' : 'غير مفضل';
          AppLogger.success('[ToggleFavoriteUseCase] تم التبديل: $status');
        },
      );
      
      return result;
    } catch (e, stackTrace) {
      AppLogger.error('[ToggleFavoriteUseCase] خطأ غير متوقع', e, stackTrace);
      return Left(UnknownFailure('فشل تحديث المفضلة: ${e.toString()}'));
    }
  }
}

class ToggleFavoriteParams {
  final String routeId;
  const ToggleFavoriteParams({required this.routeId});
}

// ==================== Get Favorite Routes ====================

/// UseCase للحصول على المسارات المفضلة فقط
/// يتبع Single Responsibility: جلب المسارات المفضلة
class GetFavoriteRoutesUseCase
    implements UseCase<List<RouteEntity>, GetFavoriteRoutesParams> {
  final RoutesRepository repository;
  GetFavoriteRoutesUseCase(this.repository);

  @override
  Future<Either<Failure, List<RouteEntity>>> call(
    GetFavoriteRoutesParams params,
  ) async {
    try {
      AppLogger.info('[GetFavoriteRoutesUseCase] جاري الحصول على المفضلة للمستخدم: ${params.userId}');
      
      // ✅ التحقق من صحة المدخلات
      if (params.userId.trim().isEmpty) {
        AppLogger.error('[GetFavoriteRoutesUseCase] معرف المستخدم فارغ');
        return const Left(ValidationFailure('معرف المستخدم مطلوب'));
      }
      
      final result = await repository.getFavoriteRoutes(params.userId);
      
      result.fold(
        (failure) {
          AppLogger.error('[GetFavoriteRoutesUseCase] فشل الحصول على المفضلة', failure);
        },
        (routes) {
          AppLogger.success('[GetFavoriteRoutesUseCase] تم جلب ${routes.length} مسار مفضل');
        },
      );
      
      return result;
    } catch (e, stackTrace) {
      AppLogger.error('[GetFavoriteRoutesUseCase] خطأ غير متوقع', e, stackTrace);
      return Left(UnknownFailure('فشل الحصول على المفضلة: ${e.toString()}'));
    }
  }
}

class GetFavoriteRoutesParams {
  final String userId;
  const GetFavoriteRoutesParams({required this.userId});
}

// ==================== Search Routes ====================

/// UseCase للبحث في المسارات
/// يتبع Single Responsibility: البحث في مسارات المستخدم فقط
class SearchRoutesUseCase
    implements UseCase<List<RouteEntity>, SearchRoutesParams> {
  final RoutesRepository repository;
  SearchRoutesUseCase(this.repository);

  @override
  Future<Either<Failure, List<RouteEntity>>> call(
    SearchRoutesParams params,
  ) async {
    try {
      AppLogger.info('[SearchRoutesUseCase] البحث عن: ${params.query} للمستخدم: ${params.userId}');
      
      // ✅ التحقق من صحة المدخلات
      if (params.userId.trim().isEmpty) {
        AppLogger.error('[SearchRoutesUseCase] معرف المستخدم فارغ');
        return const Left(ValidationFailure('معرف المستخدم مطلوب'));
      }
      
      if (params.query.trim().isEmpty) {
        AppLogger.warning('[SearchRoutesUseCase] نص البحث فارغ - إرجاع قائمة فارغة');
        return const Right([]);
      }
      
      // ✅ التحقق من طول نص البحث
      if (params.query.length > 100) {
        AppLogger.error('[SearchRoutesUseCase] نص البحث طويل جداً');
        return const Left(ValidationFailure('نص البحث يجب ألا يتجاوز 100 حرف'));
      }
      
      final result = await repository.searchRoutes(params.userId, params.query);
      
      result.fold(
        (failure) {
          AppLogger.error('[SearchRoutesUseCase] فشل البحث', failure);
        },
        (routes) {
          AppLogger.success('[SearchRoutesUseCase] تم العثور على ${routes.length} نتيجة');
        },
      );
      
      return result;
    } catch (e, stackTrace) {
      AppLogger.error('[SearchRoutesUseCase] خطأ غير متوقع', e, stackTrace);
      return Left(UnknownFailure('فشل البحث: ${e.toString()}'));
    }
  }
}

class SearchRoutesParams {
  final String userId;
  final String query;
  const SearchRoutesParams({required this.userId, required this.query});
}
