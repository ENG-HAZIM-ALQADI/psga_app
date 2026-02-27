import 'package:dartz/dartz.dart';
import 'package:psga_app/core/errors/failures.dart';
import 'package:psga_app/features/alerts/domain/entities/alert_config_entity.dart';
import 'package:psga_app/features/alerts/domain/entities/alert_entity.dart';
import 'package:psga_app/features/alerts/domain/entities/contact_entity.dart';
import 'package:psga_app/features/routes/domain/entities/location.dart';

/// مستودع التنبيهات
abstract class AlertsRepository {
  // ========== Alert Management ==========
  
  /// إطلاق تنبيه
  Future<Either<Failure, AlertEntity>> triggerAlert({
    required String userId,
    required AlertType type,
    required String title,
    required String message,
    AlertSeverity? severity,
    String? tripId,
    Location? location,
    Map<String, dynamic>? metadata,
  });

  /// الإقرار بتنبيه
  Future<Either<Failure, AlertEntity>> acknowledgeAlert({
    required String alertId,
    required String userId,
  });

  /// تصعيد تنبيه
  Future<Either<Failure, AlertEntity>> escalateAlert({
    required String alertId,
    AlertSeverity? newSeverity,
  });

  /// حل تنبيه
  Future<Either<Failure, AlertEntity>> resolveAlert({
    required String alertId,
    String? note,
  });

  /// تجاهل تنبيه
  Future<Either<Failure, AlertEntity>> ignoreAlert(String alertId);

  /// إرسال SOS
  Future<Either<Failure, AlertEntity>> sendSOS({
    required String userId,
    required Location location,
    String? message,
  });

  /// الحصول على التنبيهات النشطة
  Future<Either<Failure, List<AlertEntity>>> getActiveAlerts(String userId);

  /// الحصول على سجل التنبيهات
  Future<Either<Failure, List<AlertEntity>>> getAlertHistory({
    required String userId,
    DateTime? startDate,
    DateTime? endDate,
    AlertType? type,
    AlertSeverity? severity,
    int? limit,
  });

  /// الحصول على تنبيه بالمعرف
  Future<Either<Failure, AlertEntity>> getAlertById(String alertId);

  /// حذف تنبيه
  Future<Either<Failure, void>> deleteAlert(String alertId);

  // ========== Contact Management ==========
  
  /// إضافة جهة اتصال
  Future<Either<Failure, ContactEntity>> addContact(ContactEntity contact);

  /// تحديث جهة اتصال
  Future<Either<Failure, ContactEntity>> updateContact(ContactEntity contact);

  /// حذف جهة اتصال
  Future<Either<Failure, void>> deleteContact(String contactId);

  /// الحصول على جهات الاتصال
  Future<Either<Failure, List<ContactEntity>>> getContacts(String userId);

  /// الحصول على جهات اتصال الطوارئ
  Future<Either<Failure, List<ContactEntity>>> getEmergencyContacts(String userId);

  /// تعيين جهة اتصال كأساسية
  Future<Either<Failure, ContactEntity>> setPrimaryContact({
    required String contactId,
    required String userId,
  });

  // ========== Alert Config Management ==========
  
  /// الحصول على إعدادات التنبيهات
  Future<Either<Failure, AlertConfigEntity>> getAlertConfig(String userId);

  /// تحديث إعدادات التنبيهات
  Future<Either<Failure, AlertConfigEntity>> updateAlertConfig(AlertConfigEntity config);

  /// تحديث إعدادات نوع تنبيه
  Future<Either<Failure, AlertConfigEntity>> updateAlertTypeConfig({
    required String userId,
    required AlertTypeConfig typeConfig,
  });
}
