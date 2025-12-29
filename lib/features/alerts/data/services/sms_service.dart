import 'package:url_launcher/url_launcher.dart';
import '../../../../core/utils/logger.dart';
import '../../domain/entities/alert_entity.dart';
import '../../domain/entities/contact_entity.dart';

class SMSService {
  static final SMSService _instance = SMSService._internal();
  factory SMSService() => _instance;
  SMSService._internal();

  Future<bool> canSendSMS() async {
    final uri = Uri(scheme: 'sms', path: '');
    return await canLaunchUrl(uri);
  }

  Future<bool> sendSMS(String phoneNumber, String message) async {
    try {
      final encodedMessage = Uri.encodeComponent(message);
      final uri = Uri.parse('sms:$phoneNumber?body=$encodedMessage');
      
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        AppLogger.info('[SMS] تم فتح تطبيق الرسائل للرقم: $phoneNumber');
        return true;
      } else {
        AppLogger.error('[SMS] لا يمكن فتح تطبيق الرسائل');
        return false;
      }
    } catch (e) {
      AppLogger.error('[SMS] خطأ في إرسال الرسالة: $e');
      return false;
    }
  }

  Future<void> sendEmergencySMS(
    AlertEntity alert,
    List<ContactEntity> contacts,
    String userName,
  ) async {
    if (contacts.isEmpty) {
      AppLogger.warning('[SMS] لا توجد جهات اتصال للإرسال');
      return;
    }

    final message = _buildEmergencyMessage(alert, userName);
    
    AppLogger.info('[SMS] إرسال رسالة طوارئ إلى ${contacts.length} جهة');

    for (final contact in contacts) {
      await sendSMS(contact.phoneNumber, message);
    }
  }

  String _buildEmergencyMessage(AlertEntity alert, String userName) {
    final mapsLink = 'https://maps.google.com/?q=${alert.location.latitude},${alert.location.longitude}';
    final time = '${alert.triggeredAt.hour}:${alert.triggeredAt.minute.toString().padLeft(2, '0')}';
    
    return '''
🚨 تنبيه طوارئ من $userName!
${_getAlertTypeText(alert.type)}
الموقع: $mapsLink
الوقت: $time
يرجى التحقق فوراً!
''';
  }

  String _getAlertTypeText(AlertType type) {
    switch (type) {
      case AlertType.deviation:
        return 'انحراف عن المسار المحدد';
      case AlertType.sos:
        return 'إشارة طوارئ SOS';
      case AlertType.inactivity:
        return 'لم يتم اكتشاف أي حركة';
      case AlertType.lowBattery:
        return 'بطارية الجهاز منخفضة';
      case AlertType.noConnection:
        return 'انقطاع الاتصال';
    }
  }

  Future<bool> callEmergencyNumber(String number) async {
    try {
      final uri = Uri.parse('tel:$number');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        AppLogger.info('[SMS] جاري الاتصال بـ: $number');
        return true;
      }
      return false;
    } catch (e) {
      AppLogger.error('[SMS] خطأ في الاتصال: $e');
      return false;
    }
  }
}
