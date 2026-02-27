import 'package:psga_app/features/maps/domain/entities/place_entity.dart';
import 'package:psga_app/features/routes/domain/entities/location.dart';
import 'package:psga_app/core/utils/distance_calculator.dart';

/// نموذج بيانات للمكان
/// يرث من Entity ويضيف دوال التحويل من/إلى JSON
class PlaceModel extends PlaceEntity {
  const PlaceModel({
    required super.id,
    required super.name,
    required super.location,
    super.description,
    super.address,
    super.type,
    super.rating,
    super.reviewCount,
    super.phoneNumber,
    super.website,
    super.isOpen,
    super.openingHours,
    super.photoUrl,
    super.distance,
  });

  /// تحويل من JSON
  factory PlaceModel.fromJson(
    Map<String, dynamic> json, {
    Location? currentLocation,
    String? apiKey,
  }) {
    final geometry = json['geometry'];
    final locationData = geometry['location'];
    
    final placeLocation = Location(
      latitude: locationData['lat'] as double,
      longitude: locationData['lng'] as double,
      timestamp: DateTime.now(),
    );

    // حساب المسافة من الموقع الحالي
    double? distance;
    if (currentLocation != null) {
      final distanceMeters = DistanceCalculator.calculateDistance(
        currentLocation,
        placeLocation,
      );
      distance = distanceMeters / 1000; // تحويل إلى كيلومتر
    }

    // تحليل نوع المكان
    final types = json['types'] != null 
        ? List<String>.from(json['types'])
        : <String>[];
    final placeType = _parseTypes(types);

    // حالة الفتح
    bool isOpen = true;
    String? openingHours;
    if (json.containsKey('opening_hours')) {
      isOpen = json['opening_hours']['open_now'] ?? true;
      if (json['opening_hours']['weekday_text'] != null) {
        openingHours = (json['opening_hours']['weekday_text'] as List)
            .join('\n');
      }
    }

    // رابط الصورة
    String? photoUrl;
    if (json.containsKey('photos') && 
        json['photos'] != null && 
        (json['photos'] as List).isNotEmpty) {
      final photo = json['photos'][0];
      final photoReference = photo['photo_reference'] as String;
      if (apiKey != null) {
        photoUrl = 'https://maps.googleapis.com/maps/api/place/photo?maxwidth=400&photo_reference=$photoReference&key=$apiKey';
      }
    }

    return PlaceModel(
      id: json['place_id'] as String,
      name: json['name'] as String? ?? 'Unknown',
      description: json['vicinity'] as String?,
      location: placeLocation,
      address: json['formatted_address'] as String?,
      type: placeType,
      rating: json['rating'] != null 
          ? (json['rating'] as num).toDouble() 
          : null,
      reviewCount: json['user_ratings_total'] as int?,
      phoneNumber: json['formatted_phone_number'] as String?,
      website: json['website'] as String?,
      isOpen: isOpen,
      openingHours: openingHours,
      photoUrl: photoUrl,
      distance: distance,
    );
  }

  /// تحليل types من API إلى PlaceType
  static PlaceType _parseTypes(List<String> types) {
    if (types.contains('restaurant')) return PlaceType.restaurant;
    if (types.contains('cafe')) return PlaceType.cafe;
    if (types.contains('gas_station')) return PlaceType.gasStation;
    if (types.contains('hospital')) return PlaceType.hospital;
    if (types.contains('police')) return PlaceType.police;
    if (types.contains('mosque')) return PlaceType.mosque;
    if (types.contains('park')) return PlaceType.park;
    if (types.contains('shopping_mall')) return PlaceType.mall;
    if (types.contains('lodging')) return PlaceType.hotel;
    if (types.contains('airport')) return PlaceType.airport;
    if (types.contains('school')) return PlaceType.school;
    if (types.contains('university')) return PlaceType.university;
    if (types.contains('bank')) return PlaceType.bank;
    if (types.contains('atm')) return PlaceType.atm;
    if (types.contains('pharmacy')) return PlaceType.pharmacy;
    return PlaceType.other;
  }

  /// تحويل PlaceType إلى string للـ API
  static String placeTypeToApiString(PlaceType type) {
    switch (type) {
      case PlaceType.restaurant:
        return 'restaurant';
      case PlaceType.cafe:
        return 'cafe';
      case PlaceType.gasStation:
        return 'gas_station';
      case PlaceType.hospital:
        return 'hospital';
      case PlaceType.police:
        return 'police';
      case PlaceType.mosque:
        return 'mosque';
      case PlaceType.park:
        return 'park';
      case PlaceType.mall:
        return 'shopping_mall';
      case PlaceType.hotel:
        return 'lodging';
      case PlaceType.airport:
        return 'airport';
      case PlaceType.school:
        return 'school';
      case PlaceType.university:
        return 'university';
      case PlaceType.bank:
        return 'bank';
      case PlaceType.atm:
        return 'atm';
      case PlaceType.pharmacy:
        return 'pharmacy';
      case PlaceType.other:
        return 'point_of_interest';
    }
  }

  /// تحويل إلى Entity
  PlaceEntity toEntity() {
    return PlaceEntity(
      id: id,
      name: name,
      description: description,
      location: location,
      address: address,
      type: type,
      rating: rating,
      reviewCount: reviewCount,
      phoneNumber: phoneNumber,
      website: website,
      isOpen: isOpen,
      openingHours: openingHours,
      photoUrl: photoUrl,
      distance: distance,
    );
  }

  /// تحويل إلى JSON
  Map<String, dynamic> toJson() {
    return {
      'place_id': id,
      'name': name,
      'vicinity': description,
      'formatted_address': address,
      'geometry': {
        'location': {
          'lat': location.latitude,
          'lng': location.longitude,
        },
      },
      'types': [placeTypeToApiString(type)],
      'rating': rating,
      'user_ratings_total': reviewCount,
      'formatted_phone_number': phoneNumber,
      'website': website,
      'opening_hours': isOpen
          ? {'open_now': isOpen}
          : null,
    };
  }
}
