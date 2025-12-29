import '../../domain/entities/alert_entity.dart';
import '../../../trips/data/models/location_model.dart';

class AlertModel extends AlertEntity {
  const AlertModel({
    required super.id,
    required super.tripId,
    required super.userId,
    required super.type,
    required super.level,
    required super.status,
    required super.location,
    required super.message,
    required super.triggeredAt,
    super.acknowledgedAt,
    super.escalatedAt,
    super.sentToContacts,
    super.deliveryMethod,
    super.metadata,
  });

  factory AlertModel.fromJson(Map<String, dynamic> json) {
    return AlertModel(
      id: json['id'] as String,
      tripId: json['tripId'] as String,
      userId: json['userId'] as String,
      type: AlertType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => AlertType.deviation,
      ),
      level: AlertLevel.values.firstWhere(
        (e) => e.name == json['level'],
        orElse: () => AlertLevel.low,
      ),
      status: AlertStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => AlertStatus.pending,
      ),
      location: LocationModel.fromJson(json['location'] as Map<String, dynamic>),
      message: json['message'] as String,
      triggeredAt: DateTime.parse(json['triggeredAt'] as String),
      acknowledgedAt: json['acknowledgedAt'] != null
          ? DateTime.parse(json['acknowledgedAt'] as String)
          : null,
      escalatedAt: json['escalatedAt'] != null
          ? DateTime.parse(json['escalatedAt'] as String)
          : null,
      sentToContacts: (json['sentToContacts'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      deliveryMethod: DeliveryMethod.values.firstWhere(
        (e) => e.name == json['deliveryMethod'],
        orElse: () => DeliveryMethod.inApp,
      ),
      metadata: (json['metadata'] as Map<String, dynamic>?) ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tripId': tripId,
      'userId': userId,
      'type': type.name,
      'level': level.name,
      'status': status.name,
      'location': LocationModel.fromEntity(location).toJson(),
      'message': message,
      'triggeredAt': triggeredAt.toIso8601String(),
      'acknowledgedAt': acknowledgedAt?.toIso8601String(),
      'escalatedAt': escalatedAt?.toIso8601String(),
      'sentToContacts': sentToContacts,
      'deliveryMethod': deliveryMethod.name,
      'metadata': metadata,
    };
  }

  factory AlertModel.fromFirestore(Map<String, dynamic> doc, String docId) {
    return AlertModel.fromJson({...doc, 'id': docId});
  }

  Map<String, dynamic> toFirestore() {
    final json = toJson();
    json.remove('id');
    return json;
  }

  factory AlertModel.fromEntity(AlertEntity entity) {
    return AlertModel(
      id: entity.id,
      tripId: entity.tripId,
      userId: entity.userId,
      type: entity.type,
      level: entity.level,
      status: entity.status,
      location: entity.location,
      message: entity.message,
      triggeredAt: entity.triggeredAt,
      acknowledgedAt: entity.acknowledgedAt,
      escalatedAt: entity.escalatedAt,
      sentToContacts: entity.sentToContacts,
      deliveryMethod: entity.deliveryMethod,
      metadata: entity.metadata,
    );
  }
}
