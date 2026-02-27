import 'package:dartz/dartz.dart';
import 'package:psga_app/core/errors/failures.dart';
import 'package:psga_app/core/usecases/usecase.dart';
import 'package:psga_app/core/utils/logger.dart';
import 'package:psga_app/features/routes/domain/entities/route.dart';
import 'package:psga_app/features/routes/domain/repositories/routes_repository.dart';
import 'package:psga_app/core/services/route_calculator_service.dart';

/// UseCase لإنشاء مسار جديد
/// يتبع Single Responsibility: إنشاء وحفظ مسار جديد فقط
class CreateRouteUseCase implements UseCase<RouteEntity, CreateRouteParams> {
  final RoutesRepository repository;
  final RouteCalculatorService _calculatorService;

  CreateRouteUseCase(
    this.repository, {
    RouteCalculatorService? calculatorService,
  }) : _calculatorService = calculatorService ?? RouteCalculatorService.instance;

  @override
  Future<Either<Failure, RouteEntity>> call(CreateRouteParams params) async {
    try {
      AppLogger.info('[CreateRouteUseCase] إنشاء مسار جديد: ${params.route.name}');

      // ✅ التحقق الشامل من صحة المدخلات
      final validationError = _validateRoute(params.route);
      if (validationError != null) {
        AppLogger.error('[CreateRouteUseCase] خطأ في التحقق: $validationError');
        return Left(ValidationFailure(validationError));
      }

      // حساب المسافة والوقت تلقائياً إذا لم تكن محسوبة
      RouteEntity routeToCreate = params.route;
      
      if (params.autoCalculate && 
          (params.route.estimatedDistance == null || 
           params.route.estimatedDuration == null)) {
        AppLogger.info('[CreateRouteUseCase] حساب المسافة والوقت تلقائياً');
        
        try {
          routeToCreate = await _calculatorService.updateRouteWithCalculations(
            params.route,
            useActualRoutes: params.useActualRoutes,
          );
          
          AppLogger.success(
            '[CreateRouteUseCase] تم حساب المسار: '
            '${_calculatorService.formatDistance(routeToCreate.estimatedDistance ?? 0)}, '
            '${_calculatorService.formatDuration(routeToCreate.estimatedDuration ?? 0)}',
          );
        } catch (e) {
          AppLogger.warning('[CreateRouteUseCase] فشل الحساب التلقائي، استمرار بدونه', e);
          // نستمر حتى لو فشل الحساب
        }
      }

      // إنشاء المسار
      final result = await repository.createRoute(routeToCreate);

      result.fold(
        (failure) {
          AppLogger.error('[CreateRouteUseCase] فشل إنشاء المسار', failure);
        },
        (route) {
          AppLogger.success('[CreateRouteUseCase] تم إنشاء المسار بنجاح: ${route.id}');
        },
      );

      return result;
    } catch (e, stackTrace) {
      AppLogger.error('[CreateRouteUseCase] خطأ غير متوقع', e, stackTrace);
      return Left(UnknownFailure('فشل إنشاء المسار: ${e.toString()}'));
    }
  }

  /// ✅ التحقق من صحة المسار
  String? _validateRoute(RouteEntity route) {
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

/// معاملات إنشاء مسار
class CreateRouteParams {
  final RouteEntity route;
  final bool autoCalculate; // حساب المسافة والوقت تلقائياً
  final bool useActualRoutes; // استخدام Google Directions API للحساب الدقيق

  const CreateRouteParams({
    required this.route,
    this.autoCalculate = true,
    this.useActualRoutes = false,
  });
}
