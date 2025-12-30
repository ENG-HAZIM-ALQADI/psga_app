import 'package:equatable/equatable.dart';
import '../../../trips/domain/entities/location_entity.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// 🚨 AlertType - أنواع التنبيهات
/// ═══════════════════════════════════════════════════════════════════════════
///
/// 💡 ما هو Enum؟
/// Enum = مجموعة ثابتة من القيم المحتملة
/// بدلاً من استخدام Strings (التي قد تُكتب بشكل خاطئ)، نستخدم Enum
///
/// ❌ بدون Enum:
/// ```dart
/// String alertType = "devation";  // خطأ إملائي!
/// if (alertType == "deviation") { ... }  // لن يعمل!
/// ```
///
/// ✅ مع Enum:
/// ```dart
/// AlertType type = AlertType.deviation;  // آمن!
/// if (type == AlertType.deviation) { ... }  // يعمل!
/// ```
enum AlertType {
  /// 🛣️ انحراف عن المسار المحدد
  /// يُطلق عندما يخرج المستخدم عن الطريق المحدد
  deviation,

  /// 🆘 إشارة استغاثة (SOS)
  /// يُطلق يدوياً من قبل المستخدم عند الطوارئ
  sos,

  /// ⏱️ عدم حركة (Inactivity)
  /// يُطلق عندما لا يتحرك المستخدم لفترة معينة
  inactivity,

  /// 🔋 بطارية منخفضة
  /// يُطلق عندما تنخفض البطارية عن حد معين
  lowBattery,

  /// 📡 انقطاع الاتصال
  /// يُطلق عندما ينقطع الإنترنت لفترة طويلة
  noConnection,
}

/// ═══════════════════════════════════════════════════════════════════════════
/// ⚠️ AlertLevel - مستويات خطورة التنبيه
/// ═══════════════════════════════════════════════════════════════════════════
///
/// 💡 لماذا نحتاج مستويات؟
/// - تحديد أولوية التنبيه
/// - اختيار طريقة الإرسال (منخفض = in-app، عالي = SMS)
/// - تحديد من سيُشعر (منخفض = المستخدم فقط، حرج = جميع جهات الاتصال)
///
/// 🎯 متى نستخدم كل مستوى؟
///
/// ```dart
/// // مثال 1: انحراف بسيط (5 أمتار)
/// AlertLevel.low
///
/// // مثال 2: انحراف متوسط (50 متر)
/// AlertLevel.medium
///
/// // مثال 3: انحراف كبير (500 متر)
/// AlertLevel.high
///
/// // مثال 4: SOS أو حادث
/// AlertLevel.critical
/// ```
enum AlertLevel {
  /// 🟢 منخفض - معلومة فقط
  /// - إشعار في التطبيق فقط
  /// - لا يُرسل لجهات الاتصال
  low,

  /// 🟡 متوسط - تحذير
  /// - إشعار + صوت
  /// - قد يُرسل لجهة اتصال واحدة
  medium,

  /// 🟠 عالي - خطر
  /// - إشعار + صوت + اهتزاز
  /// - يُرسل لجهات الاتصال الرئيسية
  high,

  /// 🔴 حرج - طوارئ
  /// - جميع طرق التنبيه
  /// - يُرسل لجميع جهات الاتصال
  /// - اتصال تلقائي بالطوارئ
  critical,
}

/// ═══════════════════════════════════════════════════════════════════════════
/// 📊 AlertStatus - حالة التنبيه
/// ═══════════════════════════════════════════════════════════════════════════
///
/// 💡 دورة حياة التنبيه:
/// ```
/// pending → active → acknowledged → resolved
///              ↓
///          escalated
/// ```
enum AlertStatus {
  /// ⏳ في الانتظار - تم إنشاؤه لكن لم يُرسل بعد
  pending,

  /// 🔔 نشط - تم إرساله وينتظر رد
  active,

  /// ✅ تم الإقرار - شاهده المستخدم أو جهة الاتصال
  acknowledged,

  /// ⬆️ تم التصعيد - زاد مستوى الخطورة
  escalated,

  /// ✔️ تم الحل - انتهى التنبيه بنجاح
  resolved,

  /// ⏰ منتهي - انتهى الوقت بدون رد
  expired,
}

/// ═══════════════════════════════════════════════════════════════════════════
/// 📨 DeliveryMethod - طرق إيصال التنبيه
/// ═══════════════════════════════════════════════════════════════════════════
///
/// 💡 اختيار الطريقة حسب المستوى:
/// - low → inApp فقط
/// - medium → inApp + FCM
/// - high → inApp + FCM + SMS
/// - critical → all (كل شيء!)
enum DeliveryMethod {
  /// 📱 داخل التطبيق فقط
  inApp,

