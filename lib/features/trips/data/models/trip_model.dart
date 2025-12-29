import '../../domain/entities/trip_entity.dart';
import 'location_model.dart';
import 'deviation_model.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// 🛣️ TripModel - نموذج الرحلة (Data Layer)
/// ═══════════════════════════════════════════════════════════════════════════
///
/// الهدف من هذا الملف:
/// يمثل البيانات الكاملة للرحلة وطريقة تسلسلها (Serialization)
///
/// الفرق بين TripEntity و TripModel:
/// ```
/// TripEntity (Domain Layer)          TripModel (Data Layer)
/// ├─ Entity نقية                     ├─ Model توسعة من Entity
/// ├─ بدون Annotations                ├─ مع toJson/fromJson
/// ├─ بدون تفاصيل Database           ├─ مع serialization للـ Firebase/Hive
/// └─ مستقلة عن أي إطار عمل          └─ متوافقة مع Firebase و Hive
/// ```
///
/// الاستخدام:
/// - TripEntity: تُستخدم في Domain و Presentation Layers
/// - TripModel: تُستخدم في Data Layer للحفظ والاسترجاع من Database
///
/// التحويلات الرئيسية:
/// 1. JSON ← → TripModel (من Firebase أو API)
/// 2. TripEntity ← → TripModel (لنقل البيانات بين الطبقات)
/// 3. Firestore Document ← → TripModel (للتخزين في Firebase)

class TripModel extends TripEntity {
  /// ═══════════════════════════════════════════════════════════════════════════
  /// Constructor - تهيئة نموذج الرحلة
  /// ═══════════════════════════════════════════════════════════════════════════
  /// 
  /// نرث من TripEntity (super) لتجنب تكرار الكود
  /// super = استدعاء الـ parent class constructor
  /// 
  /// البيانات الأساسية:
  /// - id: معرف فريد للرحلة
  /// - userId: من يمتلك الرحلة؟
  /// - routeId: على أي مسار؟
  /// - status: ما حالة الرحلة الآن؟
  /// - startTime: متى بدأت؟
  /// - locationHistory: أين ذهبت؟

  const TripModel({
    required super.id,
    required super.userId,
    required super.routeId,
    required super.routeName,
    required super.status,
    required super.startTime,
    super.endTime,
    required super.startLocation,
    super.endLocation,
    super.currentLocation,
    super.locationHistory,
    super.deviations,
    super.alertsTriggered,
    super.totalDistance,
    super.averageSpeed,
    super.notes,
  });

  /// ═══════════════════════════════════════════════════════════════════════════
  /// fromJson() - تحويل من JSON إلى TripModel
  /// ═══════════════════════════════════════════════════════════════════════════
  ///
  /// متى يتم استدعاء؟
  /// عندما نجلب بيانات من Firebase أو API
  /// البيانات تأتي في صيغة JSON (Dictionary)
  /// نحتاج تحويلها لـ TripModel
  ///
  /// مثال JSON:
  /// ```json
  /// {
  ///   "id": "trip_123",
  ///   "userId": "user_456",
  ///   "routeId": "route_789",
  ///   "status": "active",
  ///   "startTime": "2024-01-15T10:30:00.000Z",
  ///   "startLocation": {
  ///     "latitude": 24.7136,
  ///     "longitude": 46.6753,
  ///     "timestamp": "2024-01-15T10:30:00.000Z"
  ///   },
  ///   ...
  /// }
  /// ```
  ///
  /// الخطوات:
  /// 1️⃣ استخراج البيانات من JSON
  /// 2️⃣ تحويل النصوص إلى الأنواع الصحيحة (تاريخ، رقم، إلخ)
  /// 3️⃣ معالجة القيم الاختيارية (قد تكون null)
  /// 4️⃣ تحويل الكائنات المدمجة (LocationModel، DeviationModel)
  /// 5️⃣ إنشاء TripModel جديد

