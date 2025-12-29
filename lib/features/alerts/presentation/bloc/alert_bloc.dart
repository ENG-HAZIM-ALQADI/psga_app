import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/utils/logger.dart';
import '../../domain/entities/alert_entity.dart';
import '../../domain/repositories/alert_repository.dart';
import '../../domain/repositories/contact_repository.dart';
import '../../domain/usecases/trigger_alert_usecase.dart';
import '../../domain/usecases/acknowledge_alert_usecase.dart';
import '../../domain/usecases/cancel_alert_usecase.dart';
import '../../domain/usecases/escalate_alert_usecase.dart';
import '../../domain/usecases/send_sos_usecase.dart';
import '../../domain/usecases/get_alert_history_usecase.dart';
import '../../data/services/notification_service.dart';
import '../../data/services/fcm_service.dart';
import '../../data/services/sms_service.dart';
import 'alert_event.dart';
import 'alert_state.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// 🚨 AlertBloc - إدارة نظام الطوارئ والتنبيهات (Presentation Layer)
/// ═══════════════════════════════════════════════════════════════════════════
///
/// الهدف من هذا الملف:
/// يدير نظام التنبيهات والطوارئ الكاملة
///
/// المسؤوليات:
/// 1. إطلاق تنبيه عام (Trigger Alert)
/// 2. تصعيد التنبيه (Escalate Alert - إرسال لعدد أكثر من الأشخاص)
/// 3. إرسال نداء استغاثة فوري (SOS - الحالة القصوى!)
/// 4. قبول التنبيه (Acknowledge - تم التأكد من الأمان)
/// 5. إلغاء التنبيه (Cancel Alert)
/// 6. تحميل سجل التنبيهات السابقة
/// 7. إدارة العد التنازلي (Countdown - إذا لم يرد أحد خلال 30 ثانية = تصعيد)
///
/// مستويات الخطورة:
/// 🟢 Low: تنبيه بسيط (لا يوجد خطر فوري)
/// 🟡 Medium: تنبيه متوسط (قد يكون هناك خطر)
/// 🔴 High: تنبيه عالي (خطر فوري!)
/// 🚨 Critical/SOS: الحالة الحرجة (نداء استغاثة)
///
/// حالات التسليم (Delivery Methods):
/// 📲 FCM: إشعارات عبر Firebase Cloud Messaging (حتى لو أغلق التطبيق)
/// 💬 SMS: رسائل نصية (تضمن الوصول حتى بدون إنترنت)
/// 🔔 Notification: إشعار محلي (داخل التطبيق)
/// 📋 All: جميع الطرق معاً
///
/// مثال على دورة حياة التنبيه:
/// ```
/// سيناريو: المستخدم يتحرك بسرعة غير طبيعية (قد يكون في خطر)
///
/// 1. كاميرا الرحلة تكتشف السرعة الغريبة
///    → add(TriggerAlertEvent(...))
///
/// 2. AlertBloc يستدعي triggerAlertUseCase
///    → إنشاء تنبيه
///    → حفظه في Hive/Firebase
///    → emit(AlertCountingDown) ← عد تنازلي 30 ثانية
///
/// 3. عرض countdown على الشاشة
///    → "هل أنت بخير؟ إذا لم ترد خلال 30 ثانية = إرسال للجميع"
///
/// 4a. المستخدم ضغط "أنا بخير"
///    → add(AcknowledgeAlertEvent)
///    → alert.status = "acknowledged"
///    → توقف الـ countdown
///
/// 4b. الـ countdown انتهى (30 ثانية)
///    → add(EscalateAlertEvent)
///    → إرسال فوري لجهات الاتصال
///    → emit(AlertEscalated)
///
/// 5. المتلقي (الوالدة أو الشرطة) يرى التنبيه
///    → يمكن الاتصال بالمستخدم أو الحضور للموقع
/// ```
///
/// مثال SOS الطوارئ:
/// ```
/// المستخدم في خطر فعلي → يضغط زر SOS الأحمر
///
/// add(SendSOSEvent(...))
///   ↓
/// emit(SOSSending(5)) ← عد تنازلي 5 ثواني (للإلغاء)
///   ↓
/// بعد 5 ثواني:
///   - إرسال فوري لـ FCM + SMS
///   - إرسال الموقع الحالي
///   - تنبيه جميع جهات الاتصال
///
/// emit(SOSSent) ← نداء الاستغاثة تم إرساله!
/// ```