  /// 🔔 Firebase Cloud Messaging (Push Notification)
  fcm,

  /// 💬 رسالة نصية (SMS)
  sms,

  /// 🌐 جميع الطرق
  all,
}

/// ═══════════════════════════════════════════════════════════════════════════
/// 🚨 AlertEntity - كيان التنبيه (Business Logic)
/// ═══════════════════════════════════════════════════════════════════════════
///
/// 🎯 الموقع في Clean Architecture:
/// ```
/// features/alerts/
///   ├── domain/
///   │   ├── entities/
///   │   │   └── alert_entity.dart ← ← ← أنت هنا! (Domain Layer)
///   │   ├── repositories/
///   │   └── usecases/
///   ├── data/
///   └── presentation/
/// ```
///
/// 📌 ما هو Entity؟
/// Entity هو "الكيان النقي" في Domain Layer:
/// - يحتوي فقط على Business Logic
/// - لا يعرف شيئاً عن Firebase أو Hive أو UI
/// - مستقل تماماً عن التقنيات المستخدمة
/// - يمثل المفهوم الأساسي في النطاق (Domain)
///
/// 💡 لماذا Equatable؟
/// Equatable يسمح لنا بمقارنة الـ Entities:
/// ```dart
/// final alert1 = AlertEntity(id: '1', ...);
/// final alert2 = AlertEntity(id: '1', ...);
///
/// // بدون Equatable:
/// alert1 == alert2  // ❌ false (كائنات مختلفة في الذاكرة)
///
/// // مع Equatable:
/// alert1 == alert2  // ✅ true (نفس القيم)
/// ```
///
/// 🔄 دورة حياة Alert كاملة:
///
/// **1️⃣ إنشاء Alert (في UseCase):**
/// ```dart
/// final alert = AlertEntity(
///   id: generateId(),
///   tripId: currentTrip.id,
///   userId: currentUser.id,
///   type: AlertType.deviation,
///   level: AlertLevel.medium,
///   status: AlertStatus.pending,
///   location: currentLocation,
///   message: 'انحراف 50 متر عن المسار',
///   triggeredAt: DateTime.now(),
/// );
/// ```
///
/// **2️⃣ إرسال Alert (في Repository):**
/// ```dart
/// final result = await alertRepository.createAlert(alert);
/// ```
///
/// **3️⃣ تحديث Status (بعد الإرسال):**
/// ```dart
/// final updatedAlert = alert.copyWith(
///   status: AlertStatus.active,
///   sentToContacts: ['contact_1', 'contact_2'],
/// );
/// ```
///
/// **4️⃣ الإقرار (Acknowledge):**
/// ```dart
/// final acknowledgedAlert = alert.copyWith(
///   status: AlertStatus.acknowledged,
///   acknowledgedAt: DateTime.now(),
/// );
/// ```
///
/// **5️⃣ التصعيد (Escalate) - إذا لم يرد أحد:**
/// ```dart
/// final escalatedAlert = alert.copyWith(
///   level: AlertLevel.critical,  // زيادة المستوى
///   status: AlertStatus.escalated,
///   escalatedAt: DateTime.now(),
/// );
/// ```
class AlertEntity extends Equatable {
  /// ═══════════════════════════════════════════════════════════════════════════
  /// 📋 الحقول (Fields)
  /// ═══════════════════════════════════════════════════════════════════════════

  /// معرف فريد للتنبيه
  /// مثال: "alert_1704123456789" أو "sos_1704123456789"
  final String id;

  /// معرف الرحلة المرتبطة (إذا كان ضمن رحلة)
  /// - قد يكون فارغاً للتنبيهات العامة (مثل SOS بدون رحلة)
  final String tripId;

  /// معرف المستخدم صاحب التنبيه
  final String userId;

  /// نوع التنبيه (deviation, sos, إلخ)
  final AlertType type;

  /// مستوى الخطورة (low, medium, high, critical)
  final AlertLevel level;

  /// حالة التنبيه (pending, active, acknowledged, إلخ)
  final AlertStatus status;

  /// موقع المستخدم عند إطلاق التنبيه
  /// - مهم جداً لمعرفة أين حدثت المشكلة
  /// - يُستخدم لإرسال رابط Google Maps لجهات الاتصال
  final LocationEntity location;

