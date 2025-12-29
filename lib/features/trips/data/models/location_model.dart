import '../../domain/entities/location_entity.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// 📍 LocationModel - نموذج الموقع الجغرافي (Data Layer)
/// ═══════════════════════════════════════════════════════════════════════════
///
/// الهدف: تمثيل موقع جغرافي واحد (نقطة على الخريطة)
///
/// معلومات الموقع:
/// - latitude: الخط العرضي (الموقع الشمالي/الجنوبي)
/// - longitude: الخط الطولي (الموقع الشرقي/الغربي)
/// - altitude: الارتفاع عن سطح الأرض (اختياري)
/// - accuracy: دقة القراءة بالأمتار (اختياري)
/// - timestamp: متى تم تسجيل هذا الموقع؟
/// - address: العنوان النصي (اختياري)
///
/// مثال الموقع:
/// ```
/// LocationModel(
///   latitude: 24.7136,
///   longitude: 46.6753,
///   altitude: 500.0,          // متر
///   accuracy: 10.0,           // ± 10 متر
///   timestamp: DateTime.now(),
///   address: "الرياض - السعودية"
/// )
/// ```

class LocationModel extends LocationEntity {
  const LocationModel({
    required super.latitude,
    required super.longitude,
    super.altitude,
    super.accuracy,
    required super.timestamp,
    super.address,
  });

  /// ═══════════════════════════════════════════════════════════════════════════
  /// fromJson() - تحويل من JSON إلى LocationModel
  /// ═══════════════════════════════════════════════════════════════════════════
  /// 
  /// مثال JSON:
  /// ```json
  /// {
  ///   "latitude": 24.7136,
  ///   "longitude": 46.6753,
  ///   "altitude": 500.5,
  ///   "accuracy": 10.2,
  ///   "timestamp": "2024-01-15T10:30:00.000Z",
  ///   "address": "الرياض"
  /// }
  /// ```

  factory LocationModel.fromJson(Map<String, dynamic> json) {
    return LocationModel(
      /// الخط العرضي (يجب تحويل من num إلى double)
      latitude: (json['latitude'] as num).toDouble(),
      
      /// الخط الطولي
      longitude: (json['longitude'] as num).toDouble(),
      
      /// الارتفاع (اختياري)
      altitude: json['altitude'] != null ? (json['altitude'] as num).toDouble() : null,
      
      /// دقة القراءة بالأمتار (اختياري)
      accuracy: json['accuracy'] != null ? (json['accuracy'] as num).toDouble() : null,
      
      /// الوقت (نصي → DateTime)
      timestamp: DateTime.parse(json['timestamp'] as String),
      
      /// العنوان (اختياري)
      address: json['address'] as String?,
    );
  }

  /// ═══════════════════════════════════════════════════════════════════════════
  /// toJson() - تحويل من LocationModel إلى JSON
  /// ═══════════════════════════════════════════════════════════════════════════

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'altitude': altitude,
      'accuracy': accuracy,
      'timestamp': timestamp.toIso8601String(),
      'address': address,
    };
  }

  /// ═══════════════════════════════════════════════════════════════════════════
  /// fromEntity() - تحويل من LocationEntity إلى LocationModel
  /// ═══════════════════════════════════════════════════════════════════════════

  factory LocationModel.fromEntity(LocationEntity entity) {
    return LocationModel(
      latitude: entity.latitude,
      longitude: entity.longitude,
      altitude: entity.altitude,
      accuracy: entity.accuracy,
      timestamp: entity.timestamp,
      address: entity.address,
    );
  }

  /// ═══════════════════════════════════════════════════════════════════════════
  /// toEntity() - تحويل من LocationModel إلى LocationEntity
  /// ═══════════════════════════════════════════════════════════════════════════

  LocationEntity toEntity() {
    return LocationEntity(
      latitude: latitude,
      longitude: longitude,
      altitude: altitude,
      accuracy: accuracy,
      timestamp: timestamp,
      address: address,
    );
  }
}
