import 'package:url_launcher/url_launcher.dart';
import 'package:psga_app/core/utils/logger.dart';
import 'package:psga_app/features/alerts/domain/entities/alert_entity.dart';
import 'package:psga_app/features/alerts/domain/entities/contact_entity.dart';

/// خدمة إرسال SMS
class SMSService {
  static final SMSService _instance = SMSService._internal();
  factory SMSService() => _instance;
  SMSService._internal();

  static SMSService get instance => _instance;

  /// إرسال SMS لرقم واحد
  Future<bool> sendSMS({
    required String phoneNumber,
    required String message,
  }) async {
    try {
      AppLogger.start('[SMS] إرسال رسالة إلى: $phoneNumber');

      final Uri smsUri = Uri(
        scheme: 'sms',
        path: phoneNumber,
        queryParameters: {'body': message},
      );

      if (await canLaunchUrl(smsUri)) {
        final launched = await launchUrl(smsUri);
        AppLogger.success('[SMS] تم فتح تطبيق الرسائل: $launched');
        return launched;
      } else {
        AppLogger.error('[SMS] لا يمكن فتح تطبيق الرسائل', 'Cannot launch SMS');
        return false;
      }
    } catch (e, stackTrace) {
      AppLogger.error('[SMS] فشل الإرسال', e, stackTrace);
      return false;
    }
  }

  /// إرسال SMS لعدة أرقام
  Future<bool> sendBulkSMS({
    required List<String> phoneNumbers,
    required String message,
  }) async {
    try {
      if (phoneNumbers.isEmpty) {
        AppLogger.warning('[SMS] لا توجد أرقام للإرسال');
        return false;
      }

      AppLogger.start('[SMS] إرسال رسائل جماعية: ${phoneNumbers.length}');

      // إرسال لأول رقم فقط (Android/iOS limitation)
      final Uri smsUri = Uri(
        scheme: 'sms',
        path: phoneNumbers.join(','),
        queryParameters: {'body': message},
      );

      if (await canLaunchUrl(smsUri)) {
        final launched = await launchUrl(smsUri);
        AppLogger.success('[SMS] تم فتح تطبيق الرسائل: $launched');
        return launched;
      } else {
        AppLogger.error('[SMS] لا يمكن فتح تطبيق الرسائل', 'Cannot launch SMS');
        return false;
      }
    } catch (e, stackTrace) {
      AppLogger.error('[SMS] فشل الإرسال الجماعي', e, stackTrace);
      return false;
    }
  }

  /// إرسال تنبيه SOS
  Future<bool> sendSOSAlert({
    required AlertEntity alert,
    required List<ContactEntity> contacts,
  }) async {
    final phoneNumbers = contacts
        .where((c) => c.canSendSMS)
        .map((c) => c.phoneNumber)
        .toList();

    if (phoneNumbers.isEmpty) {
      AppLogger.warning('[SMS] لا توجد جهات اتصال لإرسال SOS');
      return false;
    }

    final userName = alert.metadata?['userName'] ?? 'أحد المستخدمين';
    
    final locationText = alert.location != null
        ? 'الموقع الفوري: https://maps.google.com/?q=${alert.location!.latitude},${alert.location!.longitude}'
        : 'الموقع: غير متوفر';

    // بناء رسالة SOS مخصصة
    String buildSOSMessage(ContactEntity contact) {
      final contactName = contact.name;
      
      return '''
🚨🚨 طوارئ SOS 🚨🚨

$contactName،
$userName في خطر ويحتاج مساعدة عاجلة!

${alert.message}

$locationText

⏰ الوقت: ${_formatDateTime(alert.triggeredAt)}

🚨 اتصل به فوراً أو توجه للموقع!

تطبيق PSGA - حارس الأمان الشخصي
''';
    }

    // استخدام أول جهة اتصال لبناء الرسالة
    final firstContact = contacts.firstWhere((c) => c.canSendSMS);
    final message = buildSOSMessage(firstContact);

    AppLogger.warning('[SMS] إرسال SOS عاجل من: $userName');

    return await sendBulkSMS(
      phoneNumbers: phoneNumbers,
      message: message,
    );
  }

  /// إرسال تنبيه انحراف
  Future<bool> sendDeviationAlert({
    required AlertEntity alert,
    required List<ContactEntity> contacts,
  }) async {
    final phoneNumbers = contacts
        .where((c) => c.canSendSMS)
        .map((c) => c.phoneNumber)
        .toList();

    if (phoneNumbers.isEmpty) {
      return false;
    }

    final userName = alert.metadata?['userName'] ?? 'أحد المستخدمين';
    final distance = alert.metadata?['distance'] ?? 0.0;
    
    final locationText = alert.location != null
        ? 'الموقع الحالي: https://maps.google.com/?q=${alert.location!.latitude},${alert.location!.longitude}'
        : 'الموقع: غير متوفر';

    // بناء رسالة مخصصة لكل جهة اتصال تتضمن اسمها
    String buildPersonalizedMessage(ContactEntity contact) {
      final contactName = contact.name;
      
      return '''
⚠️ تحذير عاجل ⚠️

$contactName، 
$userName قد انحرف عن المسار المحدد!

📏 المسافة: ${distance.toStringAsFixed(0)} متر من المسار
⏰ الوقت: ${_formatDateTime(alert.triggeredAt)}

$locationText

🚨 يرجى التحقق من سلامته فوراً!

تطبيق PSGA - حارس الأمان الشخصي
''';
    }

    // إرسال رسالة عامة (لأن SMS API لا يدعم رسائل مختلفة)
    // لكن نستخدم أول جهة اتصال كمثال
    final firstContact = contacts.firstWhere((c) => c.canSendSMS);
    final message = buildPersonalizedMessage(firstContact);

    AppLogger.info('[SMS] إرسال تنبيه انحراف: "$userName" انحرف بمسافة ${distance.toStringAsFixed(0)}م');

    return await sendBulkSMS(
      phoneNumbers: phoneNumbers,
      message: message,
    );
  }

  /// إرسال تنبيه عام
  Future<bool> sendGeneralAlert({
    required AlertEntity alert,
    required List<ContactEntity> contacts,
  }) async {
    final phoneNumbers = contacts
        .where((c) => c.canSendSMS)
        .map((c) => c.phoneNumber)
        .toList();

    if (phoneNumbers.isEmpty) {
      return false;
    }

    final message = '''
${_getSeverityEmoji(alert.severity)} ${alert.title}

${alert.message}

الوقت: ${_formatDateTime(alert.triggeredAt)}

تطبيق PSGA
''';

    return await sendBulkSMS(
      phoneNumbers: phoneNumbers,
      message: message,
    );
  }

  /// تنسيق التاريخ والوقت
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  /// الحصول على emoji حسب الخطورة
  String _getSeverityEmoji(AlertSeverity severity) {
    switch (severity) {
      case AlertSeverity.low:
        return 'ℹ️';
      case AlertSeverity.medium:
        return '⚠️';
      case AlertSeverity.high:
        return '⚠️';
      case AlertSeverity.critical:
        return '🚨';
    }
  }

  /// التحقق من إمكانية إرسال SMS
  Future<bool> canSendSMS() async {
    try {
      final Uri smsUri = Uri(scheme: 'sms', path: '');
      return await canLaunchUrl(smsUri);
    } catch (e) {
      AppLogger.error('[SMS] خطأ في فحص الإمكانية', e);
      return false;
    }
  }
}
