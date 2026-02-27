import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:psga_app/core/utils/logger.dart';

/// معالج رسائل الخلفية (Top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  AppLogger.info('[FCM] رسالة في الخلفية: ${message.notification?.title}');
}

/// خدمة Firebase Cloud Messaging
///
/// ملاحظة: هذه النسخة تستخدم Cloud Functions لإرسال الإشعارات
/// بدلاً من استخدام Server Key مباشرة (أكثر أمانًا)
class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  static FCMService get instance => _instance;

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _fcmToken;

  /// تهيئة FCM
  Future<void> initialize() async {
    try {
      AppLogger.start('[FCM] تهيئة FCM');

      // طلب الأذونات
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
        criticalAlert: true, // للإشعارات الحرجة (iOS)
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        AppLogger.success('[FCM] تم منح الأذونات');
      } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
        AppLogger.info('[FCM] أذونات مؤقتة');
      } else {
        AppLogger.warning('[FCM] لم يتم منح الأذونات');
      }

      // الحصول على التوكن
      _fcmToken = await _messaging.getToken();
      AppLogger.info('[FCM] Token: ${_fcmToken?.substring(0, 20)}...');

      // الاستماع لتغيير التوكن
      _messaging.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        AppLogger.info('[FCM] Token جديد: ${newToken.substring(0, 20)}...');
        // حفظ التوكن الجديد في Firestore
        _saveFCMToken(newToken);
      });

      // الاستماع للرسائل في Foreground
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // الاستماع عند فتح التطبيق من notification
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

      // معالج رسائل الخلفية
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // التحقق من رسالة أدت لفتح التطبيق
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleInitialMessage(initialMessage);
      }

      // حفظ التوكن الحالي
      if (_fcmToken != null) {
        await _saveFCMToken(_fcmToken!);
      }

      AppLogger.success('[FCM] تم تهيئة FCM');
    } catch (e, stackTrace) {
      AppLogger.error('[FCM] فشل التهيئة', e, stackTrace);
    }
  }

  /// حفظ FCM Token في Firestore
  Future<void> _saveFCMToken(String token) async {
    try {
      // يجب أن يكون المستخدم مسجل دخول
      // سيتم تنفيذ هذا من AuthRepository بعد تسجيل الدخول
      AppLogger.info('[FCM] جاري حفظ التوكن');
    } catch (e) {
      AppLogger.error('[FCM] فشل حفظ التوكن', e);
    }
  }

  /// معالجة رسالة في Foreground
  void _handleForegroundMessage(RemoteMessage message) {
    AppLogger.info('[FCM] رسالة جديدة: ${message.notification?.title}');

    final data = message.data;
    final type = data['type'] as String?;

    if (type == 'alert' || type == 'sos') {
      AppLogger.warning('[FCM] تنبيه طوارئ مستلم!');
      // يمكن إظهار notification محلية هنا
      // أو تحديث الـ UI مباشرة
    }
  }

  /// معالجة فتح التطبيق من notification
  void _handleMessageOpenedApp(RemoteMessage message) {
    AppLogger.info('[FCM] فتح من notification: ${message.notification?.title}');

    final data = message.data;

    // Navigation بناءً على البيانات
    if (data.containsKey('alertId')) {
      final alertId = data['alertId'] as String;
      AppLogger.info('[FCM] فتح تنبيه: $alertId');
      // يمكن إضافة navigation هنا
    } else if (data.containsKey('type') && data['type'] == 'sos') {
      AppLogger.info('[FCM] فتح SOS');
      // Navigation لشاشة الطوارئ
    }
  }

  /// معالجة رسالة أدت لفتح التطبيق
  void _handleInitialMessage(RemoteMessage message) {
    AppLogger.info('[FCM] التطبيق فُتح من notification: ${message.notification?.title}');
    _handleMessageOpenedApp(message);
  }

  /// الاشتراك في topic
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _messaging.subscribeToTopic(topic);
      AppLogger.info('[FCM] اشتراك في: $topic');
    } catch (e, stackTrace) {
      AppLogger.error('[FCM] فشل الاشتراك في $topic', e, stackTrace);
    }
  }

  /// إلغاء الاشتراك من topic
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _messaging.unsubscribeFromTopic(topic);
      AppLogger.info('[FCM] إلغاء اشتراك من: $topic');
    } catch (e, stackTrace) {
      AppLogger.error('[FCM] فشل إلغاء الاشتراك من $topic', e, stackTrace);
    }
  }

  // ==================== إرسال الإشعارات عبر Cloud Functions ====================

  /// إرسال إشعار عبر حفظ في Firestore (Cloud Function ستتولى الإرسال)
  ///
  /// هذه الطريقة أكثر أمانًا من إرسال مباشر بـ Server Key
  /// Cloud Function ستكتشف التنبيه الجديد تلقائياً وترسل الإشعارات
  Future<bool> sendNotificationToDevice({
    required String token,
    required String title,
    required String body,
    Map<String, dynamic>? data,
    String? imageUrl,
  }) async {
    try {
      AppLogger.info('[FCM] هذه الدالة لم تعد مستخدمة - استخدم Firestore Trigger');
      AppLogger.info('[FCM] قم بحفظ التنبيه في Firestore وسيتم الإرسال تلقائياً');

      // لا نقوم بإرسال مباشر - Cloud Function ستتولى ذلك
      return true;
    } catch (e, stackTrace) {
      AppLogger.error('[FCM] خطأ', e, stackTrace);
      return false;
    }
  }

  /// إرسال SOS عبر Cloud Function
  ///
  /// يستدعي Cloud Function مباشرة لإرسال طوارئ فوري
  Future<Map<String, dynamic>> sendSOSAlert({
    required String title,
    required String message,
    Map<String, dynamic>? location,
  }) async {
    try {
      AppLogger.info('[FCM] جاري إرسال SOS عبر Cloud Function');

      final callable = _functions.httpsCallable('sendSOSAlert');

      final result = await callable.call({
        'title': title,
        'message': message,
        'location': location,
      });

      final data = result.data as Map<String, dynamic>;

      AppLogger.success(
        '[FCM] تم إرسال SOS: ${data['notificationsSent']} إشعار',
      );

      return {
        'success': data['success'] ?? false,
        'notificationsSent': data['notificationsSent'] ?? 0,
        'notificationsFailed': data['notificationsFailed'] ?? 0,
      };
    } catch (e, stackTrace) {
      AppLogger.error('[FCM] فشل إرسال SOS', e, stackTrace);

      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// إرسال تنبيه انحراف عبر Cloud Function
  Future<Map<String, dynamic>> sendDeviationAlert({
    required String userId,
    required String tripId,
    required String severity,
    required Map<String, dynamic> location,
    required double distance,
  }) async {
    try {
      AppLogger.info('[FCM] جاري إرسال تنبيه انحراف');

      final callable = _functions.httpsCallable('sendDeviationAlert');

      final result = await callable.call({
        'userId': userId,
        'tripId': tripId,
        'severity': severity,
        'location': location,
        'distance': distance,
        'timestamp': DateTime.now().toIso8601String(),
      });

      final data = result.data as Map<String, dynamic>;

      AppLogger.success('[FCM] تم إرسال تنبيه الانحراف');
      return {
        'success': data['success'] ?? false,
        'notificationsSent': data['notificationsSent'] ?? 0,
      };
    } catch (e, stackTrace) {
      AppLogger.error('[FCM] فشل إرسال تنبيه الانحراف', e, stackTrace);
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// إرسال تنبيه عام للمستخدمين
  Future<bool> sendAlertToContacts({
    required String userId,
    required List<String> contactIds,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      AppLogger.info('[FCM] إرسال تنبيه لـ ${contactIds.length} جهة اتصال');

      // جلب tokens لجهات الاتصال
      final tokens = <String>[];
      for (final contactId in contactIds) {
        try {
          final doc = await _firestore
              .collection('users')
              .doc(userId)
              .collection('contacts')
              .doc(contactId)
              .get();

          if (doc.exists && doc.data()?['fcmToken'] != null) {
            tokens.add(doc.data()!['fcmToken'] as String);
          }
        } catch (e) {
          AppLogger.warning('[FCM] فشل جلب token لـ $contactId', e);
        }
      }

      if (tokens.isEmpty) {
        AppLogger.warning('[FCM] لا توجد tokens متاحة للإرسال');
        return false;
      }

      // استدعاء Cloud Function
      final callable = _functions.httpsCallable('sendNotificationToTokens');
      
      await callable.call({
        'tokens': tokens,
        'title': title,
        'body': body,
        'data': data ?? {},
      });

      AppLogger.success('[FCM] تم إرسال التنبيهات');
      return true;
    } catch (e, stackTrace) {
      AppLogger.error('[FCM] فشل إرسال التنبيهات', e, stackTrace);
      return false;
    }
  }

  /// الحصول على إحصائيات الإشعارات
  Future<Map<String, dynamic>?> getNotificationStats({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      AppLogger.info('[FCM] جاري جلب إحصائيات الإشعارات');

      final callable = _functions.httpsCallable('getNotificationStats');

      final result = await callable.call({
        if (startDate != null) 'startDate': startDate.toIso8601String(),
        if (endDate != null) 'endDate': endDate.toIso8601String(),
      });

      final data = result.data as Map<String, dynamic>;

      AppLogger.success('[FCM] تم جلب الإحصائيات');
      return data;
    } catch (e, stackTrace) {
      AppLogger.error('[FCM] فشل جلب الإحصائيات', e, stackTrace);
      return null;
    }
  }

  // ==================== إدارة التوكنات ====================

  /// حفظ FCM Token لجهة اتصال
  Future<bool> saveContactFCMToken({
    required String userId,
    required String contactId,
    required String fcmToken,
  }) async {
    try {
      AppLogger.info('[FCM] حفظ توكن لجهة اتصال: $contactId');

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('contacts')
          .doc(contactId)
          .update({
        'fcmToken': fcmToken,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      });

      AppLogger.success('[FCM] تم حفظ التوكن');
      return true;
    } catch (e, stackTrace) {
      AppLogger.error('[FCM] فشل حفظ التوكن', e, stackTrace);
      return false;
    }
  }

  /// حذف FCM Token لجهة اتصال
  Future<bool> removeContactFCMToken({
    required String userId,
    required String contactId,
  }) async {
    try {
      AppLogger.info('[FCM] حذف توكن لجهة اتصال: $contactId');

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('contacts')
          .doc(contactId)
          .update({
        'fcmToken': FieldValue.delete(),
      });

      AppLogger.success('[FCM] تم حذف التوكن');
      return true;
    } catch (e, stackTrace) {
      AppLogger.error('[FCM] فشل حذف التوكن', e, stackTrace);
      return false;
    }
  }

  // ==================== Getters ====================

  /// الحصول على التوكن
  String? get fcmToken => _fcmToken;

  /// الاشتراك في topics المستخدم
  Future<void> subscribeToUserTopics(String userId) async {
    await subscribeToTopic('user_$userId');
    await subscribeToTopic('alerts');
  }

  /// إلغاء الاشتراك من topics المستخدم
  Future<void> unsubscribeFromUserTopics(String userId) async {
    await unsubscribeFromTopic('user_$userId');
  }

  /// التحقق من توفر FCM
  bool get isAvailable => _fcmToken != null;

  /// معلومات الخدمة
  Map<String, dynamic> getInfo() {
    return {
      'fcmToken': _fcmToken?.substring(0, 20),
      'isAvailable': isAvailable,
    };
  }
}