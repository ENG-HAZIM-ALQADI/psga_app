import '../../domain/entities/waypoint_entity.dart';
import 'location_model.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// 🛣️ WaypointModel - نموذج النقطة الوسيطة على المسار (Data Layer)
/// ═══════════════════════════════════════════════════════════════════════════
///
/// الهدف: تمثيل نقطة وسيطة على المسار (محطة راحة، نقطة اهتمام، إلخ)
///
/// مثال: في رحلة الرياض → جدة
/// - نقطة البداية: الرياض (Start)
/// - نقطة وسيطة 1: محطة الراحة في بريدة (Intermediate)
/// - نقطة وسيطة 2: مطعم في الشمالية (Intermediate)
/// - نقطة النهاية: جدة (End)

class WaypointModel extends WaypointEntity {
  const WaypointModel({
    required super.id,
    required super.location,
    super.name,
    required super.order,
    required super.type,
    super.estimatedArrival,
  });

  /// تحويل من JSON إلى WaypointModel
  factory WaypointModel.fromJson(Map<String, dynamic> json) {
    return WaypointModel(
      id: json['id'] as String,
      location: LocationModel.fromJson(Map<String, dynamic>.from(json['location'] as Map)),
      name: json['name'] as String?,
      order: json['order'] as int,          /// ترتيب النقطة على المسار
      type: WaypointType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => WaypointType.intermediate,
      ),
      estimatedArrival: json['estimatedArrival'] != null
          ? DateTime.parse(json['estimatedArrival'] as String)
          : null,
    );
  }

  /// تحويل من WaypointModel إلى JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'location': LocationModel.fromEntity(location).toJson(),
      'name': name,
      'order': order,
      'type': type.name,
      'estimatedArrival': estimatedArrival?.toIso8601String(),
    };
  }

  /// تحويل من Entity إلى Model
  factory WaypointModel.fromEntity(WaypointEntity entity) {
    return WaypointModel(
      id: entity.id,
      location: entity.location,
      name: entity.name,
      order: entity.order,
      type: entity.type,
      estimatedArrival: entity.estimatedArrival,
    );
  }

  /// تحويل من Model إلى Entity
  WaypointEntity toEntity() {
    return WaypointEntity(
      id: id,
      location: location,
      name: name,
      order: order,
      type: type,
      estimatedArrival: estimatedArrival,
    );
  }
}
