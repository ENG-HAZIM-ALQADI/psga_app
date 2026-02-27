import 'package:cloud_functions/cloud_functions.dart';
import 'package:psga_app/core/utils/logger.dart';
import 'package:psga_app/features/alerts/domain/entities/alert_entity.dart';
import 'package:psga_app/features/alerts/domain/entities/contact_entity.dart';

/// خدمة إرسال Email عبر Cloud Functions
/// 
/// تستخدم Firebase Cloud Functions مع Nodemailer (مجاني)
class EmailService {
  static EmailService? _instance;
  static EmailService get instance => _instance ??= EmailService._();
  
  EmailService._();

  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// إرسال email واحد
  Future<bool> sendEmail({
    required String to,
    required String subject,
    required String body,
    bool isHtml = true,
  }) async {
    try {
      AppLogger.start('[Email] إرسال email إلى: $to');

      final callable = _functions.httpsCallable('sendEmail');
      
      final result = await callable.call({
        'to': to,
        'subject': subject,
        'body': body,
        'isHtml': isHtml,
      });

      final data = result.data as Map<String, dynamic>;
      final success = data['success'] ?? false;

      if (success) {
        AppLogger.success('[Email] تم إرسال email بنجاح');
      } else {
        AppLogger.error('[Email] فشل إرسال email', data['error']);
      }

      return success;
    } catch (e, stackTrace) {
      AppLogger.error('[Email] خطأ في إرسال email', e, stackTrace);
      return false;
    }
  }

  /// إرسال email متعدد (bulk)
  Future<Map<String, dynamic>> sendBulkEmail({
    required List<String> recipients,
    required String subject,
    required String body,
    bool isHtml = true,
  }) async {
    try {
      if (recipients.isEmpty) {
        AppLogger.warning('[Email] لا توجد عناوين للإرسال');
        return {'success': false, 'sent': 0, 'failed': 0};
      }

      AppLogger.start('[Email] إرسال bulk email لـ ${recipients.length} عنوان');

      final callable = _functions.httpsCallable('sendBulkEmail');
      
      final result = await callable.call({
        'recipients': recipients,
        'subject': subject,
        'body': body,
        'isHtml': isHtml,
      });

      final data = result.data as Map<String, dynamic>;

      AppLogger.success(
        '[Email] تم إرسال ${data['sent']} من ${recipients.length}',
      );

      return {
        'success': data['success'] ?? false,
        'sent': data['sent'] ?? 0,
        'failed': data['failed'] ?? 0,
      };
    } catch (e, stackTrace) {
      AppLogger.error('[Email] خطأ في bulk email', e, stackTrace);
      return {'success': false, 'sent': 0, 'failed': recipients.length};
    }
  }

  /// إرسال تنبيه SOS
  Future<bool> sendSOSAlert({
    required AlertEntity alert,
    required List<ContactEntity> contacts,
  }) async {
    final recipients = contacts
        .where((c) => c.email != null && c.email!.isNotEmpty && c.canSendEmail)
        .map((c) => c.email!)
        .toList();

    if (recipients.isEmpty) {
      AppLogger.warning('[Email] لا توجد عناوين email لإرسال SOS');
      return false;
    }

    final userName = alert.metadata?['userName'] ?? 'مستخدم';
    final latitude = alert.location?.latitude ?? 0.0;
    final longitude = alert.location?.longitude ?? 0.0;
    
    // إرسال email مخصص لكل جهة اتصال
    bool allSuccess = true;
    for (final contact in contacts.where((c) => c.canSendEmail && c.email != null)) {
      final subject = '🚨 طوارئ SOS عاجلة - $userName يحتاج مساعدة';
      final body = EmailTemplates.sosAlert(
        userName: userName,
        message: alert.message,
        latitude: latitude,
        longitude: longitude,
        timestamp: alert.triggeredAt,
        contactName: contact.name, // ✅ إضافة اسم جهة الاتصال
      );

      final success = await sendEmail(
        to: contact.email!,
        subject: subject,
        body: body,
        isHtml: true,
      );

      if (!success) {
        allSuccess = false;
        AppLogger.warning('[Email] فشل إرسال SOS لـ: ${contact.name}');
      }
    }

    if (allSuccess) {
      AppLogger.success('[Email] تم إرسال جميع رسائل SOS بنجاح');
    }

    return allSuccess;
  }

