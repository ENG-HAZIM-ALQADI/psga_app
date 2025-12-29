import '../../domain/entities/deviation_entity.dart';
import 'location_model.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// ⚠️ DeviationModel - نموذج الانحراف عن المسار (Data Layer)
/// ═══════════════════════════════════════════════════════════════════════════
///
/// الهدف: تسجيل حالات انحراف المستخدم عن المسار المرسوم
///
/// مثال: كان يجب الذهاب شرقاً لكنه ذهب غرباً بـ 500 متر
/// هذا تنبيه لأن المستخدم قد يكون تائهاً أو في خطر
///
/// مستويات الانحراف:
/// 🟢 Low: 50-200 متر (انحراف بسيط)
/// 🟡 Medium: 200-500 متر (انحراف متوسط)
/// 🔴 High: أكثر من 500 متر (انحراف كبير - قد يحتاج تنبيه)

class DeviationModel extends DeviationEntity {
  const DeviationModel({
    required super.id,
    required super.tripId,
    required super.location,
    required super.expectedLocation,
    required super.distanceFromRoute,
    required super.detectedAt,
    required super.severity,
    super.wasAlertSent,
  });

  /// تحويل من JSON إلى DeviationModel
  factory DeviationModel.fromJson(Map<String, dynamic> json) {
    return DeviationModel(
      id: json['id'] as String,
      tripId: json['tripId'] as String,
      location: LocationModel.fromJson(json['location'] as Map<String, dynamic>),
      expectedLocation: LocationModel.fromJson(json['expectedLocation'] as Map<String, dynamic>),
      distanceFromRoute: (json['distanceFromRoute'] as num).toDouble(),
      detectedAt: DateTime.parse(json['detectedAt'] as String),
      severity: DeviationSeverity.values.firstWhere(
        (e) => e.name == json['severity'],
        orElse: () => DeviationSeverity.low,
      ),
      wasAlertSent: json['wasAlertSent'] as bool? ?? false,
    );
  }

  /// تحويل من DeviationModel إلى JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tripId': tripId,
      'location': LocationModel.fromEntity(location).toJson(),
      'expectedLocation': LocationModel.fromEntity(expectedLocation).toJson(),
      'distanceFromRoute': distanceFromRoute,
      'detectedAt': detectedAt.toIso8601String(),
      'severity': severity.name,
      'wasAlertSent': wasAlertSent,
    };
  }

  /// تحويل من Entity إلى Model
  factory DeviationModel.fromEntity(DeviationEntity entity) {
    return DeviationModel(
      id: entity.id,
      tripId: entity.tripId,
      location: entity.location,
      expectedLocation: entity.expectedLocation,
      distanceFromRoute: entity.distanceFromRoute,
      detectedAt: entity.detectedAt,
      severity: entity.severity,
      wasAlertSent: entity.wasAlertSent,
    );
  }
}
