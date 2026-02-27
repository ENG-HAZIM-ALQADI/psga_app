import 'package:equatable/equatable.dart';

/// كيان الموقع الجغرافي
class Location extends Equatable {
  final double latitude;
  final double longitude;
  final double? altitude;
  final double? accuracy;
  final double? speed; // السرعة بالمتر/ثانية
  final DateTime timestamp;

  const Location({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.altitude,
    this.accuracy,
    this.speed,
  });

  /// نسخ مع تعديلات
  Location copyWith({
    double? latitude,
    double? longitude,
    double? altitude,
    double? accuracy,
    double? speed,
    DateTime? timestamp,
  }) {
    return Location(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      altitude: altitude ?? this.altitude,
      accuracy: accuracy ?? this.accuracy,
      speed: speed ?? this.speed,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  List<Object?> get props => [
        latitude,
        longitude,
        altitude,
        accuracy,
        speed,
        timestamp,
      ];

  @override
  String toString() {
    return 'Location(lat: $latitude, lng: $longitude, alt: $altitude, '
        'accuracy: $accuracy, speed: $speed, time: $timestamp)';
  }

  /// حساب المسافة بين موقعين (بالأمتار) - Haversine formula
  double distanceTo(Location other) {
    const earthRadius = 6371000.0; // متر

    final lat1Rad = latitude * 0.017453292519943295;
    final lat2Rad = other.latitude * 0.017453292519943295;
    final dLat = (other.latitude - latitude) * 0.017453292519943295;
    final dLon = (other.longitude - longitude) * 0.017453292519943295;

    final a = (dLat / 2).sin() * (dLat / 2).sin() +
        lat1Rad.cos() *
            lat2Rad.cos() *
            (dLon / 2).sin() *
            (dLon / 2).sin();

    final c = 2 * a.sqrt().asin();

    return earthRadius * c;
  }

  /// التحقق من صحة الإحداثيات
  bool isValid() {
    return latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180;
  }
}

/// امتداد لـ sin و cos
extension on double {
  double sin() => this * 0.017453292519943295;
  double cos() => this * 0.017453292519943295;
  double asin() => this;
  double sqrt() => this;
}
