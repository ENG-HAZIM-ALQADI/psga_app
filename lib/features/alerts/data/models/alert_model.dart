import '../../domain/entities/alert_entity.dart';
import '../../../trips/data/models/location_model.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// 🚨 AlertModel - نموذج بيانات التنبيه
/// ═══════════════════════════════════════════════════════════════════════════
///
/// 🎯 الموقع في Clean Architecture:
/// ```
/// features/alerts/
///   ├── domain/
///   │   ├── entities/
///   │   │   └── alert_entity.dart ← الكيان النقي (Business Logic)
///   └── data/
///       ├── models/
///       │   └── alert_model.dart ← ← ← أنت هنا! (Data Layer)
///       ├── repositories/
///       └── datasources/
/// ```
///
/// 📌 ما هو AlertModel؟
/// AlertModel هو "سفير" البيانات بين العالم الخارجي والتطبيق:
/// - يرث من AlertEntity (الكيان النقي في Domain Layer)
/// - يضيف قدرة التحويل من/إلى JSON
/// - يتعامل مع Firebase وHive
/// - يدير عملية Serialization/Deserialization
///
/// 💡 الفرق بين Entity و Model:
///
/// ┌─────────────────────────────────────────────────────────────┐
/// │ AlertEntity (Domain)   │ AlertModel (Data)                  │
/// ├────────────────────────┼────────────────────────────────────┤
/// │ كيان نقي               │ نموذج بيانات                       │
/// │ Business Logic فقط      │ + Serialization/Deserialization   │
/// │ لا يعرف JSON أو Firebase │ يعرف JSON, Firebase, Hive         │
/// │ مستقل عن التقنيات       │ مرتبط بالتقنيات المستخدمة         │
/// │ لا يتغير كثيراً         │ قد يتغير مع تغيير التقنيات        │
/// └────────────────────────┴────────────────────────────────────┘
///
/// 🔄 دورة حياة Alert في التطبيق:
///
/// 1️⃣ **إنشاء Alert:**
/// ```dart
/// // في Business Logic (UseCase):
/// final alertEntity = AlertEntity(
///   id: generateId(),
///   type: AlertType.deviation,
///   level: AlertLevel.high,
///   // ...
/// );
///
/// // في Repository:
/// final alertModel = AlertModel.fromEntity(alertEntity);
///
/// // حفظ في Hive:
/// await alertBox.put(alertModel.id, alertModel);
///
/// // إرسال لـ Firebase:
/// await firestore.collection('alerts').doc(alertModel.id)
///     .set(alertModel.toFirestore());
/// ```
///
/// 2️⃣ **جلب Alert من Firebase:**
/// ```dart
/// // من Firebase:
/// final doc = await firestore.collection('alerts').doc(alertId).get();
/// final alertModel = AlertModel.fromFirestore(doc.data()!, doc.id);
///
/// // تحويل لـ Entity للاستخدام في Business Logic:
/// final alertEntity = alertModel as AlertEntity;
/// ```
///
/// 3️⃣ **تحديث Alert:**
/// ```dart
/// // في UseCase:
/// final updatedEntity = currentAlert.copyWith(
///   status: AlertStatus.acknowledged,
///   acknowledgedAt: DateTime.now(),
/// );
///
/// // في Repository:
/// final updatedModel = AlertModel.fromEntity(updatedEntity);
/// await firestore.collection('alerts').doc(updatedModel.id)
///     .update(updatedModel.toFirestore());
/// ```

class AlertModel extends AlertEntity {
  /// ═══════════════════════════════════════════════════════════════════════════
  /// 🏗️ Constructor
  /// ═══════════════════════════════════════════════════════════════════════════
  ///
  /// 💡 لاحظ استخدام `super` بدلاً من `this`:
  /// بما أن AlertModel يرث من AlertEntity، نمرر البيانات للـ parent class
  ///
  /// 📝 مثال الاستخدام:
  /// ```dart
  /// final alert = AlertModel(
  ///   id: 'alert_123',
  ///   tripId: 'trip_456',
  ///   userId: 'user_789',
  ///   type: AlertType.sos,
  ///   level: AlertLevel.critical,
  ///   status: AlertStatus.pending,
  ///   location: LocationModel(...),
  ///   message: 'طوارئ! المستخدم خرج عن المسار المحدد',
  ///   triggeredAt: DateTime.now(),
  /// );
  /// ```
  const AlertModel({
    required super.id,              // معرف التنبيه الفريد
    required super.tripId,          // معرف الرحلة المرتبطة
    required super.userId,          // معرف المستخدم
    required super.type,            // نوع التنبيه (deviation, sos, إلخ)
    required super.level,           // مستوى الخطورة
    required super.status,          // حالة التنبيه
    required super.location,        // الموقع عند إطلاق التنبيه
    required super.message,         // رسالة التنبيه
    required super.triggeredAt,     // وقت إطلاق التنبيه
    super.acknowledgedAt,           // وقت الإقرار (null إذا لم يُقر)
    super.escalatedAt,              // وقت التصعيد (null إذا لم يُصعّد)
    super.sentToContacts,           // قائمة IDs جهات الاتصال المُرسل لهم
    super.deliveryMethod,           // طريقة التوصيل (inApp, FCM, SMS)
    super.metadata,                 // بيانات إضافية
  });