class AlertBloc extends Bloc<AlertEvent, AlertState> {
  /// 🔗 الاعتماديات
  final AlertRepository alertRepository;
  final ContactRepository contactRepository;
  final TriggerAlertUseCase triggerAlertUseCase;
  final AcknowledgeAlertUseCase acknowledgeAlertUseCase;
  final CancelAlertUseCase cancelAlertUseCase;
  final EscalateAlertUseCase escalateAlertUseCase;
  final SendSOSUseCase sendSOSUseCase;
  final GetAlertHistoryUseCase getAlertHistoryUseCase;
  final NotificationService notificationService;
  final FCMService fcmService;
  final SMSService smsService;

  /// ⏱️ مؤقت العد التنازلي
  /// إذا لم يرد المستخدم خلال فترة زمنية → تصعيد تلقائي
  Timer? _countdownTimer;

  /// 📌 التنبيه الحالي
  /// نحتفظ به للإشارة إليه لاحقاً (عند الإقرار أو الإلغاء)
  AlertEntity? _currentAlert;

  /// ═══════════════════════════════════════════════════════════════════════════
  /// Constructor - تهيئة AlertBloc
  /// ═══════════════════════════════════════════════════════════════════════════
  ///
  /// super(const AlertInitial())
  ///   → الحالة الأولية: "لا يوجد تنبيه نشط"
  ///
  /// on<TriggerAlertEvent>(_onTriggerAlert)
  ///   → ربط حدث إطلاق التنبيه

  AlertBloc({
    required this.alertRepository,
    required this.contactRepository,
    required this.triggerAlertUseCase,
    required this.acknowledgeAlertUseCase,
    required this.cancelAlertUseCase,
    required this.escalateAlertUseCase,
    required this.sendSOSUseCase,
    required this.getAlertHistoryUseCase,
    required this.notificationService,
    required this.fcmService,
    required this.smsService,
  }) : super(const AlertInitial()) {
    /// ربط الأحداث بمعالجاتها
    on<TriggerAlertEvent>(_onTriggerAlert);

    /// إطلاق تنبيه
    on<AcknowledgeAlertEvent>(_onAcknowledgeAlert);

    /// قبول التنبيه
    on<CancelAlertEvent>(_onCancelAlert);

    /// إلغاء التنبيه
    on<EscalateAlertEvent>(_onEscalateAlert);

    /// تصعيد التنبيه
    on<SendSOSEvent>(_onSendSOS);

    /// نداء استغاثة
    on<LoadAlertHistoryEvent>(_onLoadAlertHistory);

    /// سجل التنبيهات
    on<LoadAlertConfigEvent>(_onLoadAlertConfig);

    /// إعدادات التنبيهات
    on<UpdateAlertConfigEvent>(_onUpdateAlertConfig);

    /// تحديث الإعدادات
    on<StartCountdownEvent>(_onStartCountdown);

    /// بدء العد التنازلي
    on<CountdownTickEvent>(_onCountdownTick);

    /// تحديث العداد
    on<StopCountdownEvent>(_onStopCountdown);

    /// إيقاف العد
  }

