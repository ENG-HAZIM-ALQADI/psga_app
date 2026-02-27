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

class SendSOSParams extends Equatable {
  final String userId;
  final Location location;
  final String? message;

  const SendSOSParams({
    required this.userId,
    required this.location,
    this.message,
  });

  @override
  List<Object?> get props => [userId, location, message];
}

/// UseCase لإرسال SOS مع التكامل الكامل مع جهات الاتصال الطوارئ
class SendSOSUseCase implements UseCase<AlertEntity, SendSOSParams> {
  final AlertsRepository repository;
  final SMSService? smsService;
  final FCMService? fcmService;

  SendSOSUseCase(
    this.repository, {
    this.smsService,
    this.fcmService,
  });

  @override
  Future<Either<Failure, AlertEntity>> call(SendSOSParams params) async {
    try {
      AppLogger.start('[SendSOSUseCase] إرسال SOS');

      // 1. إنشاء وحفظ Alert
      final alertResult = await repository.sendSOS(
        userId: params.userId,
        location: params.location,
        message: params.message,
      );

      return alertResult.fold(
        (failure) => Left(failure),
        (alert) async {
          AppLogger.info('[SendSOSUseCase] تم إنشاء Alert: ${alert.id}');

          // 2. جلب جهات الاتصال الطوارئ
          final contactsResult = await repository.getEmergencyContacts(params.userId);

          await contactsResult.fold(
            (failure) {
              AppLogger.error('[SendSOSUseCase] فشل جلب جهات الاتصال', failure.message);
            },
            (contacts) async {
              if (contacts.isEmpty) {
                AppLogger.warning('[SendSOSUseCase] لا توجد جهات اتصال طوارئ');
                return;
              }

              AppLogger.info('[SendSOSUseCase] جهات اتصال طوارئ: ${contacts.length}');

              // 3. إرسال SMS لجميع جهات الاتصال
              if (smsService != null) {
                try {
                  await smsService!.sendSOSAlert(
                    alert: alert,
                    contacts: contacts,
                  );
                  AppLogger.success('[SendSOSUseCase] تم إرسال SMS لـ ${contacts.length} جهة');
                } catch (e) {
                  AppLogger.error('[SendSOSUseCase] فشل إرسال SMS', e);
                }
              }

              // 4. إرسال FCM للجهات التي لديها tokens
              if (fcmService != null) {
                try {
                  final contactsWithTokens = contacts.where((c) => c.fcmToken != null).toList();
                  
                  if (contactsWithTokens.isNotEmpty) {
                    await fcmService!.sendSOSAlert(
                      title: alert.title,
                      message: alert.message,
                      location: {
                        'latitude': params.location.latitude,
                        'longitude': params.location.longitude,
                        'timestamp': params.location.timestamp.toIso8601String(),
                      },
                    );
                    AppLogger.success('[SendSOSUseCase] تم إرسال FCM لـ ${contactsWithTokens.length} جهة');
                  }
                } catch (e) {
                  AppLogger.error('[SendSOSUseCase] فشل إرسال FCM', e);
                }
              }
            },
          );

          AppLogger.success('[SendSOSUseCase] اكتمل إرسال SOS');
          return Right(alert);
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('[SendSOSUseCase] خطأ في إرسال SOS', e, stackTrace);
      return Left(ServerFailure('فشل إرسال SOS: ${e.toString()}'));
    }
  }
}
