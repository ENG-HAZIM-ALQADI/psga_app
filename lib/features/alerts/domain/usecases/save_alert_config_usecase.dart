import 'package:dartz/dartz.dart';
import 'package:psga_app/core/errors/failures.dart';
import 'package:psga_app/core/usecases/usecase.dart';
import 'package:psga_app/core/utils/logger.dart';
import 'package:psga_app/features/alerts/domain/entities/alert_config_entity.dart';
import 'package:psga_app/features/alerts/domain/repositories/alerts_repository.dart';

/// حالة استخدام: حفظ/تحديث إعدادات التنبيهات
/// 
/// SOLID Principles:
/// - Single Responsibility: مسؤول فقط عن حفظ الإعدادات
/// - Dependency Inversion: يعتمد على AlertsRepository (abstract)
/// 
/// يتحقق من صحة البيانات قبل الحفظ
class SaveAlertConfigUseCase 
    implements UseCase<AlertConfigEntity, SaveAlertConfigParams> {
  final AlertsRepository repository;

  SaveAlertConfigUseCase(this.repository);

  @override
  Future<Either<Failure, AlertConfigEntity>> call(SaveAlertConfigParams params) async {
    try {
      AppLogger.info('[SaveAlertConfig] جاري حفظ الإعدادات للمستخدم: ${params.config.userId}');

      // التحقق من صحة البيانات قبل الحفظ
      final validation = _validateConfig(params.config);
      if (validation != null) {
        AppLogger.error('[SaveAlertConfig] فشل التحقق', validation);
        return Left(ValidationFailure(validation));
      }

      // حفظ الإعدادات
      final result = await repository.updateAlertConfig(params.config);

      result.fold(
        (failure) => AppLogger.error('[SaveAlertConfig] فشل الحفظ', failure.message),
        (config) => AppLogger.success('[SaveAlertConfig] تم حفظ الإعدادات بنجاح'),
      );

      return result;
    } catch (e, stackTrace) {
      AppLogger.error('[SaveAlertConfig] خطأ غير متوقع', e, stackTrace);
      return Left(ServerFailure('فشل حفظ الإعدادات: ${e.toString()}'));
    }
  }

  /// التحقق من صحة الإعدادات
  /// Returns: رسالة الخطأ أو null إذا كانت صحيحة
  String? _validateConfig(AlertConfigEntity config) {
    // التحقق من userId
    if (config.userId.isEmpty) {
      return 'userId cannot be empty';
    }

    // التحقق من مدة العد التنازلي
    if (config.countdownDuration.inSeconds < 10) {
      return 'Countdown must be at least 10 seconds';
    }

    if (config.countdownDuration.inSeconds > 60) {
      return 'Countdown must be at most 60 seconds';
    }

    // Note: deviationThreshold validation moved to TripSettings
    // as it's a trip setting, not an alert setting

    // التحقق من ساعات الهدوء
    if (config.enableQuietHours) {
      if (config.quietHoursStart == null || config.quietHoursEnd == null) {
        return 'Quiet hours start and end must be set when enabled';
      }
    }

    // التحقق من وجود إعدادات لكل نوع تنبيه على الأقل
    if (config.typeConfigs.isEmpty) {
      return 'At least one alert type config must be provided';
    }

    return null; // صالح
  }
}

/// معاملات حفظ إعدادات التنبيهات
class SaveAlertConfigParams {
  final AlertConfigEntity config;

  const SaveAlertConfigParams({required this.config});
}