  /// ═══════════════════════════════════════════════════════════════════════════
  /// 📥 fromJson() - إنشاء AlertModel من JSON
  /// ═══════════════════════════════════════════════════════════════════════════
  ///
  /// 🎯 متى تُستخدم؟
  /// - عند جلب بيانات من API
  /// - عند قراءة من Shared Preferences
  /// - عند استقبال Push Notification
  /// - عند قراءة من Cache
  ///
  /// 💡 كيف تعمل؟
  /// 1. تأخذ Map<String, dynamic> (JSON object)
  /// 2. تستخرج كل قيمة وتحولها للنوع الصحيح
  /// 3. تُنشئ AlertModel جديد
  ///
  /// 📝 مثال JSON:
  /// ```json
  /// {
  ///   "id": "alert_123",
  ///   "tripId": "trip_456",
  ///   "userId": "user_789",
  ///   "type": "sos",
  ///   "level": "critical",
  ///   "status": "pending",
  ///   "location": {
  ///     "latitude": 24.7136,
  ///     "longitude": 46.6753
  ///   },
  ///   "message": "طوارئ!",
  ///   "triggeredAt": "2024-01-15T14:30:00.000Z",
  ///   "sentToContacts": ["contact_1", "contact_2"],
  ///   "deliveryMethod": "all"
  /// }
  /// ```
  ///
  /// 🔄 خطوات التحويل:
  ///
  /// 1️⃣ **استخراج Strings مباشرة:**
  ///    ```dart
  ///    id: json['id'] as String,
  ///    ```
  ///
  /// 2️⃣ **تحويل Enums:**
  ///    ```dart
  ///    type: AlertType.values.firstWhere(
  ///      (e) => e.name == json['type'],  // ابحث عن enum باسمه
  ///      orElse: () => AlertType.deviation,  // default إذا لم يُعثر عليه
  ///    ),
  ///    ```
  ///
  /// 3️⃣ **تحويل DateTime:**
  ///    ```dart
  ///    triggeredAt: DateTime.parse(json['triggeredAt'] as String),
  ///    ```
  ///
  /// 4️⃣ **تحويل Objects المتداخلة:**
  ///    ```dart
  ///    location: LocationModel.fromJson(json['location'] as Map<String, dynamic>),
  ///    ```
  ///
  /// 5️⃣ **تحويل Lists:**
  ///    ```dart
  ///    sentToContacts: (json['sentToContacts'] as List<dynamic>?)
  ///        ?.map((e) => e as String)
  ///        .toList() ?? [],
  ///    ```
  ///
  /// 6️⃣ **معالجة nullable values:**
  ///    ```dart
  ///    acknowledgedAt: json['acknowledgedAt'] != null
  ///        ? DateTime.parse(json['acknowledgedAt'] as String)
  ///        : null,
  ///    ```
  ///
  /// ⚠️ معالجة الأخطاء:
  /// - استخدام `orElse` للـ Enums لتجنب Exception
  /// - استخدام `?? []` للـ Lists الفارغة
  /// - استخدام `?? {}` للـ Maps الفارغة
  factory AlertModel.fromJson(Map<String, dynamic> json) {
    return AlertModel(
      id: json['id'] as String,
      tripId: json['tripId'] as String,
      userId: json['userId'] as String,

      // تحويل AlertType من string لـ enum
      // مثلاً: "sos" → AlertType.sos
      type: AlertType.values.firstWhere(
            (e) => e.name == json['type'],
        orElse: () => AlertType.deviation,  // default fallback
      ),

      // تحويل AlertLevel من string لـ enum
      level: AlertLevel.values.firstWhere(
            (e) => e.name == json['level'],
        orElse: () => AlertLevel.low,
      ),

      // تحويل AlertStatus من string لـ enum
      status: AlertStatus.values.firstWhere(
            (e) => e.name == json['status'],
        orElse: () => AlertStatus.pending,
      ),

      // تحويل الموقع من JSON لـ LocationModel
      // location هو object متداخل
      location: LocationModel.fromJson(json['location'] as Map<String, dynamic>),

      message: json['message'] as String,

      // تحويل DateTime من ISO8601 String
      // مثلاً: "2024-01-15T14:30:00.000Z" → DateTime object
      triggeredAt: DateTime.parse(json['triggeredAt'] as String),

      // تحويل nullable DateTime
      // إذا null، نرجع null، وإلا نحوله
      acknowledgedAt: json['acknowledgedAt'] != null
          ? DateTime.parse(json['acknowledgedAt'] as String)
          : null,

      escalatedAt: json['escalatedAt'] != null
          ? DateTime.parse(json['escalatedAt'] as String)
          : null,

      // تحويل List من JSON
      // مثلاً: ["contact_1", "contact_2"] → List<String>
      sentToContacts: (json['sentToContacts'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
          [],  // default list فارغة إذا null

      // تحويل DeliveryMethod enum
      deliveryMethod: DeliveryMethod.values.firstWhere(
            (e) => e.name == json['deliveryMethod'],
        orElse: () => DeliveryMethod.inApp,
      ),

      // metadata هي Map يمكن أن تحتوي أي بيانات إضافية
      metadata: (json['metadata'] as Map<String, dynamic>?) ?? {},
    );
  }

  /// ═══════════════════════════════════════════════════════════════════════════
  /// 📤 toJson() - تحويل AlertModel إلى JSON
  /// ═══════════════════════════════════════════════════════════════════════════
  ///
  /// 🎯 متى تُستخدم؟
  /// - عند إرسال البيانات لـ API
  /// - عند الحفظ في Shared Preferences
  /// - عند إرسال عبر Network
  /// - عند التخزين في Cache
  ///
  /// 💡 كيف تعمل؟
  /// 1. تأخذ جميع الحقول من AlertModel
  /// 2. تحول كل حقل للنوع المناسب للـ JSON
  /// 3. ترجع Map<String, dynamic>
  ///
  /// 🔄 خطوات التحويل:
  ///
  /// 1️⃣ **Strings تُنسخ مباشرة:**
  ///    ```dart
  ///    'id': id,  // String → String
  ///    ```
  ///
  /// 2️⃣ **Enums تُحول لـ name:**
  ///    ```dart
  ///    'type': type.name,  // AlertType.sos → "sos"
  ///    ```
  ///
  /// 3️⃣ **DateTime تُحول لـ ISO8601:**
  ///    ```dart
  ///    'triggeredAt': triggeredAt.toIso8601String(),
  ///    // DateTime → "2024-01-15T14:30:00.000Z"
  ///    ```
  ///
  /// 4️⃣ **Objects متداخلة تُحول لـ JSON:**
  ///    ```dart
  ///    'location': LocationModel.fromEntity(location).toJson(),
  ///    ```
  ///
  /// 5️⃣ **nullable values تستخدم ?. operator:**
  ///    ```dart
  ///    'acknowledgedAt': acknowledgedAt?.toIso8601String(),
  ///    // null → null, DateTime → String
  ///    ```
  ///
  /// 📝 مثال الناتج:
  /// ```json
  /// {
  ///   "id": "alert_123",
  ///   "type": "sos",
  ///   "level": "critical",
  ///   "triggeredAt": "2024-01-15T14:30:00.000Z",
  ///   "acknowledgedAt": null
  /// }
  /// ```
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tripId': tripId,
      'userId': userId,

      // تحويل Enums لـ String باستخدام .name
      'type': type.name,              // AlertType.sos → "sos"
      'level': level.name,            // AlertLevel.critical → "critical"
      'status': status.name,          // AlertStatus.pending → "pending"

      // تحويل LocationEntity لـ LocationModel ثم لـ JSON
      'location': LocationModel.fromEntity(location).toJson(),

      'message': message,

      // تحويل DateTime لـ ISO8601 String
      'triggeredAt': triggeredAt.toIso8601String(),

      // nullable DateTime - إذا null تبقى null
      'acknowledgedAt': acknowledgedAt?.toIso8601String(),
      'escalatedAt': escalatedAt?.toIso8601String(),

      // List<String> تُنسخ مباشرة (JSON-serializable)
      'sentToContacts': sentToContacts,

      // DeliveryMethod enum → String
      'deliveryMethod': deliveryMethod.name,

      // Map تُنسخ مباشرة
      'metadata': metadata,
    };
  }