  /// ═══════════════════════════════════════════════════════════════════════════
  /// 🚨 معالج الحدث: إطلاق تنبيه عام (_onTriggerAlert)
  /// ═══════════════════════════════════════════════════════════════════════════
  ///
  /// متى يتم استدعاء هذه الدالة؟
  /// - رصد سرعة غير طبيعية (خطر محتمل)
  /// - انحراف كبير عن المسار (قد تكون في خطر)
  /// - ضغط المستخدم على زر "تنبيه"
  ///
  /// ما يحدث:
  /// 1️⃣ أنشئ تنبيه وحفظه
  /// 2️⃣ عرض تنبيه محلي: "هل أنت بخير؟"
  /// 3️⃣ بدء عد تنازلي 30 ثانية
  /// 4️⃣ إذا انتهى الوقت → تصعيد تلقائي

  Future<void> _onTriggerAlert(
    TriggerAlertEvent event,
    Emitter<AlertState> emit,
  ) async {
    emit(const AlertLoading());

    /// استدعاء triggerAlertUseCase لإنشاء التنبيه
    final result = await triggerAlertUseCase(TriggerAlertParams(
      tripId: event.tripId ?? '',
      userId: 'current_user',

      /// TODO: احصل على من AuthBloc
      type: event.type,

      /// نوع التنبيه (Speed, Deviation، إلخ)
      level: event.level,

      /// مستوى الخطورة (Low, Medium, High)
      location: event.location,

      /// الموقع الحالي
      message: event.message,

      /// رسالة التنبيه
    ));

    result.fold(
      (failure) => emit(AlertError(failure.message)),
      (alert) {
        /// حفظ التنبيه الحالي
        _currentAlert = alert;

        /// عرض إشعار محلي على الشاشة
        notificationService.showAlertNotification(alert);

        /// بدء عد تنازلي 30 ثانية
        /// إذا لم يقبل المستخدم خلال 30 ثانية → تصعيد
        add(StartCountdownEvent(seconds: 30, alert: alert));
      },
    );
  }

  /// ═══════════════════════════════════════════════════════════════════════════
  /// ✅ معالج الحدث: قبول/إقرار التنبيه (_onAcknowledgeAlert)
  /// ═══════════════════════════════════════════════════════════════════════════
  ///
  /// متى يتم استدعاء هذه الدالة؟
  /// المستخدم ضغط على "أنا بخير" / "تم التأكد من الأمان"
  ///
  /// ما يحدث:
  /// 1️⃣ توقف العد التنازلي فوراً
  /// 2️⃣ تحديث التنبيه: status = "acknowledged"
  /// 3️⃣ إلغاء جميع الإشعارات المفتوحة
  /// 4️⃣ إرسال تنبيه للمتلقين: "المستخدم بخير"
  /// 5️⃣ العودة للحالة الطبيعية

  Future<void> _onAcknowledgeAlert(
    AcknowledgeAlertEvent event,
    Emitter<AlertState> emit,
  ) async {
    /// 1️⃣ توقف العد التنازلي فوراً
    _stopCountdown();

    /// 2️⃣ استدعاء acknowledgeAlertUseCase
    final result = await acknowledgeAlertUseCase(event.alertId);

    result.fold(
      (failure) => emit(AlertError(failure.message)),
      (_) {
        if (_currentAlert != null) {
          /// 3️⃣ تحديث بيانات التنبيه
          final acknowledgedAlert = _currentAlert!.copyWith(
            status: AlertStatus.acknowledged,
            acknowledgedAt: DateTime.now(),
          );

          /// 4️⃣ إلغاء الإشعارات
          notificationService.cancelAllNotifications();

          /// 5️⃣ إرسال حالة الإقرار
          emit(AlertAcknowledged(acknowledgedAlert));

          /// 6️⃣ مسح التنبيه الحالي
          _currentAlert = null;
        }
      },
    );
  }

  /// ═══════════════════════════════════════════════════════════════════════════
  /// ❌ معالج الحدث: إلغاء التنبيه (_onCancelAlert)
  /// ═══════════════════════════════════════════════════════════════════════════
  ///
  /// متى يتم استدعاء هذه الدالة؟
  /// المستخدم ضغط على "إلغاء التنبيه"
  /// (تنبيه خاطئ أو لا يريد التصعيد)
  ///
  /// ما يحدث:
  /// 1️⃣ توقف العد التنازلي
  /// 2️⃣ حذف التنبيه من قاعدة البيانات
  /// 3️⃣ إلغاء جميع الإشعارات
  /// 4️⃣ العودة للحالة الطبيعية

