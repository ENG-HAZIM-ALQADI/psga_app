import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:psga_app/core/services/connectivity_service.dart';
import 'package:psga_app/core/services/email_service.dart';
import 'package:psga_app/core/services/notification_service.dart';
import 'package:psga_app/core/services/sms_service.dart';
import 'package:psga_app/core/utils/logger.dart';
import 'package:psga_app/features/alerts/domain/entities/alert_config_entity.dart';
import 'package:psga_app/features/alerts/domain/entities/alert_entity.dart';
import 'package:psga_app/features/alerts/domain/entities/contact_entity.dart';

/// نوع التصعيد
enum EscalationLevel {
  internal,  // المستوى الأول: تنبيه داخلي
  fcm,       // المستوى الثاني: FCM للجهات
  sms,       // المستوى الثالث: SMS
}

/// خدمة التصعيد التلقائي للتنبيهات
/// 
/// تدير نظام التصعيد متعدد المستويات:
/// 1. تنبيه داخلي (عد تنازلي 30 ثانية)
/// 2. إشعارات FCM (لجهات الاتصال)
/// 3. رسائل SMS (backup أو offline)
class AlertEscalationService {
  static AlertEscalationService? _instance;
  static AlertEscalationService get instance => _instance ??= AlertEscalationService._();
  
  AlertEscalationService._();

  final EmailService _email = EmailService.instance;
  final SMSService _sms = SMSService.instance;
  final NotificationService _notification = NotificationService.instance;
  final ConnectivityService _connectivity = ConnectivityService.instance;

  // Timers نشطة حسب alert ID
  final Map<String, Timer> _activeTimers = {};
  
  // Callbacks للـ UI
  final Map<String, void Function(EscalationLevel)> _escalationCallbacks = {};
  final Map<String, void Function(int)> _countdownCallbacks = {};
  final Map<String, void Function()> _cancelledCallbacks = {};

  // ==================== Public API ====================

  /// بدء عملية التصعيد لتنبيه
  Future<void> startEscalation({
    required AlertEntity alert,
    required AlertConfigEntity config,
    required List<ContactEntity> contacts,
    Duration? countdownDuration,
    void Function(EscalationLevel)? onEscalation,
    void Function(int)? onCountdownTick,
    void Function()? onCancelled,
  }) async {
    try {
      AppLogger.start('[Escalation] بدء التصعيد للتنبيه: ${alert.id}');

      // إلغاء أي timer سابق لنفس التنبيه
      cancelEscalation(alert.id);

      // حفظ callbacks
      if (onEscalation != null) {
        _escalationCallbacks[alert.id] = onEscalation;
      }
      if (onCountdownTick != null) {
        _countdownCallbacks[alert.id] = onCountdownTick;
      }
      if (onCancelled != null) {
        _cancelledCallbacks[alert.id] = onCancelled;
      }

      // المستوى 1: تنبيه داخلي
      await _executeInternalAlert(alert, config);
      _notifyEscalation(alert.id, EscalationLevel.internal);

      // بدء العد التنازلي
      final duration = countdownDuration ?? 
                      config.getConfigForType(alert.type)?.escalationThreshold ??
                      const Duration(seconds: 30);

      await _startCountdown(
        alertId: alert.id,
        duration: duration,
        onComplete: () async {
          // المستوى 2 & 3: FCM + SMS
          await _executeLevel2And3(alert, config, contacts);
        },
      );

      AppLogger.success('[Escalation] اكتمل التصعيد للتنبيه: ${alert.id}');
    } catch (e, stackTrace) {
      AppLogger.error('[Escalation] فشل التصعيد', e, stackTrace);
      rethrow;
    }
  }

  /// إلغاء التصعيد (عند ضغط "أنا بخير")
  void cancelEscalation(String alertId) {
    AppLogger.info('[Escalation] إلغاء التصعيد: $alertId');

    // إيقاف Timer
    _activeTimers[alertId]?.cancel();
    _activeTimers.remove(alertId);

    // تنفيذ callback
    _cancelledCallbacks[alertId]?.call();

    // تنظيف
    _escalationCallbacks.remove(alertId);
    _countdownCallbacks.remove(alertId);
    _cancelledCallbacks.remove(alertId);

    AppLogger.success('[Escalation] تم الإلغاء: $alertId');
  }