  /// رسالة التنبيه
  ///
  /// أمثلة:
  /// ```dart
  /// // Deviation:
  /// "انحراف 50 متر عن المسار المحدد"
  ///
  /// // SOS:
  /// "🚨 تنبيه طوارئ!\nالموقع: https://maps.google.com/..."
  ///
  /// // Inactivity:
  /// "لم يتحرك المستخدم منذ 30 دقيقة"
  ///
  /// // Low Battery:
  /// "البطارية: 10% - قد ينقطع الاتصال قريباً"
  /// ```
  final String message;

  /// وقت إطلاق التنبيه
  final DateTime triggeredAt;

  /// وقت الإقرار (null إذا لم يُقر بعد)
  ///
  /// 💡 متى يتم الإقرار؟
  /// - عندما يفتح المستخدم التنبيه
  /// - عندما تضغط جهة الاتصال "تم الاستلام"
  final DateTime? acknowledgedAt;

  /// وقت التصعيد (null إذا لم يُصعّد)
  ///
  /// 💡 متى يحدث التصعيد؟
  /// - لم يرد أحد خلال المدة المحددة
  /// - اكتشاف خطر أكبر
  /// - طلب المستخدم التصعيد
  final DateTime? escalatedAt;

  /// قائمة IDs جهات الاتصال الذين أُرسل لهم التنبيه
  ///
  /// مثال:
  /// ```dart
  /// sentToContacts: ['contact_1', 'contact_2', 'contact_3']
  /// ```
  final List<String> sentToContacts;

  /// طريقة التوصيل المستخدمة
  final DeliveryMethod deliveryMethod;

  /// بيانات إضافية (Metadata)
  ///
  /// 💡 استخدامات:
  /// ```dart
  /// metadata: {
  ///   'deviceInfo': 'iPhone 14 Pro',
  ///   'batteryLevel': 15,
  ///   'networkType': 'WiFi',
  ///   'speed': 60.5,  // السرعة عند الانحراف
  ///   'distance': 50.0,  // مسافة الانحراف
  /// }
  /// ```
  final Map<String, dynamic> metadata;

  /// ═══════════════════════════════════════════════════════════════════════════
  /// 🏗️ Constructor
  /// ═══════════════════════════════════════════════════════════════════════════
  ///
  /// 📝 مثال الاستخدام:
  /// ```dart
  /// final alert = AlertEntity(
  ///   id: 'alert_123',
  ///   tripId: 'trip_456',
  ///   userId: 'user_789',
  ///   type: AlertType.deviation,
  ///   level: AlertLevel.high,
  ///   status: AlertStatus.pending,
  ///   location: LocationEntity(
  ///     latitude: 24.7136,
  ///     longitude: 46.6753,
  ///   ),
  ///   message: 'انحراف 100 متر عن المسار',
  ///   triggeredAt: DateTime.now(),
  /// );
  /// ```
  const AlertEntity({
    required this.id,
    required this.tripId,
    required this.userId,
    required this.type,
    required this.level,
    required this.status,
    required this.location,
    required this.message,
    required this.triggeredAt,
    this.acknowledgedAt,
    this.escalatedAt,
    this.sentToContacts = const [],
    this.deliveryMethod = DeliveryMethod.inApp,
    this.metadata = const {},
  });

  /// ═══════════════════════════════════════════════════════════════════════════
  /// 🔄 copyWith() - إنشاء نسخة معدلة
  /// ═══════════════════════════════════════════════════════════════════════════
  ///
  /// 💡 لماذا copyWith؟
  /// Entity هو **immutable** (غير قابل للتعديل)
  /// لا يمكننا تغيير قيمة مباشرة: `alert.status = AlertStatus.active`  ❌
  /// بدلاً من ذلك، نُنشئ نسخة جديدة بالقيم المعدلة: ✅
  ///
  /// 📝 أمثلة الاستخدام:
  ///
  /// **مثال 1: تحديث الحالة:**
  /// ```dart
  /// final updatedAlert = alert.copyWith(
  ///   status: AlertStatus.active,
  /// );
  /// // كل شيء آخر يبقى كما هو، فقط status تغيّر
  /// ```
  ///
  /// **مثال 2: الإقرار:**
  /// ```dart
  /// final acknowledgedAlert = alert.copyWith(
  ///   status: AlertStatus.acknowledged,
  ///   acknowledgedAt: DateTime.now(),
  /// );
  /// ```
  ///
  /// **مثال 3: التصعيد:**
  /// ```dart
  /// final escalatedAlert = alert.copyWith(
  ///   level: AlertLevel.critical,  // من high إلى critical
  ///   status: AlertStatus.escalated,
  ///   escalatedAt: DateTime.now(),
  ///   deliveryMethod: DeliveryMethod.all,  // كل الطرق!
  /// );
  /// ```
  ///
  /// **مثال 4: إضافة جهات اتصال:**
  /// ```dart
  /// final alertWithContacts = alert.copyWith(
  ///   sentToContacts: [...alert.sentToContacts, 'contact_3'],
  /// );
  /// // إضافة contact جديد للقائمة الموجودة
  /// ```
  AlertEntity copyWith({
    String? id,
    String? tripId,
    String? userId,
    AlertType? type,
    AlertLevel? level,
    AlertStatus? status,
    LocationEntity? location,
    String? message,
    DateTime? triggeredAt,
    DateTime? acknowledgedAt,
    DateTime? escalatedAt,
    List<String>? sentToContacts,
    DeliveryMethod? deliveryMethod,
    Map<String, dynamic>? metadata,
  }) {
    return AlertEntity(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      level: level ?? this.level,
      status: status ?? this.status,
      location: location ?? this.location,
      message: message ?? this.message,
      triggeredAt: triggeredAt ?? this.triggeredAt,
      acknowledgedAt: acknowledgedAt ?? this.acknowledgedAt,
      escalatedAt: escalatedAt ?? this.escalatedAt,
      sentToContacts: sentToContacts ?? this.sentToContacts,
      deliveryMethod: deliveryMethod ?? this.deliveryMethod,
      metadata: metadata ?? this.metadata,
    );
  }