  Future<void> _onCancelAlert(
    CancelAlertEvent event,
    Emitter<AlertState> emit,
  ) async {
    _stopCountdown();

    /// استدعاء cancelAlertUseCase
    final result = await cancelAlertUseCase(event.alert);

    result.fold(
      (failure) => emit(AlertError(failure.message)),
      (_) {
        /// إلغاء الإشعارات
        notificationService.cancelAllNotifications();

        /// مسح التنبيه الحالي
        _currentAlert = null;

        /// العودة للحالة الأولية
        emit(const AlertInitial());
      },
    );
  }

  /// ═══════════════════════════════════════════════════════════════════════════
  /// 📢 معالج الحدث: تصعيد التنبيه (_onEscalateAlert)
  /// ═══════════════════════════════════════════════════════════════════════════
  ///
  /// متى يتم استدعاء هذه الدالة؟
  /// 1️⃣ العد التنازلي 30 ثانية انتهى ولم يرد المستخدم
  /// 2️⃣ المستخدم ضغط على "تصعيد التنبيه"
  ///
  /// ما يحدث:
  /// 1️⃣ تصعيد التنبيه (إرسال لعدد أكبر من الأشخاص)
  /// 2️⃣ إرسال عبر جميع القنوات:
  ///    - FCM (إشعارات)
  ///    - SMS (رسائل نصية)
  /// 3️⃣ إرسال الموقع الحالي
  /// 4️⃣ إرسال معلومات المستخدم والرحلة
  /// 5️⃣ إنهاء العد التنازلي

  Future<void> _onEscalateAlert(
    EscalateAlertEvent event,
    Emitter<AlertState> emit,
  ) async {
    /// استدعاء escalateAlertUseCase
    final result = await escalateAlertUseCase(EscalateAlertParams(
      alertId: event.alert.id,
      currentAlert: event.alert,
    ));

    await result.fold(
      (failure) async => emit(AlertError(failure.message)),
      (escalatedAlert) async {
        /// حفظ التنبيه المصعد
        _currentAlert = escalatedAlert;

        /// جلب قائمة جهات الاتصال
        final contactsResult =
            await contactRepository.getContacts('current_user');
        contactsResult.fold(
          (failure) => AppLogger.error('[Alert] فشل في جلب جهات الاتصال'),
          (contacts) async {
            /// إرسال عبر FCM إذا كان محدد أو "All"
            if (escalatedAlert.deliveryMethod == DeliveryMethod.fcm ||
                escalatedAlert.deliveryMethod == DeliveryMethod.all) {
              await fcmService.sendAlertToContacts(
                escalatedAlert,
                contacts,
                'المستخدم',
              );
            }

            /// إرسال عبر SMS إذا كان محدد أو "All"
            if (escalatedAlert.deliveryMethod == DeliveryMethod.sms ||
                escalatedAlert.deliveryMethod == DeliveryMethod.all) {
              await smsService.sendEmergencySMS(
                escalatedAlert,
                contacts,
                'المستخدم',
              );
            }
          },
        );

        /// إرسال حالة: تم التصعيد
        emit(AlertEscalated(escalatedAlert));
      },
    );
  }

  /// ═══════════════════════════════════════════════════════════════════════════
  /// 🆘 معالج الحدث: نداء استغاثة (_onSendSOS)
  /// ═══════════════════════════════════════════════════════════════════════════
  ///
  /// متى يتم استدعاء هذه الدالة؟
  /// المستخدم في خطر فعلي وضغط زر SOS الأحمر!
  /// (الحالة الحرجة)
  ///
  /// ما يحدث:
  /// 1️⃣ عرض عد تنازلي 5 ثواني (للإلغاء قبل الإرسال)
  /// 2️⃣ بعد 5 ثواني: إرسال فوري!
  /// 3️⃣ إرسال لـ جميع جهات الاتصال عبر:
  ///    - FCM (فوري)
  ///    - SMS (مضمون)
  /// 4️⃣ إرسال الموقع الحالي
  /// 5️⃣ إرسال رقم هاتف المستخدم
  /// 6️⃣ تنبيه الشرطة تلقائياً (حسب الإعدادات)