  /// إرسال تنبيه انحراف
  Future<bool> sendDeviationAlert({
    required AlertEntity alert,
    required List<ContactEntity> contacts,
  }) async {
    final recipients = contacts
        .where((c) => c.email != null && c.email!.isNotEmpty && c.canSendEmail)
        .map((c) => c.email!)
        .toList();

    if (recipients.isEmpty) {
      AppLogger.warning('[Email] لا توجد عناوين email لإرسال انحراف');
      return false;
    }

    final userName = alert.metadata?['userName'] ?? 'مستخدم';
    final distance = alert.metadata?['distance'] ?? 0.0;
    final latitude = alert.location?.latitude ?? 0.0;
    final longitude = alert.location?.longitude ?? 0.0;
    
    // إرسال email مخصص لكل جهة اتصال
    bool allSuccess = true;
    for (final contact in contacts.where((c) => c.canSendEmail && c.email != null)) {
      final subject = '⚠️ تحذير عاجل: $userName انحرف عن المسار';
      final body = EmailTemplates.deviationAlert(
        userName: userName,
        message: alert.message,
        distance: distance,
        latitude: latitude,
        longitude: longitude,
        timestamp: alert.triggeredAt,
        contactName: contact.name, // ✅ إضافة اسم جهة الاتصال
      );

      final success = await sendEmail(
        to: contact.email!,
        subject: subject,
        body: body,
        isHtml: true,
      );

      if (!success) {
        allSuccess = false;
        AppLogger.warning('[Email] فشل إرسال لـ: ${contact.name}');
      }
    }

    if (allSuccess) {
      AppLogger.success('[Email] تم إرسال جميع رسائل الانحراف بنجاح');
    }

    return allSuccess;
  }

