import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/logger.dart';
import '../../../trips/domain/entities/location_entity.dart';
import '../entities/alert_entity.dart';
import '../repositories/alert_repository.dart';
import '../repositories/contact_repository.dart';

class SendSOSParams {
  final String userId;
  final String? tripId;
  final LocationEntity location;

  SendSOSParams({
    required this.userId,
    this.tripId,
    required this.location,
  });
}

class SendSOSUseCase {
  final AlertRepository alertRepository;
  final ContactRepository contactRepository;

  SendSOSUseCase({
    required this.alertRepository,
    required this.contactRepository,
  });

  Future<Either<Failure, AlertEntity>> call(SendSOSParams params) async {
    AppLogger.warning('[SOS] إرسال إشارة طوارئ!');
    
    final alert = AlertEntity(
      id: 'sos_${DateTime.now().millisecondsSinceEpoch}',
      tripId: params.tripId ?? '',
      userId: params.userId,
      type: AlertType.sos,
      level: AlertLevel.critical,
      status: AlertStatus.active,
      location: params.location,
      message: _buildSOSMessage(params.location),
      triggeredAt: DateTime.now(),
      deliveryMethod: DeliveryMethod.all,
    );

    final createResult = await alertRepository.createAlert(alert);
    
    return createResult.fold(
      (failure) => Left(failure),
      (createdAlert) async {
        final contactsResult = await contactRepository.getContacts(params.userId);
        
        return contactsResult.fold(
          (failure) => Right(createdAlert),
          (contacts) {
            final contactIds = contacts.map((c) => c.id).toList();
            final updatedAlert = createdAlert.copyWith(
              sentToContacts: contactIds,
            );
            AppLogger.info('[SOS] تم الإرسال إلى ${contacts.length} جهة اتصال');
            return Right(updatedAlert);
          },
        );
      },
    );
  }

  String _buildSOSMessage(LocationEntity location) {
    final mapsLink = 'https://maps.google.com/?q=${location.latitude},${location.longitude}';
    return '''
🚨 تنبيه طوارئ!
الموقع: $mapsLink
الوقت: ${DateTime.now().toString().substring(0, 19)}
يرجى التحقق فوراً!
''';
  }

  String getGoogleMapsUrl(LocationEntity location) {
    return 'https://maps.google.com/?q=${location.latitude},${location.longitude}';
  }
}
