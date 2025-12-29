import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../../../core/utils/logger.dart';
import '../../domain/entities/alert_entity.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );
    
    _initialized = true;
    AppLogger.info('[Notifications] تم تهيئة خدمة الإشعارات');
  }

  void _onNotificationTap(NotificationResponse response) {
    AppLogger.info('[Notifications] تم النقر على الإشعار: ${response.payload}');
  }

  Future<void> showAlertNotification(AlertEntity alert, {bool sound = true, bool vibration = true}) async {
    final androidDetails = AndroidNotificationDetails(
      'alerts_channel',
      'التنبيهات',
      channelDescription: 'إشعارات التنبيهات والطوارئ',
      importance: Importance.max,
      priority: Priority.high,
      playSound: sound,
      enableVibration: vibration,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      alert.id.hashCode,
      _getNotificationTitle(alert.type),
      alert.message,
      details,
      payload: alert.id,
    );

    AppLogger.info('[Notifications] تم عرض إشعار: ${alert.type.name}');
  }

  Future<void> showCountdownNotification(int seconds, String alertId) async {
    const androidDetails = AndroidNotificationDetails(
      'countdown_channel',
      'العد التنازلي',
      channelDescription: 'إشعارات العد التنازلي للتنبيهات',
      importance: Importance.high,
      priority: Priority.high,
      ongoing: true,
      autoCancel: false,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      alertId.hashCode + 1000,
      'تنبيه نشط',
      'سيتم التصعيد خلال $seconds ثانية',
      details,
      payload: alertId,
    );
  }

  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
    AppLogger.info('[Notifications] تم إلغاء الإشعار: $id');
  }

  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
    AppLogger.info('[Notifications] تم إلغاء جميع الإشعارات');
  }

  String _getNotificationTitle(AlertType type) {
    switch (type) {
      case AlertType.deviation:
        return 'انحراف عن المسار';
      case AlertType.sos:
        return 'طوارئ SOS';
      case AlertType.inactivity:
        return 'تنبيه عدم الحركة';
      case AlertType.lowBattery:
        return 'بطارية منخفضة';
      case AlertType.noConnection:
        return 'انقطاع الاتصال';
    }
  }
}