  /// إرسال تنبيه عام
  Future<bool> sendGeneralAlert({
    required AlertEntity alert,
    required List<ContactEntity> contacts,
  }) async {
    final recipients = contacts
        .where((c) => c.email != null && c.email!.isNotEmpty && c.canSendEmail)
        .map((c) => c.email!)
        .toList();

    if (recipients.isEmpty) {
      return false;
    }

    final userName = alert.metadata?['userName'] ?? 'مستخدم';
    final subject = '${_getSeverityEmoji(alert.severity)} ${alert.title}';
    final body = EmailTemplates.generalAlert(
      userName: userName,
      title: alert.title,
      message: alert.message,
      severity: alert.severity,
      timestamp: alert.triggeredAt,
    );

    final result = await sendBulkEmail(
      recipients: recipients,
      subject: subject,
      body: body,
      isHtml: true,
    );

    return result['success'] ?? false;
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

  /// التحقق من إمكانية إرسال Email
  Future<bool> canSendEmail() async {
    try {
      // يمكن إضافة فحص للاتصال أو الإعدادات
      return true;
    } catch (e) {
      AppLogger.error('[Email] خطأ في فحص الإمكانية', e);
      return false;
    }
  }
}

/// قوالب HTML للـ Emails
class EmailTemplates {
  /// قالب SOS
  static String sosAlert({
    required String userName,
    required String message,
    required double latitude,
    required double longitude,
    required DateTime timestamp,
    String contactName = 'عزيزي',
  }) {
    return '''
<!DOCTYPE html>
<html dir="rtl" lang="ar">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    body {
      font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
      margin: 0;
      padding: 0;
      background-color: #f5f5f5;
    }
    .container {
      max-width: 600px;
      margin: 20px auto;
      background: white;
      border-radius: 10px;
      overflow: hidden;
      box-shadow: 0 4px 6px rgba(0,0,0,0.1);
    }
    .header {
      background: linear-gradient(135deg, #dc2626 0%, #991b1b 100%);
      color: white;
      padding: 30px 20px;
      text-align: center;
      animation: pulse 2s infinite;
    }
    @keyframes pulse {
      0%, 100% { opacity: 1; }
      50% { opacity: 0.8; }
    }
    .header h1 {
      margin: 0;
      font-size: 32px;
      font-weight: bold;
    }
    .content {
      padding: 30px 20px;
    }
    .alert-box {
      background: #fef2f2;
      border-right: 4px solid #dc2626;
      padding: 20px;
      margin: 20px 0;
      border-radius: 5px;
    }
    .alert-box h2 {
      margin-top: 0;
      color: #991b1b;
      font-size: 24px;
    }
    .emergency-text {
      font-size: 20px;
      font-weight: bold;
      color: #dc2626;
      margin: 15px 0;
      text-align: center;
    }
    .info-row {
      margin: 15px 0;
      padding: 10px;
      background: #f9fafb;
      border-radius: 5px;
    }
    .info-label {
      font-weight: bold;
      color: #374151;
      margin-left: 5px;
    }
    .button {
      display: inline-block;
      background: #dc2626;
      color: white !important;
      padding: 18px 50px;
      text-decoration: none;
      border-radius: 8px;
      margin: 20px 0;
      font-weight: bold;
      font-size: 18px;
      text-align: center;
      box-shadow: 0 4px 8px rgba(220, 38, 38, 0.4);
    }
    .button:hover {
      background: #991b1b;
    }
    .footer {
      background: #f9fafb;
      padding: 20px;
      text-align: center;
      font-size: 12px;
      color: #6b7280;
      border-top: 1px solid #e5e7eb;
    }
    .urgent-notice {
      background: #7f1d1d;
      color: white;
      padding: 20px;
      text-align: center;
      font-size: 16px;
      font-weight: bold;
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>🚨🚨 طوارئ SOS 🚨🚨</h1>
    </div>
    <div class="urgent-notice">
      ⚠️ هذه رسالة طوارئ - يتطلب استجابة فورية ⚠️
    </div>
    <div class="content">
      <div class="alert-box">
        <h2>$contactName،</h2>
        <p class="emergency-text">🚨 $userName في خطر ويحتاج مساعدة فورية!</p>
        <p style="margin:10px 0; font-size:18px; color:#991b1b;">$message</p>
      </div>
      
      <div class="info-row">
        <span class="info-label">⏰ وقت الطوارئ:</span>
        <span style="color:#dc2626; font-weight:bold;">${_formatDateTime(timestamp)}</span>
      </div>
      
      <div class="info-row">
        <span class="info-label">📍 الموقع الفوري:</span>
        <br>
        <span>خط العرض: $latitude</span>
        <br>
        <span>خط الطول: $longitude</span>
      </div>
      
      <div style="text-align: center; margin-top: 30px;">
        <a href="https://maps.google.com/?q=$latitude,$longitude" class="button">
          📍 انتقل للموقع فوراً
        </a>
      </div>
      
      <div style="background: #7f1d1d; color: white; padding: 20px; border-radius: 5px; margin-top: 20px; text-align: center;">
        <p style="margin: 0; font-size: 18px; font-weight: bold;">
          🚨 يُرجى الاتصال بـ $userName فوراً أو التوجه للموقع
        </p>
        <p style="margin: 10px 0 0 0; font-size: 14px;">
          كل ثانية مهمة - استجابتك السريعة قد تنقذ حياة
        </p>
      </div>
    </div>
    <div class="footer">
      <p>هذا تنبيه طوارئ آلي من تطبيق PSGA - حارس الأمان الشخصي</p>
      <p><strong style="color:#dc2626;">يرجى الاستجابة فوراً للتأكد من سلامة $userName</strong></p>
    </div>
  </div>
</body>
</html>
    ''';
  }

