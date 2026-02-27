import 'package:equatable/equatable.dart';
import 'package:psga_app/features/routes/domain/entities/location.dart';

/// كيان نقطة الطريق
class Waypoint extends Equatable {
  final String id;
  final String name;
  final String? description;
  final Location location;
  final int order;
  final double? radius; // نصف قطر المنطقة الآمنة بالأمتار
  final bool isCheckpoint; // هل هي نقطة تفتيش إجبارية
  final DateTime createdAt;

  const Waypoint({
    required this.id,
    required this.name,
    required this.location,
    required this.order,
    required this.createdAt,
    this.description,
    this.radius = 50.0,
    this.isCheckpoint = false,
  });

  /// نسخ مع تعديلات
  Waypoint copyWith({
    String? id,
    String? name,
    String? description,
    Location? location,
    int? order,
    double? radius,
    bool? isCheckpoint,
    DateTime? createdAt,
  }) {
    return Waypoint(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      location: location ?? this.location,
      order: order ?? this.order,
      radius: radius ?? this.radius,
      isCheckpoint: isCheckpoint ?? this.isCheckpoint,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// التحقق من وصول المستخدم لهذه النقطة
  bool isReached(Location currentLocation) {
    final distance = location.distanceTo(currentLocation);
    return distance <= (radius ?? 50.0);
  }

  @override
  List<Object?> get props => [
        id,
        name,
        description,
        location,
        order,
        radius,
        isCheckpoint,
        createdAt,
      ];

  @override
  String toString() {
    return 'Waypoint(id: $id, name: $name, order: $order, '
        'location: $location, radius: $radius, checkpoint: $isCheckpoint)';
  }
}
