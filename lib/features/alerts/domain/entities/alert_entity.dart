import 'package:equatable/equatable.dart';
import 'package:psga_app/features/routes/domain/entities/location.dart';

/// أنواع التنبيهات
enum AlertType {
  deviation,        // انحراف عن المسار
  sos,             // طوارئ SOS
  checkpoint,      // نقطة تفتيش
  speedLimit,      // تجاوز السرعة
  lowBattery,      // بطارية منخفضة
  noMovement,      // عدم حركة
  geofence,        // خروج من منطقة جغرافية
  custom,          // تنبيه مخصص
}

/// مستويات خطورة التنبيه
enum AlertSeverity {
  low,      // منخفض
  medium,   // متوسط
  high,     // عالي
  critical, // حرج
}

/// حالة التنبيه
enum AlertStatus {
  triggered,    // تم الإطلاق
  pending,      // معلق
  acknowledged, // تم الإقرار
  escalated,    // تم التصعيد
  resolved,     // تم الحل
  cancelled,    // ملغي
  ignored,      // تم التجاهل
}

/// كيان التنبيه
class AlertEntity extends Equatable {
  final String id;
  final String userId;
  final String? tripId;
  final AlertType type;
  final AlertSeverity severity;
  final AlertStatus status;
  final String title;
  final String message;
  final Location? location;
  final DateTime triggeredAt;
  final DateTime? acknowledgedAt;
  final DateTime? resolvedAt;
  final String? acknowledgedBy;
  final Map<String, dynamic>? metadata;
  final List<String> notifiedContacts;
  final bool isSent;
  final bool isEscalated;
  final int escalationLevel;

  const AlertEntity({
    required this.id,
    required this.userId,
    required this.type,
    required this.severity,
    required this.status,
    required this.title,
    required this.message,
    required this.triggeredAt,
    this.tripId,
    this.location,
    this.acknowledgedAt,
    this.resolvedAt,
    this.acknowledgedBy,
    this.metadata,
    this.notifiedContacts = const [],
    this.isSent = false,
    this.isEscalated = false,
    this.escalationLevel = 0,
  });

  @override
  List<Object?> get props => [
        id,
        userId,
        tripId,
        type,
        severity,
        status,
        title,
        message,
        location,
        triggeredAt,
        acknowledgedAt,
        resolvedAt,
        acknowledgedBy,
        metadata,
        notifiedContacts,
        isSent,
        isEscalated,
        escalationLevel,
      ];

  /// هل التنبيه نشط؟
  bool get isActive => status == AlertStatus.pending || status == AlertStatus.escalated;

  /// هل التنبيه تم الإقرار به؟
  bool get isAcknowledged => acknowledgedAt != null;

  /// هل التنبيه تم حله؟
  bool get isResolved => status == AlertStatus.resolved;

  /// مدة التنبيه منذ الإطلاق
  Duration get duration => DateTime.now().difference(triggeredAt);

  /// هل يجب التصعيد؟
  bool shouldEscalate(Duration threshold) {
    return isActive && 
           !isEscalated && 
           duration > threshold &&
           severity != AlertSeverity.low;
  }

  /// نسخ مع تعديلات
  AlertEntity copyWith({
    String? id,
    String? userId,
    String? tripId,
    AlertType? type,
    AlertSeverity? severity,
    AlertStatus? status,
    String? title,
    String? message,
    Location? location,
    DateTime? triggeredAt,
    DateTime? acknowledgedAt,
    DateTime? resolvedAt,
    String? acknowledgedBy,
    Map<String, dynamic>? metadata,
    List<String>? notifiedContacts,
    bool? isSent,
    bool? isEscalated,
    int? escalationLevel,
  }) {
    return AlertEntity(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      tripId: tripId ?? this.tripId,
      type: type ?? this.type,
      severity: severity ?? this.severity,
      status: status ?? this.status,
      title: title ?? this.title,
      message: message ?? this.message,
      location: location ?? this.location,
      triggeredAt: triggeredAt ?? this.triggeredAt,
      acknowledgedAt: acknowledgedAt ?? this.acknowledgedAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      acknowledgedBy: acknowledgedBy ?? this.acknowledgedBy,
      metadata: metadata ?? this.metadata,
      notifiedContacts: notifiedContacts ?? this.notifiedContacts,
      isSent: isSent ?? this.isSent,
      isEscalated: isEscalated ?? this.isEscalated,
      escalationLevel: escalationLevel ?? this.escalationLevel,
    );
  }

  /// الحصول على وصف النوع
  static String getTypeDescription(AlertType type) {
    switch (type) {
      case AlertType.deviation:
        return 'انحراف عن المسار';
      case AlertType.sos:
        return 'طوارئ SOS';
      case AlertType.checkpoint:
        return 'نقطة تفتيش';
      case AlertType.speedLimit:
        return 'تجاوز السرعة';
      case AlertType.lowBattery:
        return 'بطارية منخفضة';
      case AlertType.noMovement:
        return 'عدم حركة';
      case AlertType.geofence:
        return 'خروج من المنطقة';
      case AlertType.custom:
        return 'تنبيه مخصص';
    }
  }

  /// الحصول على وصف الخطورة
  static String getSeverityDescription(AlertSeverity severity) {
    switch (severity) {
      case AlertSeverity.low:
        return 'منخفض';
      case AlertSeverity.medium:
        return 'متوسط';
      case AlertSeverity.high:
        return 'عالي';
      case AlertSeverity.critical:
        return 'حرج';
    }
  }

  /// الحصول على وصف الحالة
  static String getStatusDescription(AlertStatus status) {
    switch (status) {
      case AlertStatus.triggered:
        return 'تم الإطلاق';
      case AlertStatus.pending:
        return 'معلق';
      case AlertStatus.acknowledged:
        return 'تم الإقرار';
      case AlertStatus.escalated:
        return 'تم التصعيد';
      case AlertStatus.resolved:
        return 'تم الحل';
      case AlertStatus.cancelled:
        return 'ملغي';
      case AlertStatus.ignored:
        return 'تم التجاهل';
    }
  }
}