  /// قالب انحراف
  static String deviationAlert({
    required String userName,
    required String message,
    required double distance,
    required double latitude,
    required double longitude,
    required DateTime timestamp,
    String contactName = 'عزيزي',
  }) {
    return '''
<!DOCTYPE html>
<html dir="rtl" lang="ar">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    body {
      font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
      margin: 0;
      padding: 0;
      background-color: #f5f5f5;
    }
    .container {
      max-width: 600px;
      margin: 20px auto;
      background: white;
      border-radius: 10px;
      overflow: hidden;
      box-shadow: 0 4px 6px rgba(0,0,0,0.1);
    }
    .header {
      background: linear-gradient(135deg, #f59e0b 0%, #d97706 100%);
      color: white;
      padding: 30px 20px;
      text-align: center;
    }
    .header h1 {
      margin: 0;
      font-size: 28px;
      font-weight: bold;
    }
    .content {
      padding: 30px 20px;
    }
    .alert-box {
      background: #fffbeb;
      border-right: 4px solid #f59e0b;
      padding: 20px;
      margin: 20px 0;
      border-radius: 5px;
    }
    .alert-box h2 {
      margin-top: 0;
      color: #d97706;
      font-size: 22px;
    }
    .warning-text {
      font-size: 18px;
      font-weight: bold;
      color: #b45309;
      margin: 15px 0;
    }
    .info-row {
      margin: 15px 0;
      padding: 10px;
      background: #f9fafb;
      border-radius: 5px;
    }
    .info-label {
      font-weight: bold;
      color: #374151;
      margin-left: 5px;
    }
    .button {
      display: inline-block;
      background: #f59e0b;
      color: white !important;
      padding: 15px 40px;
      text-decoration: none;
      border-radius: 8px;
      margin: 20px 0;
      font-weight: bold;
      font-size: 16px;
      text-align: center;
      box-shadow: 0 2px 4px rgba(0,0,0,0.2);
    }
    .button:hover {
      background: #d97706;
    }
    .footer {
      background: #f9fafb;
      padding: 20px;
      text-align: center;
      font-size: 12px;
      color: #6b7280;
      border-top: 1px solid #e5e7eb;
    }
    .urgent {
      color: #dc2626;
      font-weight: bold;
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>⚠️ تحذير: انحراف عن المسار</h1>
    </div>
    <div class="content">
      <div class="alert-box">
        <h2>$contactName،</h2>
        <p class="warning-text">🚨 $userName قد انحرف عن المسار المحدد!</p>
        <p style="margin:10px 0; font-size:16px;">$message</p>
        <p class="urgent">⚠️ يرجى التحقق من سلامته فوراً</p>
      </div>
      
      <div class="info-row">
        <span class="info-label">📏 المسافة عن المسار:</span>
        <span style="color:#d97706; font-weight:bold;">${distance.toStringAsFixed(0)} متر</span>
      </div>
      
      <div class="info-row">
        <span class="info-label">⏰ وقت الانحراف:</span>
        <span>${_formatDateTime(timestamp)}</span>
      </div>
      
      <div class="info-row">
        <span class="info-label">📍 الموقع الحالي:</span>
        <br>
        <span>خط العرض: $latitude</span>
        <br>
        <span>خط الطول: $longitude</span>
      </div>
      
      <div style="text-align: center; margin-top: 30px;">
        <a href="https://maps.google.com/?q=$latitude,$longitude" class="button">
          📍 عرض الموقع الفوري على الخريطة
        </a>
      </div>
      
      <div style="background: #fef2f2; padding: 15px; border-radius: 5px; margin-top: 20px; border-right: 3px solid #dc2626;">
        <p style="margin: 0; color: #991b1b; font-weight: bold;">
          ⚠️ تنبيه: هذا انحراف غير متوقع عن المسار. يُرجى الاتصال بـ $userName للتأكد من سلامته.
        </p>
      </div>
    </div>
    <div class="footer">
      <p>هذا تنبيه آلي من تطبيق PSGA - حارس الأمان الشخصي</p>
      <p><strong>الاستجابة السريعة قد تنقذ حياة</strong></p>
    </div>
  </div>
</body>
</html>
    ''';
  }

  /// قالب تنبيه عام
  static String generalAlert({
    required String userName,
    required String title,
    required String message,
    required AlertSeverity severity,
    required DateTime timestamp,
  }) {
    final color = _getSeverityColor(severity);
    
    return '''
<!DOCTYPE html>
<html dir="rtl" lang="ar">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    body {
      font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
      margin: 0;
      padding: 0;
      background-color: #f5f5f5;
    }
    .container {
      max-width: 600px;
      margin: 20px auto;
      background: white;
      border-radius: 10px;
      overflow: hidden;
      box-shadow: 0 4px 6px rgba(0,0,0,0.1);
    }
    .header {
      background: $color;
      color: white;
      padding: 30px 20px;
      text-align: center;
    }
    .content {
      padding: 30px 20px;
    }
    .footer {
      background: #f9fafb;
      padding: 20px;
      text-align: center;
      font-size: 12px;
      color: #6b7280;
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>$title</h1>
    </div>
    <div class="content">
      <p>$message</p>
      <p><strong>الوقت:</strong> ${_formatDateTime(timestamp)}</p>
    </div>
    <div class="footer">
      <p>تطبيق PSGA - حارس الأمان الشخصي</p>
    </div>
  </div>
</body>
</html>
    ''';
  }

  static String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  static String _getSeverityColor(AlertSeverity severity) {
    switch (severity) {
      case AlertSeverity.low:
        return '#3b82f6';
      case AlertSeverity.medium:
        return '#f59e0b';
      case AlertSeverity.high:
        return '#ef4444';
      case AlertSeverity.critical:
        return '#991b1b';
    }
  }
}