  /// ═══════════════════════════════════════════════════════════════════════════
  /// 🔍 isActive - هل التنبيه نشط؟
  /// ═══════════════════════════════════════════════════════════════════════════
  ///
  /// 💡 ما معنى "نشط"؟
  /// التنبيه يكون نشطاً إذا:
  /// - في حالة pending (تم إنشاؤه، ينتظر الإرسال)
  /// - في حالة active (تم إرساله، ينتظر رد)
  ///
  /// ❌ ليس نشطاً إذا:
  /// - acknowledged (تم الإقرار به)
  /// - resolved (تم حله)
  /// - expired (انتهى)
  ///
  /// 📝 مثال الاستخدام:
  /// ```dart
  /// // في UI:
  /// if (alert.isActive) {
  ///   showRedBadge();  // عرض إشارة حمراء
  ///   playAlertSound();  // تشغيل صوت التنبيه
  /// }
  ///
  /// // في UseCase:
  /// final activeAlerts = allAlerts.where((a) => a.isActive).toList();
  /// ```
  bool get isActive => status == AlertStatus.active || status == AlertStatus.pending;

  /// ═══════════════════════════════════════════════════════════════════════════
  /// 🏷️ typeDisplayName - اسم النوع بالعربية
  /// ═══════════════════════════════════════════════════════════════════════════
  ///
  /// 💡 لماذا نحتاجه؟
  /// للعرض في UI بدون الحاجة لـ switch في كل مكان
  ///
  /// 📝 مثال الاستخدام:
  /// ```dart
  /// // في UI:
  /// Text(alert.typeDisplayName)  // "انحراف عن المسار"
  ///
  /// // بدلاً من:
  /// Text(_getTypeName(alert.type))  // تكرار في كل صفحة!
  /// ```
  String get typeDisplayName {
    switch (type) {
      case AlertType.deviation:
        return 'انحراف عن المسار';
      case AlertType.sos:
        return 'طوارئ';
      case AlertType.inactivity:
        return 'عدم حركة';
      case AlertType.lowBattery:
        return 'بطارية منخفضة';
      case AlertType.noConnection:
        return 'انقطاع الاتصال';
    }
  }

  /// ═══════════════════════════════════════════════════════════════════════════
  /// ⚖️ props - للمقارنة مع Equatable
  /// ═══════════════════════════════════════════════════════════════════════════
  ///
  /// 💡 كيف يعمل Equatable؟
  /// يقارن جميع القيم في props للتحقق من المساواة
  ///
  /// ```dart
  /// final alert1 = AlertEntity(id: '1', type: AlertType.sos, ...);
  /// final alert2 = AlertEntity(id: '1', type: AlertType.sos, ...);
  ///
  /// alert1 == alert2  // true (لأن جميع القيم في props متطابقة)
  /// ```
  ///
  /// 🎯 الفائدة:
  /// - في BLoC: التحقق من تغيير State
  /// - في Lists: إزالة التكرار
  /// - في Tests: مقارنة النتائج
  @override
  List<Object?> get props => [
    id,
    tripId,
    userId,
    type,
    level,
    status,
    location,
    message,
    triggeredAt,
    acknowledgedAt,
    escalatedAt,
    sentToContacts,
    deliveryMethod,
    metadata,
  ];
}