  factory TripModel.fromJson(Map<String, dynamic> json) {
    return TripModel(
      /// معرف الرحلة
      id: json['id'] as String,

      /// معرف المستخدم
      userId: json['userId'] as String,

      /// معرف المسار
      routeId: json['routeId'] as String,

      /// اسم المسار
      routeName: json['routeName'] as String,

      /// حالة الرحلة
      /// TripStatus.active, TripStatus.paused, TripStatus.completed، إلخ
      /// لماذا firstWhere؟ نحتاج البحث عن اسم الـ enum في النص
      status: TripStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => TripStatus.pending,  /// قيمة افتراضية إذا لم نجد
      ),

      /// وقت البدء (نحتاج تحويل النص لـ DateTime)
      startTime: DateTime.parse(json['startTime'] as String),

      /// وقت الإنهاء (قد يكون null إذا كانت الرحلة نشطة)
      endTime: json['endTime'] != null
          ? DateTime.parse(json['endTime'] as String)
          : null,

      /// موقع البداية (نحتاج تحويل JSON إلى LocationModel)
      startLocation: LocationModel.fromJson(Map<String, dynamic>.from(json['startLocation'] as Map)),

      /// موقع النهاية (اختياري)
      endLocation: json['endLocation'] != null
          ? LocationModel.fromJson(Map<String, dynamic>.from(json['endLocation'] as Map))
          : null,

      /// الموقع الحالي (اختياري)
      currentLocation: json['currentLocation'] != null
          ? LocationModel.fromJson(Map<String, dynamic>.from(json['currentLocation'] as Map))
          : null,

      /// قائمة المواقع التاريخية
      /// نحتاج تحويل كل عنصر في القائمة من JSON إلى LocationModel
      /// إذا كانت null: استخدم قائمة فارغة []
      locationHistory: (json['locationHistory'] as List<dynamic>?)
              ?.map((e) => LocationModel.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          [],

      /// قائمة الانحرافات عن المسار
      deviations: (json['deviations'] as List<dynamic>?)
              ?.map((e) => DeviationModel.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          [],

      /// عدد التنبيهات المُطلقة خلال الرحلة
      alertsTriggered: json['alertsTriggered'] as int? ?? 0,

      /// إجمالي المسافة المقطوعة (بالكيلومترات)
      totalDistance: (json['totalDistance'] as num?)?.toDouble() ?? 0.0,

      /// السرعة المتوسطة (كم/ساعة)
      averageSpeed: (json['averageSpeed'] as num?)?.toDouble() ?? 0.0,

      /// ملاحظات المستخدم عن الرحلة
      notes: json['notes'] as String?,
    );
  }

  /// ═══════════════════════════════════════════════════════════════════════════
  /// toJson() - تحويل من TripModel إلى JSON
  /// ═══════════════════════════════════════════════════════════════════════════
  ///
  /// متى يتم استدعاء؟
  /// عندما نريد حفظ البيانات في Firebase أو إرسالها لـ API
  /// نحتاج تحويل TripModel لصيغة JSON
  ///
  /// مثال الاستخدام:
  /// ```
  /// final trip = TripModel(...)
  /// final json = trip.toJson()
  /// await firebase.collection('trips').add(json)
  /// ```

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'routeId': routeId,
      'routeName': routeName,

      /// تحويل Enum إلى نص
      /// TripStatus.active → "active"
      'status': status.name,

      /// تحويل DateTime إلى ISO 8601 string
      /// DateTime(2024, 1, 15, 10, 30) → "2024-01-15T10:30:00.000Z"
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),

      /// تحويل LocationEntity إلى LocationModel ثم toJson()
      'startLocation': LocationModel.fromEntity(startLocation).toJson(),
      'endLocation': endLocation != null
          ? LocationModel.fromEntity(endLocation!).toJson()
          : null,
      'currentLocation': currentLocation != null
          ? LocationModel.fromEntity(currentLocation!).toJson()
          : null,

      /// تحويل قائمة المواقع إلى JSON
      /// كل موقع → LocationModel → toJson()
      'locationHistory': locationHistory
          .map((e) => LocationModel.fromEntity(e).toJson())
          .toList(),

      /// تحويل قائمة الانحرافات إلى JSON
      'deviations': deviations
          .map((e) => DeviationModel.fromEntity(e).toJson())
          .toList(),

