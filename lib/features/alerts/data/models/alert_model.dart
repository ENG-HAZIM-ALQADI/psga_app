import 'package:psga_app/features/alerts/domain/entities/alert_entity.dart';
import 'package:psga_app/features/routes/data/models/location_model.dart';

/// نموذج التنبيه
class AlertModel extends AlertEntity {
  const AlertModel({
    required super.id,
    required super.userId,
    required super.type,
    required super.severity,
    required super.status,
    required super.title,
    required super.message,
    required super.triggeredAt,
    super.tripId,
    super.location,
    super.acknowledgedAt,
    super.resolvedAt,
    super.acknowledgedBy,
    super.metadata,
    super.notifiedContacts,
    super.isSent,
    super.isEscalated,
    super.escalationLevel,
  });

  /// من JSON
  factory AlertModel.fromJson(Map<String, dynamic> json) {
    return AlertModel(
      id: json['id'] as String,
      userId: json['userId'] as String,
      tripId: json['tripId'] as String?,
      type: AlertType.values.firstWhere(
        (e) => e.toString() == 'AlertType.${json['type']}',
      ),
      severity: AlertSeverity.values.firstWhere(
        (e) => e.toString() == 'AlertSeverity.${json['severity']}',
      ),
      status: AlertStatus.values.firstWhere(
        (e) => e.toString() == 'AlertStatus.${json['status']}',
      ),
      title: json['title'] as String,
      message: json['message'] as String,
      location: json['location'] != null
          ? LocationModel.fromJson(json['location'] as Map<String, dynamic>)
          : null,
      triggeredAt: _parseDateTime(json['triggeredAt']),
      acknowledgedAt: json['acknowledgedAt'] != null
          ? _parseDateTime(json['acknowledgedAt'])
          : null,
      resolvedAt: json['resolvedAt'] != null
          ? _parseDateTime(json['resolvedAt'])
          : null,
      acknowledgedBy: json['acknowledgedBy'] as String?,
      metadata: json['metadata'] != null
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : null,
      notifiedContacts: json['notifiedContacts'] != null
          ? List<String>.from(json['notifiedContacts'] as List)
          : const [],
      isSent: json['isSent'] as bool? ?? false,
      isEscalated: json['isEscalated'] as bool? ?? false,
      escalationLevel: json['escalationLevel'] as int? ?? 0,
    );
  }

  /// إلى JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'tripId': tripId,
      'type': type.toString().split('.').last,
      'severity': severity.toString().split('.').last,
      'status': status.toString().split('.').last,
      'title': title,
      'message': message,
      'location': location != null
          ? LocationModel.fromEntity(location!).toJson()
          : null,
      'triggeredAt': triggeredAt.toIso8601String(),
      'acknowledgedAt': acknowledgedAt?.toIso8601String(),
      'resolvedAt': resolvedAt?.toIso8601String(),
      'acknowledgedBy': acknowledgedBy,
      'metadata': metadata,
      'notifiedContacts': notifiedContacts,
      'isSent': isSent,
      'isEscalated': isEscalated,
      'escalationLevel': escalationLevel,
    };
  }

  /// من Entity
  factory AlertModel.fromEntity(AlertEntity entity) {
    return AlertModel(
      id: entity.id,
      userId: entity.userId,
      type: entity.type,
      severity: entity.severity,
      status: entity.status,
      title: entity.title,
      message: entity.message,
      triggeredAt: entity.triggeredAt,
      tripId: entity.tripId,
      location: entity.location,
      acknowledgedAt: entity.acknowledgedAt,
      resolvedAt: entity.resolvedAt,
      acknowledgedBy: entity.acknowledgedBy,
      metadata: entity.metadata,
      notifiedContacts: entity.notifiedContacts,
      isSent: entity.isSent,
      isEscalated: entity.isEscalated,
      escalationLevel: entity.escalationLevel,
    );
  }

  /// إلى Entity
  AlertEntity toEntity() => this;

  /// تحويل DateTime من String أو Firestore Timestamp
  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is String) return DateTime.parse(value);
    if (value is Map) {
      final seconds = value['_seconds'] as int? ?? value['seconds'] as int? ?? 0;
      return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
    }
    try { return (value as dynamic).toDate() as DateTime; } catch (_) { return DateTime.now(); }
  }
}