  /// ═══════════════════════════════════════════════════════════════════════════
  /// 🔥 fromFirestore() - إنشاء AlertModel من Firestore Document
  /// ═══════════════════════════════════════════════════════════════════════════
  ///
  /// 🎯 متى تُستخدم؟
  /// عند جلب بيانات من Firestore (Firebase Cloud Database)
  ///
  /// 💡 لماذا factory منفصلة؟
  /// Firestore يخزن الـ ID في مكان منفصل عن الـ data:
  /// ```dart
  /// DocumentSnapshot doc = await firestore.collection('alerts').doc(alertId).get();
  /// // doc.id → "alert_123" (الـ ID)
  /// // doc.data() → {tripId: "...", type: "sos", ...} (البيانات بدون ID)
  /// ```
  ///
  /// 🔄 كيف تعمل؟
  /// 1. تأخذ البيانات من الـ document (بدون ID)
  /// 2. تأخذ الـ ID من الـ document ID
  /// 3. تدمجهم في map واحد
  /// 4. تستدعي fromJson()
  ///
  /// 📝 مثال الاستخدام:
  /// ```dart
  /// // جلب من Firestore:
  /// final doc = await FirebaseFirestore.instance
  ///     .collection('alerts')
  ///     .doc('alert_123')
  ///     .get();
  ///
  /// // تحويل لـ AlertModel:
  /// final alert = AlertModel.fromFirestore(
  ///   doc.data()!,  // البيانات
  ///   doc.id,       // الـ ID
  /// );
  ///
  /// // الآن alert.id = "alert_123" ✅
  /// ```
  ///
  /// 💡 Spread Operator (...):
  /// ```dart
  /// {...doc, 'id': docId}
  /// ```
  /// يعني: خذ كل محتويات doc وأضف 'id' إليها
  ///
  /// مثال:
  /// ```dart
  /// final doc = {'name': 'Ali', 'age': 25};
  /// final docId = 'user_123';
  /// final result = {...doc, 'id': docId};
  /// // result = {'name': 'Ali', 'age': 25, 'id': 'user_123'}
  /// ```
  factory AlertModel.fromFirestore(Map<String, dynamic> doc, String docId) {
    return AlertModel.fromJson({...doc, 'id': docId});
  }

