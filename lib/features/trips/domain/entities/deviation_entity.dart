import 'package:equatable/equatable.dart';
import 'location_entity.dart';

/// 📌 مستويات شدة الانحراف
enum DeviationSeverity { 
  low,      // خفيف (مسافة بسيطة)
  medium,   // متوسط
  high,     // عالٍ (خطر محتمل)
  critical  // حرج (خطر فوري، استغاثة)
}

/// ═══════════════════════════════════════════════════════════════════════════
/// ⚠️ DeviationEntity - كيان الانحراف عن المسار (Domain Layer)
/// ═══════════════════════════════════════════════════════════════════════════
/// يمثل واقعة خروج المستخدم عن المسار المحدد له في التطبيق.
class DeviationEntity extends Equatable {
  final String id;                  // معرف الانحراف
  final String tripId;              // الرحلة التي حدث فيها الانحراف
  final LocationEntity location;    // الموقع الفعلي الذي رصد فيه الانحراف
  final LocationEntity expectedLocation; // الموقع الذي كان من المفترض التواجد فيه
  final double distanceFromRoute;   // المسافة الفاصلة عن المسار (بالأمتار)
  final DateTime detectedAt;        // وقت اكتشاف الانحراف
  final DeviationSeverity severity; // مستوى الخطورة
  final bool wasAlertSent;          // هل تم إرسال تنبيه للطوارئ بخصوص هذا الانحراف؟

  const DeviationEntity({
    required this.id,
    required this.tripId,
    required this.location,
    required this.expectedLocation,
    required this.distanceFromRoute,
    required this.detectedAt,
    required this.severity,
    this.wasAlertSent = false,
  });

  DeviationEntity copyWith({
    String? id,
    String? tripId,
    LocationEntity? location,
    LocationEntity? expectedLocation,
    double? distanceFromRoute,
    DateTime? detectedAt,
    DeviationSeverity? severity,
    bool? wasAlertSent,
  }) {
    return DeviationEntity(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      location: location ?? this.location,
      expectedLocation: expectedLocation ?? this.expectedLocation,
      distanceFromRoute: distanceFromRoute ?? this.distanceFromRoute,
      detectedAt: detectedAt ?? this.detectedAt,
      severity: severity ?? this.severity,
      wasAlertSent: wasAlertSent ?? this.wasAlertSent,
    );
  }

  /// 🔹 دالة مساعدة لتحديد مستوى الخطورة بناءً على المسافة
  static DeviationSeverity getSeverityFromDistance(double distance) {
    if (distance < 50) return DeviationSeverity.low;
    if (distance < 100) return DeviationSeverity.medium;
    if (distance < 200) return DeviationSeverity.high;
    return DeviationSeverity.critical;
  }

  @override
  List<Object?> get props => [
        id,
        tripId,
        location,
        expectedLocation,
        distanceFromRoute,
        detectedAt,
        severity,
        wasAlertSent,
      ];
}