/// ═══════════════════════════════════════════════════════════════════════════
/// 🎓 سيناريوهات استخدام كاملة:
/// ═══════════════════════════════════════════════════════════════════════════
///
/// 📱 **سيناريو 1: انحراف عن المسار**
/// ```dart
/// // 1. اكتشاف الانحراف (في TripBloc)
/// final distance = calculateDistance(currentLocation, routePoint);
///
/// if (distance > config.deviationThreshold) {
///   // 2. إنشاء Alert
///   final alert = AlertEntity(
///     id: 'alert_${DateTime.now().millisecondsSinceEpoch}',
///     tripId: currentTrip.id,
///     userId: currentUser.id,
///     type: AlertType.deviation,
///     level: distance > 100 ? AlertLevel.high : AlertLevel.medium,
///     status: AlertStatus.pending,
///     location: currentLocation,
///     message: 'انحراف ${distance.toInt()} متر عن المسار',
///     triggeredAt: DateTime.now(),
///     metadata: {
///       'distance': distance,
///       'speed': currentSpeed,
///     },
///   );
///
///   // 3. إطلاق UseCase
///   final result = await triggerAlertUseCase(alert);
///
///   // 4. معالجة النتيجة
///   result.fold(
///     (failure) => emit(AlertError(failure.message)),
///     (success) => emit(AlertSent()),
///   );
/// }
/// ```
///
/// 🆘 **سيناريو 2: SOS**
/// ```dart
/// // عند الضغط على زر SOS
/// onSOSPressed() async {
///   // 1. تأكيد من المستخدم
///   final confirmed = await showConfirmDialog(
///     'هل تريد إرسال إشارة استغاثة؟',
///   );
///
///   if (confirmed) {
///     // 2. إنشاء SOS Alert
///     final alert = AlertEntity(
///       id: 'sos_${DateTime.now().millisecondsSinceEpoch}',
///       tripId: currentTrip?.id ?? '',
///       userId: currentUser.id,
///       type: AlertType.sos,
///       level: AlertLevel.critical,
///       status: AlertStatus.pending,
///       location: await getCurrentLocation(),
///       message: buildSOSMessage(),
///       triggeredAt: DateTime.now(),
///       deliveryMethod: DeliveryMethod.all,  // كل الطرق!
///     );
///
///     // 3. إرسال
///     final result = await sendSOSUseCase(alert);
///
///     // 4. عد تنازلي (30 ثانية للإلغاء)
///     startCountdown(30, onTimeout: () {
///       // إرسال فعلي بعد 30 ثانية
///       confirmSOS();
///     });
///   }
/// }
/// ```
///
/// ⏱️ **سيناريو 3: عدم حركة**
/// ```dart
/// // في Background Service
/// Timer.periodic(Duration(minutes: 5), (timer) async {
///   final lastLocation = await getLastLocation();
///   final timeSinceLastMove = DateTime.now().difference(lastLocation.timestamp);
///
///   if (timeSinceLastMove > Duration(minutes: 30)) {
///     final alert = AlertEntity(
///       id: 'inactivity_${DateTime.now().millisecondsSinceEpoch}',
///       tripId: currentTrip.id,
///       userId: currentUser.id,
///       type: AlertType.inactivity,
///       level: AlertLevel.medium,
///       status: AlertStatus.pending,
///       location: lastLocation,
///       message: 'لم يتحرك المستخدم منذ ${timeSinceLastMove.inMinutes} دقيقة',
///       triggeredAt: DateTime.now(),
///     );
///
///     await triggerAlertUseCase(alert);
///   }
/// });
/// ```
///
/// ⬆️ **سيناريو 4: التصعيد التلقائي**
/// ```dart
/// // في AlertBloc
/// startEscalationTimer(AlertEntity alert) {
///   Timer(Duration(minutes: 5), () async {
///     if (alert.status == AlertStatus.active) {
///       // لم يرد أحد خلال 5 دقائق، صعّد!
///       final escalated = alert.copyWith(
///         level: AlertLevel.critical,
///         status: AlertStatus.escalated,
///         escalatedAt: DateTime.now(),
///         deliveryMethod: DeliveryMethod.all,
///       );
///
///       await escalateAlertUseCase(escalated);
///
///       // أرسل SMS لجميع جهات الاتصال
///       final contacts = await getEmergencyContacts();
///       for (final contact in contacts) {
///         await sendSMS(contact.phoneNumber, escalated.message);
///       }
///     }
///   });
/// }
/// ```
/// ═══════════════════════════════════════════════════════════════════════════