  Future<void> _onSendSOS(
    SendSOSEvent event,
    Emitter<AlertState> emit,
  ) async {
    /// عرض: "جاري الإرسال خلال 5 ثواني - اضغط إلغاء للتراجع"
    emit(const SOSSending(5));

    /// استدعاء sendSOSUseCase
    final result = await sendSOSUseCase(SendSOSParams(
      userId: 'current_user',
      location: event.location,
    ));

    await result.fold(
      (failure) async => emit(AlertError(failure.message)),
      (alert) async {
        /// حفظ التنبيه
        _currentAlert = alert;

        /// جلب جهات الاتصال
        final contactsResult =
            await contactRepository.getContacts('current_user');
        final notifiedContacts = <String>[];

        await contactsResult.fold(
          (failure) async => AppLogger.error('[SOS] فشل في جلب جهات الاتصال'),
          (contacts) async {
            /// جمع أسماء جهات الاتصال المخطرة
            for (final contact in contacts) {
              notifiedContacts.add(contact.name);
            }

            /// إرسال عبر جميع القنوات
            await fcmService.sendAlertToContacts(alert, contacts, 'المستخدم');
            await smsService.sendEmergencySMS(alert, contacts, 'المستخدم');
          },
        );

        /// عرض إشعار محلي
        await notificationService.showAlertNotification(alert);

        /// إرسال حالة: تم إرسال SOS
        /// الواجهة ستعرض: "تم إرسال نداء الاستغاثة للمخاوضين"
        emit(SOSSent(alert: alert, notifiedContacts: notifiedContacts));
      },
    );
  }

  /// ═══════════════════════════════════════════════════════════════════════════
  /// 📜 معالج الحدث: تحميل سجل التنبيهات (_onLoadAlertHistory)
  /// ═══════════════════════════════════════════════════════════════════════════
  ///
  /// متى يتم استدعاء هذه الدالة؟
  /// المستخدم فتح صفحة "سجل التنبيهات"
  ///
  /// المعاملات:
  /// - typeFilter: نوع التنبيهات (Speed, Deviation، إلخ)
  /// - statusFilter: الحالة (Pending, Acknowledged، إلخ)
  /// - limit: عدد التنبيهات المطلوبة

  Future<void> _onLoadAlertHistory(
    LoadAlertHistoryEvent event,
    Emitter<AlertState> emit,
  ) async {
    emit(const AlertLoading());

    /// جلب سجل التنبيهات
    final result = await getAlertHistoryUseCase(GetAlertHistoryParams(
      userId: 'current_user',
      limit: event.limit,
      typeFilter: event.typeFilter,
      statusFilter: event.statusFilter,
    ));

    result.fold(
      (failure) => emit(AlertError(failure.message)),
      (alerts) => emit(AlertHistoryLoaded(alerts)),
    );
  }

  /// ═══════════════════════════════════════════════════════════════════════════
  /// ⚙️ معالج الحدث: تحميل إعدادات التنبيه (_onLoadAlertConfig)
  /// ═══════════════════════════════════════════════════════════════════════════

  Future<void> _onLoadAlertConfig(
    LoadAlertConfigEvent event,
    Emitter<AlertState> emit,
  ) async {
    emit(const AlertLoading());

    final result = await alertRepository.getAlertConfig('current_user');

    result.fold(
      (failure) => emit(AlertError(failure.message)),
      (config) => emit(AlertConfigLoaded(config)),
    );
  }

