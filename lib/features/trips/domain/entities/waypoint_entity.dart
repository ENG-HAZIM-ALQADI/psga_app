import 'package:equatable/equatable.dart';
import 'location_entity.dart';

/// 📌 أنواع نقاط المسار
enum WaypointType { 
  start,        // نقطة البداية
  end,          // نقطة النهاية (الوجهة)
  intermediate  // نقطة وسيطة (توقف أو علامة)
}

/// ═══════════════════════════════════════════════════════════════════════════
/// 📍 WaypointEntity - كيان نقطة المسار (Domain Layer)
/// ═══════════════════════════════════════════════════════════════════════════
/// تمثل نقطة محددة ضمن المسار المخطط له.
class WaypointEntity extends Equatable {
  final String id;                // معرف فريد
  final LocationEntity location;  // الموقع الجغرافي
  final String? name;             // اسم اختياري (مثل: "المنزل"، "مكتب البريد")
  final int order;               // ترتيب النقطة في المسار (0 للبداية، إلخ)
  final WaypointType type;        // نوع النقطة
  final DateTime? estimatedArrival; // الوقت المتوقع للوصول لهذه النقطة

  const WaypointEntity({
    required this.id,
    required this.location,
    this.name,
    required this.order,
    required this.type,
    this.estimatedArrival,
  });

  WaypointEntity copyWith({
    String? id,
    LocationEntity? location,
    String? name,
    int? order,
    WaypointType? type,
    DateTime? estimatedArrival,
  }) {
    return WaypointEntity(
      id: id ?? this.id,
      location: location ?? this.location,
      name: name ?? this.name,
      order: order ?? this.order,
      type: type ?? this.type,
      estimatedArrival: estimatedArrival ?? this.estimatedArrival,
    );
  }

  @override
  List<Object?> get props => [
        id,
        location,
        name,
        order,
        type,
        estimatedArrival,
      ];
}