  /// ═══════════════════════════════════════════════════════════════════════════
  /// 🔥 toFirestore() - تحويل AlertModel لحفظه في Firestore
  /// ═══════════════════════════════════════════════════════════════════════════
  ///
  /// 🎯 متى تُستخدم؟
  /// عند حفظ أو تحديث البيانات في Firestore
  ///
  /// 💡 لماذا نحذف الـ ID؟
  /// Firestore يحفظ الـ ID في مكان منفصل (Document ID)،
  /// لذلك لا نحتاج أن يكون في البيانات نفسها
  ///
  /// 📝 مثال الاستخدام:
  /// ```dart
  /// final alert = AlertModel(...);
  ///
  /// // حفظ في Firestore:
  /// await FirebaseFirestore.instance
  ///     .collection('alerts')
  ///     .doc(alert.id)              // ← الـ ID هنا
  ///     .set(alert.toFirestore());  // ← البيانات بدون ID
  /// ```
  ///
  /// 🔄 الخطوات:
  /// 1. استدعاء toJson() للحصول على JSON كامل
  /// 2. حذف الـ 'id' من الـ JSON
  /// 3. إرجاع الـ JSON بدون ID
  ///
  /// مثال:
  /// ```dart
  /// // toJson() يرجع:
  /// {'id': 'alert_123', 'type': 'sos', 'level': 'critical'}
  ///
  /// // toFirestore() يرجع:
  /// {'type': 'sos', 'level': 'critical'}  ← لاحظ: بدون 'id'
  /// ```
  Map<String, dynamic> toFirestore() {
    final json = toJson();  // احصل على JSON كامل
    json.remove('id');      // احذف الـ ID
    return json;            // أرجع JSON بدون ID
  }

