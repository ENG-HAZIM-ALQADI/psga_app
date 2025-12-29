import 'package:equatable/equatable.dart';
import 'location_entity.dart';
import 'waypoint_entity.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// 🗺️ RouteEntity - الكيان الخاص بالمسار المخطط (Domain Layer)
/// ═══════════════════════════════════════════════════════════════════════════
/// 
/// ❓ ما هو الـ Route في تطبيقنا؟
/// هو "الخريطة الورقية" أو "المخطط". هو المسار الذي يرسمه المستخدم *قبل* أن يمشي.
/// الفرق بينه وبين الـ Trip هو أن الـ Route هو "الخطة"، والـ Trip هو "التنفيذ".
///
/// 💡 شرح للمبتدئين:
/// - WaypointEntity: هي "الدبابيس" التي نضعها على الخريطة (بداية، نهاية، محطة وقود).
/// - polylinePoints: هي مئات النقاط الصغيرة جداً التي توصل بين الدبابيس لترسم خطاً ملوناً على الخريطة.
class RouteEntity extends Equatable {
  final String id;                // المعرف الفريد للمسار.
  final String userId;            // المستخدم الذي رسم هذا المسار.
  final String name;              // اسم المسار (مثلاً: "طريقي المختصر للجامعة").
  final String? description;      // شرح بسيط للطريق.
  final WaypointEntity startPoint; // من أين يبدأ؟
  final WaypointEntity endPoint;   // أين ينتهي؟
  final List<WaypointEntity> waypoints; // أي محطات توقف في المنتصف.
  final Duration estimatedDuration; // كم دقيقة "نتوقع" أن تستغرق الرحلة؟
  final double estimatedDistance;   // كم متر "نتوقع" أن تكون المسافة؟
  final bool isFavorite;           // هل المستخدم يحب هذا الطريق ووضعه في المفضلة؟
  final int usageCount;            // كم مرة مشى المستخدم في هذا الطريق فعلاً؟
  final DateTime createdAt;        // تاريخ إنشاء هذا المخطط.
  final DateTime updatedAt;        // تاريخ آخر مرة عدل فيها المستخدم المخطط.
  
  // النقاط الجغرافية الكثيفة التي ترسم الخط المتعرج على الخريطة.
  final List<LocationEntity> polylinePoints; 

  const RouteEntity({
    required this.id,
    required this.userId,
    required this.name,
    this.description,
    required this.startPoint,
    required this.endPoint,
    this.waypoints = const [],
    required this.estimatedDuration,
    required this.estimatedDistance,
    this.isFavorite = false,
    this.usageCount = 0,
    required this.createdAt,
    required this.updatedAt,
    this.polylinePoints = const [],
  });

  /// 🔹 دالة مساعدة تجمع البداية والنهاية والمحطات في قائمة واحدة لسهولة عرضها.
  List<WaypointEntity> get allWaypoints => [startPoint, ...waypoints, endPoint];

  /// 🔹 دالة الـ CopyWith: لإنشاء نسخة جديدة من المسار عند التعديل (مثلاً عند رفعه للمفضلة).
  RouteEntity copyWith({
    String? id,
    String? userId,
    String? name,
    String? description,
    WaypointEntity? startPoint,
    WaypointEntity? endPoint,
    List<WaypointEntity>? waypoints,
    Duration? estimatedDuration,
    double? estimatedDistance,
    bool? isFavorite,
    int? usageCount,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<LocationEntity>? polylinePoints,
  }) {
    return RouteEntity(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      description: description ?? this.description,
      startPoint: startPoint ?? this.startPoint,
      endPoint: endPoint ?? this.endPoint,
      waypoints: waypoints ?? this.waypoints,
      estimatedDuration: estimatedDuration ?? this.estimatedDuration,
      estimatedDistance: estimatedDistance ?? this.estimatedDistance,
      isFavorite: isFavorite ?? this.isFavorite,
      usageCount: usageCount ?? this.usageCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      polylinePoints: polylinePoints ?? this.polylinePoints,
    );
  }

  @override
  List<Object?> get props => [
        id, userId, name, description, startPoint, endPoint, waypoints,
        estimatedDuration, estimatedDistance, isFavorite, usageCount,
        createdAt, updatedAt, polylinePoints,
      ];
}