      'alertsTriggered': alertsTriggered,
      'totalDistance': totalDistance,
      'averageSpeed': averageSpeed,
      'notes': notes,
    };
  }

  /// ═══════════════════════════════════════════════════════════════════════════
  /// fromFirestore() - تحويل من Firestore Document إلى TripModel
  /// ═══════════════════════════════════════════════════════════════════════════
  ///
  /// خصوصية Firebase:
  /// عندما نحفظ في Firebase Firestore:
  /// - المعرف (ID) يُحفظ في مكان منفصل (documentId)
  /// - البيانات الأخرى تُحفظ في doc data
  /// 
  /// لذلك نحتاج:
  /// 1. دمج المعرف مع البيانات
  /// 2. ثم استدعاء fromJson()
  ///
  /// مثال:
  /// ```
  /// doc.id = "trip_123"
  /// doc.data() = {"userId": "user_456", "status": "active", ...}
  /// 
  /// fromFirestore يدمجهما:
  /// {...doc.data(), "id": doc.id}
  /// ثم يستدعي fromJson()
  /// ```

  factory TripModel.fromFirestore(Map<String, dynamic> doc, String docId) {
    /// دمج المعرف مع بيانات الـ document
    return TripModel.fromJson({...doc, 'id': docId});
  }

  /// ═══════════════════════════════════════════════════════════════════════════
  /// toFirestore() - تحويل TripModel لصيغة Firestore
  /// ═══════════════════════════════════════════════════════════════════════════
  ///
  /// الاختلاف عن toJson():
  /// Firebase Firestore يُدير المعرفات بشكل منفصل
  /// لذا لا نحتاج إرسال 'id' مع البيانات
  ///
  /// الخطوات:
  /// 1. استدعاء toJson() للحصول على جميع البيانات
  /// 2. حذف حقل 'id' (Firebase سيدينه بنفسه)
  /// 3. إرسال باقي البيانات

  Map<String, dynamic> toFirestore() {
    final json = toJson();
    json.remove('id');  /// حذف المعرف (Firebase يديره)
    return json;
  }

  /// ═══════════════════════════════════════════════════════════════════════════
  /// fromEntity() - تحويل من TripEntity إلى TripModel
  /// ═══════════════════════════════════════════════════════════════════════════
  ///
  /// السيناريو:
  /// في Domain Layer، نستخدم TripEntity
  /// في Data Layer، نستخدم TripModel
  /// هذه الدالة تحول بينهما
  ///
  /// المثال:
  /// ```
  /// // في Domain:
  /// final entity = TripEntity(...)
  /// 
  /// // في Data Layer:
  /// final model = TripModel.fromEntity(entity)
  /// await hive.saveTrip(model)
  /// ```
  ///
  /// لماذا نحتاج التحويل؟
  /// - TripEntity: عامة وليست متعلقة بـ Database
  /// - TripModel: مخصصة للـ serialization والحفظ

  factory TripModel.fromEntity(TripEntity entity) {
    return TripModel(
      id: entity.id,
      userId: entity.userId,
      routeId: entity.routeId,
      routeName: entity.routeName,
      status: entity.status,
      startTime: entity.startTime,
      endTime: entity.endTime,
      startLocation: entity.startLocation,
      endLocation: entity.endLocation,
      currentLocation: entity.currentLocation,
      locationHistory: entity.locationHistory,
      deviations: entity.deviations,
      alertsTriggered: entity.alertsTriggered,
      totalDistance: entity.totalDistance,
      averageSpeed: entity.averageSpeed,
      notes: entity.notes,
    );
  }
}

/// ═══════════════════════════════════════════════════════════════════════════
/// ملخص التحويلات في TripModel:
/// ═══════════════════════════════════════════════════════════════════════════
/// 
/// ```
/// TripEntity                TripModel
/// (Domain)                  (Data)
/// ├─ من BLoC              ├─ من Firebase/Hive
/// ├─ toJSON()            ├─ fromJSON()
/// ├─ fromEntity()        ├─ toFirestore()
/// └─ لا يعرف عن DB      └─ يعرف كل شيء عن التسلسل
/// ```
/// 
/// تدفق البيانات:
/// ```
/// Firebase JSON
///   ↓ fromFirestore()
/// TripModel
///   ↓ حفظ في Hive
/// TripModel (cached)
///   ↓ toEntity()
/// TripEntity
///   ↓ استخدام في BLoC
/// UI تعرض الرحلة
/// ```
/// 
/// ═══════════════════════════════════════════════════════════════════════════
