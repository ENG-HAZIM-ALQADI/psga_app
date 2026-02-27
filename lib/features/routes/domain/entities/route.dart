import 'package:equatable/equatable.dart';
import 'package:psga_app/features/routes/domain/entities/location.dart';
import 'package:psga_app/features/routes/domain/entities/waypoint.dart';

/// حالة المسار
enum RouteStatus {
  active, // نشط
  inactive, // غير نشط
  archived, // مؤرشف
}

/// كيان المسار
class RouteEntity extends Equatable {
  final String id;
  final String userId;
  final String name;
  final String? description;
  final List<Waypoint> waypoints;
  final RouteStatus status;
  final bool isFavorite;
  final double? estimatedDistance; // بالأمتار
  final int? estimatedDuration; // بالدقائق
  final DateTime createdAt;
  final DateTime updatedAt;

  const RouteEntity({
    required this.id,
    required this.userId,
    required this.name,
    required this.waypoints,
    required this.createdAt,
    required this.updatedAt,
    this.description,
    this.status = RouteStatus.active,
    this.isFavorite = false,
    this.estimatedDistance,
    this.estimatedDuration,
  });

  /// نسخ مع تعديلات
  RouteEntity copyWith({
    String? id,
    String? userId,
    String? name,
    String? description,
    List<Waypoint>? waypoints,
    RouteStatus? status,
    bool? isFavorite,
    double? estimatedDistance,
    int? estimatedDuration,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RouteEntity(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      description: description ?? this.description,
      waypoints: waypoints ?? this.waypoints,
      status: status ?? this.status,
      isFavorite: isFavorite ?? this.isFavorite,
      estimatedDistance: estimatedDistance ?? this.estimatedDistance,
      estimatedDuration: estimatedDuration ?? this.estimatedDuration,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// حساب المسافة الإجمالية للمسار
  double calculateTotalDistance() {
    if (waypoints.length < 2) return 0.0;

    double totalDistance = 0.0;
    for (int i = 0; i < waypoints.length - 1; i++) {
      totalDistance += waypoints[i].location.distanceTo(
            waypoints[i + 1].location,
          );
    }
    return totalDistance;
  }

  /// الحصول على نقطة البداية
  Location? get startLocation {
    if (waypoints.isEmpty) return null;
    return waypoints.first.location;
  }

  /// الحصول على نقطة النهاية
  Location? get endLocation {
    if (waypoints.isEmpty) return null;
    return waypoints.last.location;
  }

  /// عدد نقاط التفتيش
  int get checkpointCount {
    return waypoints.where((w) => w.isCheckpoint).length;
  }

  /// التحقق من اكتمال المسار
  bool get isComplete {
    return waypoints.length >= 2;
  }

  /// التحقق من نشاط المسار
  bool get isActive {
    return status == RouteStatus.active;
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        name,
        description,
        waypoints,
        status,
        isFavorite,
        estimatedDistance,
        estimatedDuration,
        createdAt,
        updatedAt,
      ];

  @override
  String toString() {
    return 'RouteEntity(id: $id, name: $name, waypoints: ${waypoints.length}, '
        'status: $status, favorite: $isFavorite, distance: $estimatedDistance)';
  }
}
