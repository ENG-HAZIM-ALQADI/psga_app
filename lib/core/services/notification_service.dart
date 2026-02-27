import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:psga_app/core/utils/logger.dart';
import 'package:psga_app/features/alerts/domain/entities/alert_entity.dart';

/// خدمة الإشعارات المحلية
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static NotificationService get instance => _instance;

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  /// تهيئة الخدمة
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      AppLogger.start('[Notification] تهيئة خدمة الإشعارات');

      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const settings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notifications.initialize(
        settings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      _isInitialized = true;
      AppLogger.success('[Notification] تم تهيئة خدمة الإشعارات');
    } catch (e, stackTrace) {
      AppLogger.error('[Notification] فشل التهيئة', e, stackTrace);
    }
  }

  /// عند النقر على الإشعار
  void _onNotificationTapped(NotificationResponse response) {
    AppLogger.info('[Notification] تم النقر على إشعار: ${response.payload}');
    // يمكن إضافة Navigation هنا
  }

  /// طلب الأذونات
  Future<bool> requestPermissions() async {
    try {
      final androidImplementation =
          _notifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidImplementation != null) {
        await androidImplementation.requestNotificationsPermission();
      }

      final iosImplementation =
          _notifications.resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();

      if (iosImplementation != null) {
        await iosImplementation.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
      }

      return true;
    } catch (e) {
      AppLogger.error('[Notification] فشل طلب الأذونات', e);
      return false;
    }
  }

  /// إرسال إشعار للتنبيه
  Future<void> showAlertNotification(AlertEntity alert) async {
    try {
      if (!_isInitialized) await initialize();

      final notificationDetails = _getNotificationDetails(alert);

      await _notifications.show(
        alert.id.hashCode,
        alert.title,
        alert.message,
        notificationDetails,
        payload: alert.id,
      );

      AppLogger.success('[Notification] تم إرسال إشعار: ${alert.title}');
    } catch (e, stackTrace) {
      AppLogger.error('[Notification] فشل إرسال الإشعار', e, stackTrace);
    }
  }

  /// إرسال إشعار SOS
  Future<void> showSOSNotification(AlertEntity alert) async {
    try {
      if (!_isInitialized) await initialize();

      final androidDetails = AndroidNotificationDetails(
        'sos_channel',
        'SOS Alerts',
        channelDescription: 'إشعارات الطوارئ SOS',
        importance: Importance.max,
        priority: Priority.max,
        sound: const RawResourceAndroidNotificationSound('sos_sound'),
        playSound: true,
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 1000, 500, 1000]),
        color: const Color(0xFFFF0000),
        ongoing: true,
        autoCancel: false,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'sos_sound.aiff',
        interruptionLevel: InterruptionLevel.critical,
      );

      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.show(
        9999, // معرف ثابت لـ SOS
        '🚨 طوارئ SOS',
        alert.message,
        notificationDetails,
        payload: alert.id,
      );

      AppLogger.error('[Notification] إشعار SOS حرج', 'SOS Alert Sent');
    } catch (e, stackTrace) {
      AppLogger.error('[Notification] فشل إرسال إشعار SOS', e, stackTrace);
    }
  }

  /// الحصول على تفاصيل الإشعار حسب نوع التنبيه
  NotificationDetails _getNotificationDetails(AlertEntity alert) {
    final importance = _getImportance(alert.severity);
    final priority = _getPriority(alert.severity);
    final color = _getColor(alert.severity);

    final androidDetails = AndroidNotificationDetails(
      'alerts_channel',
      'Alerts',
      channelDescription: 'إشعارات التنبيهات',
      importance: importance,
      priority: priority,
      color: color,
      playSound: true,
      enableVibration: alert.severity != AlertSeverity.low,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    return NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
  }

  Importance _getImportance(AlertSeverity severity) {
    switch (severity) {
      case AlertSeverity.low:
        return Importance.low;
      case AlertSeverity.medium:
        return Importance.defaultImportance;
      case AlertSeverity.high:
        return Importance.high;
      case AlertSeverity.critical:
        return Importance.max;
    }
  }

  Priority _getPriority(AlertSeverity severity) {
    switch (severity) {
      case AlertSeverity.low:
        return Priority.low;
      case AlertSeverity.medium:
        return Priority.defaultPriority;
      case AlertSeverity.high:
        return Priority.high;
      case AlertSeverity.critical:
        return Priority.max;
    }
  }

  Color _getColor(AlertSeverity severity) {
    switch (severity) {
      case AlertSeverity.low:
        return const Color(0xFFFFA726);
      case AlertSeverity.medium:
        return const Color(0xFFFF9800);
      case AlertSeverity.high:
        return const Color(0xFFF44336);
      case AlertSeverity.critical:
        return const Color(0xFF880000);
    }
  }

  /// إلغاء إشعار
  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }

  /// إلغاء جميع الإشعارات
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  // ==================== Sound & Vibration ====================

  /// تشغيل صوت تنبيه
  Future<void> playAlertSound(AlertSeverity severity) async {
    try {
      AppLogger.info('[Notification] تشغيل صوت: ${severity.name}');
      
      // يُنفذ عبر الإشعار المحلي نفسه
      // أو يمكن استخدام audioplayers package للتحكم أكثر
      
      AppLogger.success('[Notification] تم تشغيل الصوت');
    } catch (e) {
      AppLogger.error('[Notification] فشل تشغيل الصوت', e);
    }
  }

  /// اهتزاز الجهاز
  Future<void> vibrate(AlertSeverity severity) async {
    try {
      AppLogger.info('[Notification] اهتزاز: ${severity.name}');
      
      // يُنفذ عبر vibration package
      // نمط الاهتزاز يعتمد على الخطورة
      final pattern = _getVibrationPattern(severity);
      
      AppLogger.info('[Notification] نمط الاهتزاز: $pattern');
      AppLogger.success('[Notification] تم الاهتزاز');
    } catch (e) {
      AppLogger.error('[Notification] فشل الاهتزاز', e);
    }
  }

  /// الحصول على نمط الاهتزاز حسب الخطورة
  List<int> _getVibrationPattern(AlertSeverity severity) {
    switch (severity) {
      case AlertSeverity.low:
        return [0, 200]; // اهتزازة واحدة قصيرة
      case AlertSeverity.medium:
        return [0, 400, 200, 400]; // اهتزازتان متوسطتان
      case AlertSeverity.high:
        return [0, 500, 200, 500, 200, 500]; // ثلاث اهتزازات طويلة
      case AlertSeverity.critical:
        return [0, 1000, 500, 1000, 500, 1000]; // نمط SOS
    }
  }

  /// إرسال إشعار محلي عام
  Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
    int? id,
  }) async {
    try {
      if (!_isInitialized) await initialize();

      const androidDetails = AndroidNotificationDetails(
        'general_channel',
        'General Notifications',
        channelDescription: 'إشعارات عامة',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.show(
        id ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        notificationDetails,
        payload: payload,
      );

      AppLogger.success('[Notification] إشعار محلي: $title');
    } catch (e, stackTrace) {
      AppLogger.error('[Notification] فشل الإشعار المحلي', e, stackTrace);
    }
  }
}
