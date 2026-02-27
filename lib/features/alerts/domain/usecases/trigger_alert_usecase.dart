import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:psga_app/core/errors/failures.dart';
import 'package:psga_app/core/usecases/usecase.dart';
import 'package:psga_app/core/utils/logger.dart';
import 'package:psga_app/features/alerts/domain/entities/alert_entity.dart';
import 'package:psga_app/features/alerts/domain/repositories/alerts_repository.dart';
import 'package:psga_app/features/routes/domain/entities/location.dart';
import 'package:psga_app/core/services/sms_service.dart';
import 'package:psga_app/core/services/fcm_service.dart';

class TriggerAlertParams extends Equatable {
  final String userId;
  final AlertType type;
  final String title;
  final String message;
  final AlertSeverity? severity;
  final String? tripId;
  final Location? location;
  final Map<String, dynamic>? metadata;

  const TriggerAlertParams({
    required this.userId,
    required this.type,
    required this.title,
    required this.message,
    this.severity,
    this.tripId,
    this.location,
    this.metadata,
  });

  @override
  List<Object?> get props => [userId, type, title, message, severity, tripId, location, metadata];
}

/// UseCase لإطلاق تنبيه مع التصعيد التلقائي لجهات الطوارئ
class TriggerAlertUseCase implements UseCase<AlertEntity, TriggerAlertParams> {
  final AlertsRepository repository;
  final SMSService? smsService;
  final FCMService? fcmService;

  TriggerAlertUseCase(
    this.repository, {
    this.smsService,
    this.fcmService,
  });

  @override
  Future<Either<Failure, AlertEntity>> call(TriggerAlertParams params) async {
    try {
      AppLogger.start('[TriggerAlertUseCase] إطلاق تنبيه: ${params.type.name}');

      // 1. إنشاء التنبيه
      final alertResult = await repository.triggerAlert(
        userId: params.userId,
        type: params.type,
        title: params.title,
        message: params.message,
        severity: params.severity,
        tripId: params.tripId,
        location: params.location,
        metadata: params.metadata,
      );

      return alertResult.fold(
        (failure) => Left(failure),
        (alert) async {
          AppLogger.info('[TriggerAlertUseCase] تم إنشاء التنبيه: ${alert.id}');

          // 2. التصعيد التلقائي للتنبيهات عالية الخطورة
          if (alert.severity == AlertSeverity.high || alert.severity == AlertSeverity.critical) {
            AppLogger.warning('[TriggerAlertUseCase] تنبيه عالي الخطورة - بدء التصعيد');
            
            final contactsResult = await repository.getEmergencyContacts(params.userId);

            await contactsResult.fold(
              (failure) {
                AppLogger.error('[TriggerAlertUseCase] فشل جلب جهات الاتصال', failure.message);
              },
              (contacts) async {
                if (contacts.isEmpty) {
                  AppLogger.warning('[TriggerAlertUseCase] لا توجد جهات اتصال طوارئ');
                  return;
                }

                AppLogger.info('[TriggerAlertUseCase] جهات اتصال طوارئ: ${contacts.length}');

                // 3. إرسال للتنبيهات الحرجة فقط أو حسب الإعدادات
                if (alert.severity == AlertSeverity.critical) {
                  // SMS لجميع جهات الاتصال الطوارئ
                  if (smsService != null) {
                    try {
                      await smsService!.sendDeviationAlert(
                        alert: alert,
                        contacts: contacts,
                      );
                      AppLogger.success('[TriggerAlertUseCase] تم إرسال SMS لـ ${contacts.length} جهة');
                    } catch (e) {
                      AppLogger.error('[TriggerAlertUseCase] فشل إرسال SMS', e);
                    }
                  }

                  // FCM للجهات التي لديها tokens
                  if (fcmService != null) {
                    try {
                      final contactsWithTokens = contacts.where((c) => c.fcmToken != null).toList();
                      
                      if (contactsWithTokens.isNotEmpty && params.location != null) {
                        await fcmService!.sendSOSAlert(
                          title: alert.title,
                          message: alert.message,
                          location: {
                            'latitude': params.location!.latitude,
                            'longitude': params.location!.longitude,
                            'timestamp': params.location!.timestamp.toIso8601String(),
                          },
                        );
                        AppLogger.success('[TriggerAlertUseCase] تم إرسال FCM لـ ${contactsWithTokens.length} جهة');
                      }
                    } catch (e) {
                      AppLogger.error('[TriggerAlertUseCase] فشل إرسال FCM', e);
                    }
                  }
                }
              },
            );
          }

          AppLogger.success('[TriggerAlertUseCase] اكتمل إطلاق التنبيه');
          return Right(alert);
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('[TriggerAlertUseCase] خطأ في إطلاق التنبيه', e, stackTrace);
      return Left(ServerFailure('فشل إطلاق التنبيه: ${e.toString()}'));
    }
  }
}
