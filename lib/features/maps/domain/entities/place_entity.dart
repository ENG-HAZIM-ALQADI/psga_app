import 'package:equatable/equatable.dart';
import 'package:psga_app/features/routes/domain/entities/location.dart';

/// نوع المكان
enum PlaceType {
  restaurant,
  cafe,
  gasStation,
  hospital,
  police,
  mosque,
  park,
  mall,
  hotel,
  airport,
  school,
  university,
  bank,
  atm,
  pharmacy,
  other,
}

/// كيان المكان
class PlaceEntity extends Equatable {
  final String id;
  final String name;
  final String? description;
  final Location location;
  final String? address;
  final PlaceType type;
  final double? rating;
  final int? reviewCount;
  final String? phoneNumber;
  final String? website;
  final bool isOpen;
  final String? openingHours;
  final String? photoUrl;
  final double? distance; // المسافة من الموقع الحالي (بالكيلومترات)

  const PlaceEntity({
    required this.id,
    required this.name,
    required this.location,
    this.description,
    this.address,
    this.type = PlaceType.other,
    this.rating,
    this.reviewCount,
    this.phoneNumber,
    this.website,
    this.isOpen = true,
    this.openingHours,
    this.photoUrl,
    this.distance,
  });

  @override
  List<Object?> get props => [
        id,
        name,
        description,
        location,
        address,
        type,
        rating,
        reviewCount,
        phoneNumber,
        website,
        isOpen,
        openingHours,
        photoUrl,
        distance,
      ];

  /// نسخ مع تعديلات
  PlaceEntity copyWith({
    String? id,
    String? name,
    String? description,
    Location? location,
    String? address,
    PlaceType? type,
    double? rating,
    int? reviewCount,
    String? phoneNumber,
    String? website,
    bool? isOpen,
    String? openingHours,
    String? photoUrl,
    double? distance,
  }) {
    return PlaceEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      location: location ?? this.location,
      address: address ?? this.address,
      type: type ?? this.type,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      website: website ?? this.website,
      isOpen: isOpen ?? this.isOpen,
      openingHours: openingHours ?? this.openingHours,
      photoUrl: photoUrl ?? this.photoUrl,
      distance: distance ?? this.distance,
    );
  }

  /// الحصول على وصف النوع
  static String getTypeDescription(PlaceType type) {
    switch (type) {
      case PlaceType.restaurant:
        return 'مطعم';
      case PlaceType.cafe:
        return 'مقهى';
      case PlaceType.gasStation:
        return 'محطة وقود';
      case PlaceType.hospital:
        return 'مستشفى';
      case PlaceType.police:
        return 'مركز شرطة';
      case PlaceType.mosque:
        return 'مسجد';
      case PlaceType.park:
        return 'حديقة';
      case PlaceType.mall:
        return 'مركز تسوق';
      case PlaceType.hotel:
        return 'فندق';
      case PlaceType.airport:
        return 'مطار';
      case PlaceType.school:
        return 'مدرسة';
      case PlaceType.university:
        return 'جامعة';
      case PlaceType.bank:
        return 'بنك';
      case PlaceType.atm:
        return 'صراف آلي';
      case PlaceType.pharmacy:
        return 'صيدلية';
      case PlaceType.other:
        return 'أخرى';
    }
  }

  /// تنسيق المسافة
  String get formattedDistance {
    if (distance == null) return '';
    if (distance! < 1) {
      return '${(distance! * 1000).toStringAsFixed(0)} م';
    }
    return '${distance!.toStringAsFixed(1)} كم';
  }

  /// تنسيق التقييم
  String get formattedRating {
    if (rating == null) return 'لا يوجد تقييم';
    return '${rating!.toStringAsFixed(1)} ⭐';
  }
}
