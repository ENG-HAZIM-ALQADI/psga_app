import 'package:psga_app/features/trips/domain/entities/trip_settings_entity.dart';

/// نموذج إعدادات الرحلات للتخزين
/// Data Layer: يحول بين Entity و JSON
/// 
/// يدعم:
/// - التخزين المحلي (Hive)
/// - المزامنة مع Firebase
class TripSettingsModel {
  final String userId;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final double startLocationThreshold;
  final double lowDeviationThreshold;
  final double mediumDeviationThreshold;
  final double highDeviationThreshold;
  final bool enableLocationValidation;
  final bool enableAutoRouteCalculation;
  final bool alwaysStartFromCurrentLocation;
  final bool updateOriginalRoute;
  final int startFromHereUsageCount;

  const TripSettingsModel({
    required this.userId,
    required this.createdAt,
    required this.startLocationThreshold,
    required this.lowDeviationThreshold,
    required this.mediumDeviationThreshold,
    required this.highDeviationThreshold,
    required this.enableLocationValidation,
    required this.enableAutoRouteCalculation,
    required this.alwaysStartFromCurrentLocation,
    required this.updateOriginalRoute,
    required this.startFromHereUsageCount,
    this.updatedAt,
  });

  /// من Entity
  factory TripSettingsModel.fromEntity(TripSettingsEntity entity) {
    return TripSettingsModel(
      userId: entity.userId,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      startLocationThreshold: entity.startLocationThreshold,
      lowDeviationThreshold: entity.lowDeviationThreshold,
      mediumDeviationThreshold: entity.mediumDeviationThreshold,
      highDeviationThreshold: entity.highDeviationThreshold,
      enableLocationValidation: entity.enableLocationValidation,
      enableAutoRouteCalculation: entity.enableAutoRouteCalculation,
      alwaysStartFromCurrentLocation: entity.alwaysStartFromCurrentLocation,
      updateOriginalRoute: entity.updateOriginalRoute,
      startFromHereUsageCount: entity.startFromHereUsageCount,
    );
  }

  /// من JSON (Hive أو Firebase)
  factory TripSettingsModel.fromJson(Map<String, dynamic> json) {
    return TripSettingsModel(
      userId: json['userId'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null 
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
      startLocationThreshold: (json['startLocationThreshold'] as num?)?.toDouble() ?? 50.0,
      lowDeviationThreshold: (json['lowDeviationThreshold'] as num?)?.toDouble() ?? 50.0,
      mediumDeviationThreshold: (json['mediumDeviationThreshold'] as num?)?.toDouble() ?? 150.0,
      highDeviationThreshold: (json['highDeviationThreshold'] as num?)?.toDouble() ?? 300.0,
      enableLocationValidation: json['enableLocationValidation'] as bool? ?? true,
      enableAutoRouteCalculation: json['enableAutoRouteCalculation'] as bool? ?? true,
      alwaysStartFromCurrentLocation: json['alwaysStartFromCurrentLocation'] as bool? ?? false,
      updateOriginalRoute: json['updateOriginalRoute'] as bool? ?? false,
      startFromHereUsageCount: json['startFromHereUsageCount'] as int? ?? 0,
    );
  }

  /// إلى JSON (للـ Hive و Firebase)
  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'startLocationThreshold': startLocationThreshold,
      'lowDeviationThreshold': lowDeviationThreshold,
      'mediumDeviationThreshold': mediumDeviationThreshold,
      'highDeviationThreshold': highDeviationThreshold,
      'enableLocationValidation': enableLocationValidation,
      'enableAutoRouteCalculation': enableAutoRouteCalculation,
      'alwaysStartFromCurrentLocation': alwaysStartFromCurrentLocation,
      'updateOriginalRoute': updateOriginalRoute,
      'startFromHereUsageCount': startFromHereUsageCount,
    };
  }

  /// إلى Entity
  TripSettingsEntity toEntity() {
    return TripSettingsEntity(
      userId: userId,
      createdAt: createdAt,
      updatedAt: updatedAt,
      startLocationThreshold: startLocationThreshold,
      lowDeviationThreshold: lowDeviationThreshold,
      mediumDeviationThreshold: mediumDeviationThreshold,
      highDeviationThreshold: highDeviationThreshold,
      enableLocationValidation: enableLocationValidation,
      enableAutoRouteCalculation: enableAutoRouteCalculation,
      alwaysStartFromCurrentLocation: alwaysStartFromCurrentLocation,
      updateOriginalRoute: updateOriginalRoute,
      startFromHereUsageCount: startFromHereUsageCount,
    );
  }
  
  /// إنشاء إعدادات افتراضية للمستخدم
  factory TripSettingsModel.createDefault(String userId) {
    final now = DateTime.now();
    return TripSettingsModel(
      userId: userId,
      createdAt: now,
      updatedAt: now,
      startLocationThreshold: 50.0,
      lowDeviationThreshold: 50.0,
      mediumDeviationThreshold: 150.0,
      highDeviationThreshold: 300.0,
      enableLocationValidation: true,
      enableAutoRouteCalculation: true,
      alwaysStartFromCurrentLocation: false,
      updateOriginalRoute: false,
      startFromHereUsageCount: 0,
    );
  }
}
