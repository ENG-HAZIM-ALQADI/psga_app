import 'package:firebase_messaging/firebase_messaging.dart';
import '../../../../core/utils/logger.dart';
import '../../domain/entities/alert_entity.dart';
import '../../domain/entities/contact_entity.dart';

abstract class FCMServiceBase {
  Future<void> initialize();
  Future<String?> getToken();
  Future<void> sendAlertToContacts(
    AlertEntity alert,
    List<ContactEntity> contacts,
    String userName,
  );
  Future<void> subscribeToTopic(String topic);
  Future<void> unsubscribeFromTopic(String topic);
}

class MockFCMService implements FCMServiceBase {
  bool _initialized = false;
  String? _mockToken;

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    
    _mockToken = 'mock_fcm_token_${DateTime.now().millisecondsSinceEpoch}';
    _initialized = true;
    AppLogger.info('[FCM-Mock] تم تهيئة خدمة FCM الوهمية');
  }

  @override
  Future<String?> getToken() async {
    _mockToken ??= 'mock_fcm_token_${DateTime.now().millisecondsSinceEpoch}';
    return _mockToken;
  }

  @override
  Future<void> sendAlertToContacts(
    AlertEntity alert,
    List<ContactEntity> contacts,
    String userName,
  ) async {
    AppLogger.info('[FCM-Mock] إرسال تنبيه إلى ${contacts.length} جهة اتصال');
    
    for (final contact in contacts) {
      AppLogger.info('[FCM-Mock] إرسال إلى: ${contact.name}');
      await Future.delayed(const Duration(milliseconds: 100));
    }
    
    AppLogger.success('[FCM-Mock] تم إرسال التنبيهات بنجاح');
  }

  @override
  Future<void> subscribeToTopic(String topic) async {
    AppLogger.info('[FCM-Mock] تم الاشتراك في: $topic');
  }

  @override
  Future<void> unsubscribeFromTopic(String topic) async {
    AppLogger.info('[FCM-Mock] تم إلغاء الاشتراك من: $topic');
  }
}

class FirebaseFCMService implements FCMServiceBase {
  bool _initialized = false;
  String? _token;
  FirebaseMessaging? _messaging;

  @override
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      _messaging = FirebaseMessaging.instance;
      
      final settings = await _messaging!.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        AppLogger.info('[FCM] تم منح صلاحيات الإشعارات');
      } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
        AppLogger.info('[FCM] تم منح صلاحيات مؤقتة للإشعارات');
      } else {
        AppLogger.warning('[FCM] تم رفض صلاحيات الإشعارات');
      }

      _token = await _messaging!.getToken();
      if (_token != null && _token!.length > 20) {
        AppLogger.info('[FCM] Token: ${_token!.substring(0, 20)}...');
      }

      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

      _initialized = true;
      AppLogger.success('[FCM] تم تهيئة خدمة FCM');
    } catch (e) {
      AppLogger.error('[FCM] خطأ في التهيئة: $e');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    AppLogger.info('[FCM] رسالة في المقدمة: ${message.notification?.title}');
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    AppLogger.info('[FCM] تم فتح التطبيق من الإشعار: ${message.notification?.title}');
  }

  @override
  Future<String?> getToken() async {
    if (_messaging == null) return null;
    _token ??= await _messaging!.getToken();
    return _token;
  }

  @override
  Future<void> sendAlertToContacts(
    AlertEntity alert,
    List<ContactEntity> contacts,
    String userName,
  ) async {
    final contactsWithToken = contacts.where(
      (c) => c.fcmToken != null && c.fcmToken!.isNotEmpty
    ).toList();
    
    if (contactsWithToken.isEmpty) {
      AppLogger.warning('[FCM] لا توجد جهات اتصال لديها FCM token');
      return;
    }

    AppLogger.info('[FCM] إرسال إشعار إلى ${contactsWithToken.length} جهة');

    for (final contact in contactsWithToken) {
      await _sendToToken(
        token: contact.fcmToken!,
        title: _getAlertTitle(alert.type, userName),
        body: _getAlertBody(alert),
        data: {
          'alertId': alert.id,
          'alertType': alert.type.name,
          'lat': alert.location.latitude.toString(),
          'lng': alert.location.longitude.toString(),
        },
      );
    }
  }

  Future<void> _sendToToken({
    required String token,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    AppLogger.info('[FCM] إرسال إلى token: ${token.substring(0, 10)}...');
  }

  String _getAlertTitle(AlertType type, String userName) {
    switch (type) {
      case AlertType.deviation:
        return 'تنبيه انحراف - $userName';
      case AlertType.sos:
        return 'طوارئ SOS - $userName';
      case AlertType.inactivity:
        return 'تنبيه عدم حركة - $userName';
      case AlertType.lowBattery:
        return 'بطارية منخفضة - $userName';
      case AlertType.noConnection:
        return 'انقطاع اتصال - $userName';
    }
  }

  String _getAlertBody(AlertEntity alert) {
    final mapsUrl = 'https://maps.google.com/?q=${alert.location.latitude},${alert.location.longitude}';
    return '${alert.message}\nالموقع: $mapsUrl';
  }

  @override
  Future<void> subscribeToTopic(String topic) async {
    if (_messaging == null) return;
    await _messaging!.subscribeToTopic(topic);
    AppLogger.info('[FCM] تم الاشتراك في: $topic');
  }

  @override
  Future<void> unsubscribeFromTopic(String topic) async {
    if (_messaging == null) return;
    await _messaging!.unsubscribeFromTopic(topic);
    AppLogger.info('[FCM] تم إلغاء الاشتراك من: $topic');
  }
}

class FCMService implements FCMServiceBase {
  final FCMServiceBase _delegate;
  
  FCMService({bool useMock = true}) : _delegate = useMock ? MockFCMService() : FirebaseFCMService();

  @override
  Future<void> initialize() => _delegate.initialize();

  @override
  Future<String?> getToken() => _delegate.getToken();

  @override
  Future<void> sendAlertToContacts(
    AlertEntity alert,
    List<ContactEntity> contacts,
    String userName,
  ) => _delegate.sendAlertToContacts(alert, contacts, userName);

  @override
  Future<void> subscribeToTopic(String topic) => _delegate.subscribeToTopic(topic);

  @override
  Future<void> unsubscribeFromTopic(String topic) => _delegate.unsubscribeFromTopic(topic);
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  AppLogger.info('[FCM] رسالة في الخلفية: ${message.notification?.title}');
}