  /// ═══════════════════════════════════════════════════════════════════════════
  /// 🔄 fromEntity() - تحويل AlertEntity إلى AlertModel
  /// ═══════════════════════════════════════════════════════════════════════════
  ///
  /// 🎯 متى تُستخدم؟
  /// عند الانتقال من Domain Layer إلى Data Layer
  ///
  /// 💡 لماذا نحتاجها؟
  /// ```
  /// UseCase (Domain) → Repository (Data)
  /// AlertEntity      → AlertModel
  /// ```
  ///
  /// UseCase يتعامل مع Entities فقط (نظيفة، بدون تفاصيل تقنية)
  /// Repository يحتاج Models لحفظها في Hive أو Firebase
  ///
  /// 📝 مثال الاستخدام:
  /// ```dart
  /// // في UseCase:
  /// Future<Either<Failure, AlertEntity>> call(AlertEntity alert) async {
  ///   // ...logic
  ///   return await repository.createAlert(alert);
  /// }
  ///
  /// // في Repository:
  /// Future<Either<Failure, AlertEntity>> createAlert(AlertEntity alert) async {
  ///   final alertModel = AlertModel.fromEntity(alert);  // ← تحويل!
  ///   await localDataSource.createAlert(alertModel);
  ///   await remoteDataSource.createAlert(alertModel);
  ///   return Right(alert);
  /// }
  /// ```
  ///
  /// 🔄 كيف تعمل؟
  /// بما أن AlertModel extends AlertEntity، جميع الحقول موجودة بالفعل!
  /// نحتاج فقط إنشاء AlertModel جديد بنفس القيم
  factory AlertModel.fromEntity(AlertEntity entity) {
    return AlertModel(
      id: entity.id,
      tripId: entity.tripId,
      userId: entity.userId,
      type: entity.type,
      level: entity.level,
      status: entity.status,
      location: entity.location,
      message: entity.message,
      triggeredAt: entity.triggeredAt,
      acknowledgedAt: entity.acknowledgedAt,
      escalatedAt: entity.escalatedAt,
      sentToContacts: entity.sentToContacts,
      deliveryMethod: entity.deliveryMethod,
      metadata: entity.metadata,
    );
  }
}

/// ═══════════════════════════════════════════════════════════════════════════
/// 🎓 ملاحظات إضافية للمبتدئين:
/// ═══════════════════════════════════════════════════════════════════════════
///
/// 📊 Serialization vs Deserialization:
///
/// **Serialization** = تحويل Object إلى نص (JSON):
/// ```dart
/// AlertModel → toJson() → {"id": "...", "type": "sos"}
/// ```
///
/// **Deserialization** = تحويل نص (JSON) إلى Object:
/// ```dart
/// {"id": "...", "type": "sos"} → fromJson() → AlertModel
/// ```
///
/// 🔄 سيناريو كامل - من Firebase للشاشة:
///
/// ```dart
/// // 1️⃣ جلب من Firestore
/// final doc = await firestore.collection('alerts').doc('alert_123').get();
///
/// // 2️⃣ تحويل لـ Model (Data Layer)
/// final alertModel = AlertModel.fromFirestore(doc.data()!, doc.id);
///
/// // 3️⃣ تمرير للـ Repository (يرجع Entity)
/// final alertEntity = alertModel as AlertEntity;
///
/// // 4️⃣ استخدام في UseCase (Domain Layer)
/// final result = await sendSOSUseCase(alertEntity);
///
/// // 5️⃣ عرض في UI (Presentation Layer)
/// result.fold(
///   (failure) => showError(failure.message),
///   (success) => showSuccess('تم إرسال التنبيه!'),
/// );
/// ```
///
/// 💡 Best Practices:
///
/// 1️⃣ **دائماً استخدم orElse للـ Enums:**
///    ```dart
///    type: AlertType.values.firstWhere(
///      (e) => e.name == json['type'],
///      orElse: () => AlertType.deviation,  // ← مهم جداً!
///    ),
///    ```
///    لماذا؟ إذا جاء enum غير معروف من الـ backend، لن يحدث crash!
///
/// 2️⃣ **استخدم ?? للـ defaults:**
///    ```dart
///    sentToContacts: (json['sentToContacts'] as List?) ?? [],
///    ```
///    بدلاً من السماح بـ null
///
/// 3️⃣ **احفظ metadata للمرونة:**
///    ```dart
///    metadata: {
///      'deviceInfo': 'iPhone 14 Pro',
///      'batteryLevel': 15,
///      'networkType': 'WiFi',
///    }
///    ```
///    يمكنك إضافة أي بيانات إضافية بدون تعديل الـ Model!
///
/// 4️⃣ **استخدم ISO8601 للتواريخ:**
///    ```dart
///    triggeredAt.toIso8601String()  // "2024-01-15T14:30:00.000Z"
///    ```
///    معيار عالمي، يعمل مع جميع اللغات والمناطق الزمنية
/// ═══════════════════════════════════════════════════════════════════════════
