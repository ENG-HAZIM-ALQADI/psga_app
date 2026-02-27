import 'package:dartz/dartz.dart';
import 'package:psga_app/core/errors/failures.dart';
import 'package:psga_app/core/usecases/usecase.dart';
import 'package:psga_app/core/utils/logger.dart';
import 'package:psga_app/features/alerts/domain/entities/alert_config_entity.dart';
import 'package:psga_app/features/alerts/domain/repositories/alerts_repository.dart';

/// حالة استخدام: جلب إعدادات التنبيهات
/// 
/// Single Responsibility: مسؤول فقط عن جلب إعدادات التنبيهات للمستخدم
class GetAlertConfigUseCase implements UseCase<AlertConfigEntity, String> {
  final AlertsRepository repository;

  GetAlertConfigUseCase(this.repository);

  @override
  Future<Either<Failure, AlertConfigEntity>> call(String userId) async {
    try {
      AppLogger.info('[GetAlertConfigUseCase] جاري جلب إعدادات التنبيهات للمستخدم: $userId');
      
      final result = await repository.getAlertConfig(userId);
      
      result.fold(
        (failure) => AppLogger.error('[GetAlertConfigUseCase] فشل جلب إعدادات التنبيهات: ${failure.message}'),
        (config) => AppLogger.success('[GetAlertConfigUseCase] تم جلب إعدادات التنبيهات بنجاح'),
      );
      
      return result;
    } catch (e, stackTrace) {
      AppLogger.error('[GetAlertConfigUseCase] خطأ غير متوقع في جلب الإعدادات', e, stackTrace);
      return Left(ServerFailure('فشل جلب إعدادات التنبيهات: ${e.toString()}'));
    }
  }
}

/// حالة استخدام: تحديث إعدادات التنبيهات
/// 
/// Single Responsibility: مسؤول فقط عن تحديث إعدادات التنبيهات
class UpdateAlertConfigUseCase implements UseCase<AlertConfigEntity, AlertConfigEntity> {
  final AlertsRepository repository;

  UpdateAlertConfigUseCase(this.repository);

  @override
  Future<Either<Failure, AlertConfigEntity>> call(AlertConfigEntity config) async {
    try {
      AppLogger.info('[UpdateAlertConfigUseCase] جاري تحديث إعدادات التنبيهات');
      
      final result = await repository.updateAlertConfig(config);
      
      result.fold(
        (failure) => AppLogger.error('[UpdateAlertConfigUseCase] فشل تحديث الإعدادات: ${failure.message}'),
        (updatedConfig) => AppLogger.success('[UpdateAlertConfigUseCase] تم تحديث الإعدادات بنجاح'),
      );
      
      return result;
    } catch (e, stackTrace) {
      AppLogger.error('[UpdateAlertConfigUseCase] خطأ غير متوقع في تحديث الإعدادات', e, stackTrace);
      return Left(ServerFailure('فشل تحديث إعدادات التنبيهات: ${e.toString()}'));
    }
  }
}