  /// إرسال SOS فوري (بدون عد تنازلي)
  Future<Map<String, dynamic>> sendImmediateSOS({
    required AlertEntity alert,
    required List<ContactEntity> contacts,
    required AlertConfigEntity config,
  }) async {
    try {
      AppLogger.start('[Escalation] إرسال SOS فوري');

      final results = {
        'internal': false,
        'fcm': false,
        'sms': false,
        'email': false,
        'fcmCount': 0,
        'smsCount': 0,
        'emailCount': 0,
      };

      // المستوى 1: تنبيه داخلي
      await _executeInternalAlert(alert, config);
      results['internal'] = true;

      // المستوى 2: FCM
      if (_connectivity.isConnected) {
        final fcmResult = await _sendFCMNotifications(alert, contacts);
        results['fcm'] = fcmResult['success'] ?? false;
        results['fcmCount'] = fcmResult['count'] ?? 0;
      }

      // المستوى 3: SMS (دائماً للـ SOS)
      final smsResult = await _sendSMSAlerts(alert, contacts);
      results['sms'] = smsResult;
      results['smsCount'] = contacts.where((c) => c.canSendSMS).length;

      // ✅ Email (للـ SOS إذا كان متصل)
      if (_connectivity.isConnected) {
        final emailResult = await _sendEmailAlerts(alert, contacts);
        results['email'] = emailResult;
        results['emailCount'] = contacts.where((c) => c.canSendEmail).length;
      }

      AppLogger.success('[Escalation] اكتمل SOS الفوري');
      return results;
    } catch (e, stackTrace) {
      AppLogger.error('[Escalation] فشل SOS الفوري', e, stackTrace);
      return {'error': e.toString()};
    }
  }

  /// التحقق من وجود تصعيد نشط
  bool hasActiveEscalation(String alertId) {
    return _activeTimers.containsKey(alertId);
  }

  /// الحصول على الوقت المتبقي للتصعيد
  Duration? getRemainingTime(String alertId) {
    // يحتاج تتبع أفضل - TODO
    return null;
  }

  // ==================== Private Methods ====================

  /// المستوى 1: تنبيه داخلي
  Future<void> _executeInternalAlert(
    AlertEntity alert,
    AlertConfigEntity config,
  ) async {
    try {
      AppLogger.info('[Escalation] المستوى 1: تنبيه داخلي');

      final typeConfig = config.getConfigForType(alert.type);

      // صوت
      if (typeConfig?.playSoundAlert ?? true) {
        await _notification.playAlertSound(alert.severity);
      }

      // اهتزاز
      if (typeConfig?.vibrateAlert ?? true) {
        await _notification.vibrate(alert.severity);
      }

      // إشعار محلي
      await _notification.showLocalNotification(
        title: alert.title,
        body: alert.message,
        payload: alert.id,
      );

      AppLogger.success('[Escalation] تم المستوى 1');
    } catch (e) {
      AppLogger.error('[Escalation] فشل المستوى 1', e);
    }
  }

  /// المستوى 2 & 3: FCM + SMS + Email
  Future<void> _executeLevel2And3(
    AlertEntity alert,
    AlertConfigEntity config,
    List<ContactEntity> contacts,
  ) async {
    try {
      AppLogger.info('[Escalation] المستوى 2 & 3: FCM + SMS + Email');

      final typeConfig = config.getConfigForType(alert.type);

      // المستوى 2: FCM
      if (_connectivity.isConnected && (typeConfig?.sendPushNotification ?? true)) {
        _notifyEscalation(alert.id, EscalationLevel.fcm);
        await _sendFCMNotifications(alert, contacts);
      }

      // المستوى 3: SMS
      if (typeConfig?.sendSMS ?? true) {
        _notifyEscalation(alert.id, EscalationLevel.sms);
        await _sendSMSAlerts(alert, contacts);
      }

      // ✅ Email (جديد)
      if (_connectivity.isConnected && (typeConfig?.sendEmail ?? true)) {
        AppLogger.info('[Escalation] إرسال Email');
        await _sendEmailAlerts(alert, contacts);
      }

      AppLogger.success('[Escalation] اكتمل المستوى 2 & 3');
    } catch (e) {
      AppLogger.error('[Escalation] فشل المستوى 2 & 3', e);
    }
  }

