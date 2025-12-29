import 'package:equatable/equatable.dart';
import '../../../trips/domain/entities/location_entity.dart';

enum AlertType {
  deviation,
  sos,
  inactivity,
  lowBattery,
  noConnection,
}

enum AlertLevel {
  low,
  medium,
  high,
  critical,
}

enum AlertStatus {
  pending,
  active,
  acknowledged,
  escalated,
  resolved,
  expired,
}

enum DeliveryMethod {
  inApp,
  fcm,
  sms,
  all,
}

class AlertEntity extends Equatable {
  final String id;
  final String tripId;
  final String userId;
  final AlertType type;
  final AlertLevel level;
  final AlertStatus status;
  final LocationEntity location;
  final String message;
  final DateTime triggeredAt;
  final DateTime? acknowledgedAt;
  final DateTime? escalatedAt;
  final List<String> sentToContacts;
  final DeliveryMethod deliveryMethod;
  final Map<String, dynamic> metadata;

  const AlertEntity({
    required this.id,
    required this.tripId,
    required this.userId,
    required this.type,
    required this.level,
    required this.status,
    required this.location,
    required this.message,
    required this.triggeredAt,
    this.acknowledgedAt,
    this.escalatedAt,
    this.sentToContacts = const [],
    this.deliveryMethod = DeliveryMethod.inApp,
    this.metadata = const {},
  });

  AlertEntity copyWith({
    String? id,
    String? tripId,
    String? userId,
    AlertType? type,
    AlertLevel? level,
    AlertStatus? status,
    LocationEntity? location,
    String? message,
    DateTime? triggeredAt,
    DateTime? acknowledgedAt,
    DateTime? escalatedAt,
    List<String>? sentToContacts,
    DeliveryMethod? deliveryMethod,
    Map<String, dynamic>? metadata,
  }) {
    return AlertEntity(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      level: level ?? this.level,
      status: status ?? this.status,
      location: location ?? this.location,
      message: message ?? this.message,
      triggeredAt: triggeredAt ?? this.triggeredAt,
      acknowledgedAt: acknowledgedAt ?? this.acknowledgedAt,
      escalatedAt: escalatedAt ?? this.escalatedAt,
      sentToContacts: sentToContacts ?? this.sentToContacts,
      deliveryMethod: deliveryMethod ?? this.deliveryMethod,
      metadata: metadata ?? this.metadata,
    );
  }

  bool get isActive => status == AlertStatus.active || status == AlertStatus.pending;

  String get typeDisplayName {
    switch (type) {
      case AlertType.deviation:
        return 'انحراف عن المسار';
      case AlertType.sos:
        return 'طوارئ';
      case AlertType.inactivity:
        return 'عدم حركة';
      case AlertType.lowBattery:
        return 'بطارية منخفضة';
      case AlertType.noConnection:
        return 'انقطاع الاتصال';
    }
  }

  @override
  List<Object?> get props => [
        id,
        tripId,
        userId,
        type,
        level,
        status,
        location,
        message,
        triggeredAt,
        acknowledgedAt,
        escalatedAt,
        sentToContacts,
        deliveryMethod,
        metadata,
      ];
}