  /// ═══════════════════════════════════════════════════════════════════════════
  /// 🔧 معالج الحدث: تحديث إعدادات التنبيه (_onUpdateAlertConfig)
  /// ═══════════════════════════════════════════════════════════════════════════

  Future<void> _onUpdateAlertConfig(
    UpdateAlertConfigEvent event,
    Emitter<AlertState> emit,
  ) async {
    final result = await alertRepository.updateAlertConfig(event.config);

    result.fold(
      (failure) => emit(AlertError(failure.message)),
      (_) => emit(AlertConfigLoaded(event.config)),
    );
  }

  /// ═══════════════════════════════════════════════════════════════════════════
  /// ⏱️ معالج الحدث: بدء العد التنازلي (_onStartCountdown)
  /// ═══════════════════════════════════════════════════════════════════════════
  ///
  /// الهدف: عد تنازلي 30 ثانية قبل التصعيد التلقائي
  ///
  /// الآلية:
  /// 1️⃣ عرض: "30 ثانية قبل إرسال التنبيه لجميع المخاوضين"
  /// 2️⃣ كل ثانية: تحديث العداد
  /// 3️⃣ عندما يصل الصفر: تصعيد تلقائي

  void _onStartCountdown(
    StartCountdownEvent event,
    Emitter<AlertState> emit,
  ) {
    /// توقف أي عد سابق
    _stopCountdown();

    AppLogger.info('[Alert] بدء العد التنازلي: ${event.seconds} ثانية',
        name: 'AlertBloc');

    /// عرض حالة العد التنازلي
    emit(AlertCountingDown(
      alert: event.alert,
      remainingSeconds: event.seconds,
    ));

    /// إنشاء Timer دوري
    /// كل ثانية: أنقص العداد
    _countdownTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        final remaining = event.seconds - timer.tick;

        /// هل انتهى الوقت؟
        if (remaining <= 0) {
          /// توقف المؤقت
          timer.cancel();

          /// تصعيد تلقائي
          AppLogger.warning('[Alert] ⏰ انتهى الوقت - تصعيد تلقائي!',
              name: 'AlertBloc');
          add(EscalateAlertEvent(event.alert));
        } else {
          /// تحديث العداد
          add(CountdownTickEvent(remaining));
        }
      },
    );
  }

  /// ═══════════════════════════════════════════════════════════════════════════
  /// 🔔 معالج الحدث: تحديث العد التنازلي (_onCountdownTick)
  /// ═══════════════════════════════════════════════════════════════════════════
  ///
  /// الهدف: تحديث الواجهة كل ثانية مع العداد الجديد

  void _onCountdownTick(
    CountdownTickEvent event,
    Emitter<AlertState> emit,
  ) {
    /// إذا كانت الحالة الحالية هي countdown
    final currentState = state;
    if (currentState is AlertCountingDown) {
      /// حدّث العداد فقط (بدون إعادة بناء كامل الواجهة)
      emit(currentState.copyWith(remainingSeconds: event.remainingSeconds));
    }
  }

  /// ═══════════════════════════════════════════════════════════════════════════
  /// 🛑 معالج الحدث: إيقاف العد التنازلي (_onStopCountdown)
  /// ═══════════════════════════════════════════════════════════════════════════

  void _onStopCountdown(
    StopCountdownEvent event,
    Emitter<AlertState> emit,
  ) {
    _stopCountdown();
  }

  /// دالة مساعدة: إيقاف المؤقت
  void _stopCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
  }

  /// ═══════════════════════════════════════════════════════════════════════════
  /// 🧹 تنظيف الموارد (Close)
  /// ═══════════════════════════════════════════════════════════════════════════
  ///
  /// متى يتم استدعاء هذه الدالة؟
  /// عند إغلاق BLoC (مثل: المستخدم أغلق التطبيق)
  ///
  /// الهدف: تنظيف الموارد (توقف المؤقتات، إغلاق Streams)

  @override
  Future<void> close() {
    /// توقف المؤقت قبل الإغلاق
    _stopCountdown();
    return super.close();
  }
}
