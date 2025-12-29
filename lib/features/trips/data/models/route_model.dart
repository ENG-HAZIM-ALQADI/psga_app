import '../../domain/entities/route_entity.dart';
import 'waypoint_model.dart';
import 'location_model.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// 🛣️ RouteModel - نموذج المسار (Data Layer)
/// ═══════════════════════════════════════════════════════════════════════════
///
/// الهدف: تمثيل المسار الواحد مع جميع البيانات المتعلقة به
///
/// المسار في PSGA:
/// - مجموعة من النقاط المحفوظة (Waypoints)
/// - نقطة بداية ونهاية
/// - معلومات توضيحية (اسم، وصف، مسافة متوقعة، إلخ)
/// - إحصائيات الاستخدام (كم مرة استُخدم؟ هل هو مفضل؟)
///
/// مثال واقعي:
/// ```
/// الرياض → جدة (بسيارة)
/// ├─ نقاط وسيطة (محطات للراحة)
/// ├─ مسافة متوقعة: 900 كم
/// ├─ وقت متوقع: 12 ساعة
/// └─ مستخدم مرات أخرى: 5 مرات
/// ```

class RouteModel extends RouteEntity {
  const RouteModel({
    required super.id,
    required super.userId,
    required super.name,
    super.description,
    required super.startPoint,
    required super.endPoint,
    super.waypoints,
    required super.estimatedDuration,
    required super.estimatedDistance,
    super.isFavorite,
    super.usageCount,
    required super.createdAt,
    required super.updatedAt,
    super.polylinePoints,
  });

  /// ═══════════════════════════════════════════════════════════════════════════
  /// fromJson() - تحويل من JSON إلى RouteModel
  /// ═══════════════════════════════════════════════════════════════════════════
  /// 
  /// الاستخدام: عندما نجلب مسار من Firebase أو API
  /// 
  /// مثال JSON:
  /// ```json
  /// {
  ///   "id": "route_123",
  ///   "userId": "user_456",
  ///   "name": "الرياض → جدة",
  ///   "startPoint": {"latitude": 24.7136, "longitude": 46.6753, ...},
  ///   "endPoint": {"latitude": 21.5433, "longitude": 39.1735, ...},
  ///   "waypoints": [...],
  ///   "estimatedDurationSeconds": 43200,  // 12 ساعة
  ///   "estimatedDistance": 900.5,
  ///   "polylinePoints": [...]
  /// }
  /// ```

  factory RouteModel.fromJson(Map<String, dynamic> json) {
    return RouteModel(
      id: json['id'] as String,
      userId: json['userId'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      
      /// تحويل نقطة البداية من JSON
      startPoint: WaypointModel.fromJson(Map<String, dynamic>.from(json['startPoint'] as Map)),
      
      /// تحويل نقطة النهاية من JSON
      endPoint: WaypointModel.fromJson(Map<String, dynamic>.from(json['endPoint'] as Map)),
      
      /// تحويل النقاط الوسيطة (أو قائمة فارغة إذا لم تكن موجودة)
      waypoints: (json['waypoints'] as List<dynamic>?)
              ?.map((e) => WaypointModel.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          [],
      
      /// الوقت المتوقع بالثواني → تحويل إلى Duration
      /// مثال: 43200 ثانية = 12 ساعة
      estimatedDuration: Duration(seconds: json['estimatedDurationSeconds'] as int),
      
      /// المسافة المتوقعة (بالكيلومترات)
      estimatedDistance: (json['estimatedDistance'] as num).toDouble(),
      
      /// هل هذا المسار مفضل؟
      isFavorite: json['isFavorite'] as bool? ?? false,
      
      /// كم مرة استُخدم هذا المسار؟
      usageCount: json['usageCount'] as int? ?? 0,
      
      /// متى تم إنشاء المسار؟
      createdAt: DateTime.parse(json['createdAt'] as String),
      
      /// متى تم تحديث المسار آخر مرة؟
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      
      /// نقاط الخط (للرسم على الخريطة)
      /// polylinePoints = جميع النقاط على المسار (لرسمه على Google Maps)
      polylinePoints: (json['polylinePoints'] as List<dynamic>?)
              ?.map((e) => LocationModel.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          [],
    );
  }

  /// ═══════════════════════════════════════════════════════════════════════════
  /// toJson() - تحويل من RouteModel إلى JSON
  /// ═══════════════════════════════════════════════════════════════════════════
  /// 
  /// الاستخدام: عندما نريد حفظ المسار في Firebase

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'description': description,
      
      /// تحويل Waypoint إلى JSON
      'startPoint': WaypointModel.fromEntity(startPoint).toJson(),
      'endPoint': WaypointModel.fromEntity(endPoint).toJson(),
      
      /// تحويل قائمة النقاط الوسيطة إلى JSON
      'waypoints': waypoints.map((e) => WaypointModel.fromEntity(e).toJson()).toList(),
      
      /// تحويل Duration إلى ثواني (Firebase يفضل الأرقام على Duration)
      'estimatedDurationSeconds': estimatedDuration.inSeconds,
      
      'estimatedDistance': estimatedDistance,
      'isFavorite': isFavorite,
      'usageCount': usageCount,
      
      /// تحويل DateTime إلى ISO 8601
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      
      /// تحويل نقاط الخط إلى JSON
      'polylinePoints': polylinePoints.map((e) => LocationModel.fromEntity(e).toJson()).toList(),
    };
  }

  /// ═══════════════════════════════════════════════════════════════════════════
  /// fromFirestore() و toFirestore() - تحويل لـ Firebase Firestore
  /// ═══════════════════════════════════════════════════════════════════════════
  /// 
  /// Firebase Firestore يدير المعرفات بشكل منفصل عن البيانات

  factory RouteModel.fromFirestore(Map<String, dynamic> doc, String docId) {
    return RouteModel.fromJson({...doc, 'id': docId});
  }

  Map<String, dynamic> toFirestore() {
    final json = toJson();
    json.remove('id');
    return json;
  }

  /// ═══════════════════════════════════════════════════════════════════════════
  /// fromEntity() - تحويل من RouteEntity إلى RouteModel
  /// ═══════════════════════════════════════════════════════════════════════════

  factory RouteModel.fromEntity(RouteEntity entity) {
    return RouteModel(
      id: entity.id,
      userId: entity.userId,
      name: entity.name,
      description: entity.description,
      startPoint: entity.startPoint,
      endPoint: entity.endPoint,
      waypoints: entity.waypoints,
      estimatedDuration: entity.estimatedDuration,
      estimatedDistance: entity.estimatedDistance,
      isFavorite: entity.isFavorite,
      usageCount: entity.usageCount,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      polylinePoints: entity.polylinePoints,
    );
  }
}