  /// بدء عد تنازلي
  Future<void> _startCountdown({
    required String alertId,
    required Duration duration,
    required VoidCallback onComplete,
  }) async {
    AppLogger.info('[Escalation] بدء عد تنازلي: ${duration.inSeconds}s');

    int remainingSeconds = duration.inSeconds;

    final timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (remainingSeconds <= 0) {
        timer.cancel();
        _activeTimers.remove(alertId);
        onComplete();
        return;
      }

      // إرسال tick للـ UI
      _countdownCallbacks[alertId]?.call(remainingSeconds);
      remainingSeconds--;
    });

    _activeTimers[alertId] = timer;
  }

  /// إرسال إشعارات FCM
  Future<Map<String, dynamic>> _sendFCMNotifications(
    AlertEntity alert,
    List<ContactEntity> contacts,
  ) async {
    try {
      AppLogger.start('[Escalation] إرسال FCM لـ ${contacts.length} جهة');

      // فلترة الجهات التي تستقبل push notifications
      final eligibleContacts = contacts
          .where((c) => c.receivesPushNotification)
          .toList();

      if (eligibleContacts.isEmpty) {
        AppLogger.warning('[Escalation] لا توجد جهات لإرسال FCM');
        return {'success': false, 'count': 0};
      }

      // استخدام Cloud Function لإرسال الإشعارات
      // (التنبيه محفوظ في Firestore وCloud Function سترسل تلقائياً)
      AppLogger.info('[Escalation] الإشعارات ستُرسل عبر Cloud Function');

      return {
        'success': true,
        'count': eligibleContacts.length,
      };
    } catch (e, stackTrace) {
      AppLogger.error('[Escalation] فشل إرسال FCM', e, stackTrace);
      return {'success': false, 'error': e.toString()};
    }
  }

  /// إرسال رسائل SMS
  Future<bool> _sendSMSAlerts(
    AlertEntity alert,
    List<ContactEntity> contacts,
  ) async {
    try {
      AppLogger.start('[Escalation] إرسال SMS');

      final eligibleContacts = contacts
          .where((c) => c.canSendSMS)
          .toList();

      if (eligibleContacts.isEmpty) {
        AppLogger.warning('[Escalation] لا توجد جهات لإرسال SMS');
        return false;
      }

      // اختيار الطريقة المناسبة حسب نوع التنبيه
      bool result;
      if (alert.type == AlertType.sos) {
        result = await _sms.sendSOSAlert(
          alert: alert,
          contacts: eligibleContacts,
        );
      } else if (alert.type == AlertType.deviation) {
        result = await _sms.sendDeviationAlert(
          alert: alert,
          contacts: eligibleContacts,
        );
      } else {
        result = await _sms.sendGeneralAlert(
          alert: alert,
          contacts: eligibleContacts,
        );
      }

      if (result) {
        AppLogger.success('[Escalation] تم إرسال SMS');
      } else {
        AppLogger.warning('[Escalation] فشل إرسال SMS');
      }

      return result;
    } catch (e, stackTrace) {
      AppLogger.error('[Escalation] خطأ في إرسال SMS', e, stackTrace);
      return false;
    }
  }

  /// إرسال Email alerts
  Future<bool> _sendEmailAlerts(
    AlertEntity alert,
    List<ContactEntity> contacts,
  ) async {
    try {
      AppLogger.start('[Escalation] إرسال Email');

      final eligibleContacts = contacts
          .where((c) => c.canSendEmail && c.email != null && c.email!.isNotEmpty)
          .toList();

      if (eligibleContacts.isEmpty) {
        AppLogger.warning('[Escalation] لا توجد جهات لإرسال Email');
        return false;
      }

      // اختيار الطريقة المناسبة حسب نوع التنبيه
      bool result;
      if (alert.type == AlertType.sos) {
        result = await _email.sendSOSAlert(
          alert: alert,
          contacts: eligibleContacts,
        );
      } else if (alert.type == AlertType.deviation) {
        result = await _email.sendDeviationAlert(
          alert: alert,
          contacts: eligibleContacts,
        );
      } else {
        result = await _email.sendGeneralAlert(
          alert: alert,
          contacts: eligibleContacts,
        );
      }

      if (result) {
        AppLogger.success('[Escalation] تم إرسال Email لـ ${eligibleContacts.length} جهة');
      } else {
        AppLogger.warning('[Escalation] فشل إرسال Email');
      }

      return result;
    } catch (e, stackTrace) {
      AppLogger.error('[Escalation] خطأ في إرسال Email', e, stackTrace);
      return false;
    }
  }

  /// إخطار التصعيد للـ UI
  void _notifyEscalation(String alertId, EscalationLevel level) {
    _escalationCallbacks[alertId]?.call(level);
    
    String levelName;
    switch (level) {
      case EscalationLevel.internal:
        levelName = 'داخلي';
        break;
      case EscalationLevel.fcm:
        levelName = 'FCM';
        break;
      case EscalationLevel.sms:
        levelName = 'SMS';
        break;
    }
    
    AppLogger.info('[Escalation] تصعيد للمستوى: $levelName');
  }

  // ==================== Utility ====================

  /// تنظيف جميع الـ timers
  void dispose() {
    AppLogger.info('[Escalation] تنظيف جميع الـ timers');
    
    for (final timer in _activeTimers.values) {
      timer.cancel();
    }
    
    _activeTimers.clear();
    _escalationCallbacks.clear();
    _countdownCallbacks.clear();
    _cancelledCallbacks.clear();
  }

  /// معلومات عن التصعيدات النشطة
  Map<String, dynamic> getActiveEscalations() {
    return {
      'count': _activeTimers.length,
      'alertIds': _activeTimers.keys.toList(),
    };
  }
}
