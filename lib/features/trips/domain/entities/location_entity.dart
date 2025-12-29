import 'dart:math';
import 'package:equatable/equatable.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// 📍 LocationEntity - كيان الموقع الجغرافي (Domain Layer)
/// ═══════════════════════════════════════════════════════════════════════════
/// يمثل نقطة جغرافية محددة على كوكب الأرض مع بيانات تكميلية مثل الارتفاع والدقة.
class LocationEntity extends Equatable {
  final double latitude;   // خط العرض
  final double longitude;  // خط الطول
  final double? altitude;  // الارتفاع عن سطح البحر (اختياري)
  final double? accuracy;  // دقة تحديد الموقع بالأمتار (اختياري)
  final DateTime timestamp; // وقت رصد هذا الموقع
  final String? address;   // العنوان النصي (اختياري، يتم جلبه عبر Geocoding)

  const LocationEntity({
    required this.latitude,
    required this.longitude,
    this.altitude,
    this.accuracy,
    required this.timestamp,
    this.address,
  });

  /// 🔹 حساب المسافة بين موقعين (باستخدام معادلة Haversine)
  /// تعيد المسافة بالأمتار.
  double distanceTo(LocationEntity other) {
    const double earthRadius = 6371000; // نصف قطر الأرض بالأمتار
    
    final double lat1Rad = latitude * pi / 180;
    final double lat2Rad = other.latitude * pi / 180;
    final double deltaLatRad = (other.latitude - latitude) * pi / 180;
    final double deltaLngRad = (other.longitude - longitude) * pi / 180;

    final double a = sin(deltaLatRad / 2) * sin(deltaLatRad / 2) +
        cos(lat1Rad) * cos(lat2Rad) *
        sin(deltaLngRad / 2) * sin(deltaLngRad / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  /// 🔹 تحويل لإحداثيات بسيطة (Map)
  Map<String, double> toLatLng() {
    return {
      'lat': latitude,
      'lng': longitude,
    };
  }

  /// 🔹 إنشاء نسخة معدلة
  LocationEntity copyWith({
    double? latitude,
    double? longitude,
    double? altitude,
    double? accuracy,
    DateTime? timestamp,
    String? address,
  }) {
    return LocationEntity(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      altitude: altitude ?? this.altitude,
      accuracy: accuracy ?? this.accuracy,
      timestamp: timestamp ?? this.timestamp,
      address: address ?? this.address,
    );
  }

  @override
  List<Object?> get props => [
        latitude,
        longitude,
        altitude,
        accuracy,
        timestamp,
        address,
      ];
}
