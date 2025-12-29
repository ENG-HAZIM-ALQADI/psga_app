import 'package:equatable/equatable.dart';
import 'package:psga_app/features/trips/domain/entities/location_entity.dart';

/// كيان المكان - يمثل موقعاً جغرافياً
class PlaceEntity extends Equatable {
  final String placeId;
  final String name;
  final String address;
  final LocationEntity location;
  final List<String> types;
  final double? rating;
  final bool? isOpen;

  const PlaceEntity({
    required this.placeId,
    required this.name,
    required this.address,
    required this.location,
    this.types = const [],
    this.rating,
    this.isOpen,
  });

  PlaceEntity copyWith({
    String? placeId,
    String? name,
    String? address,
    LocationEntity? location,
    List<String>? types,
    double? rating,
    bool? isOpen,
  }) {
    return PlaceEntity(
      placeId: placeId ?? this.placeId,
      name: name ?? this.name,
      address: address ?? this.address,
      location: location ?? this.location,
      types: types ?? this.types,
      rating: rating ?? this.rating,
      isOpen: isOpen ?? this.isOpen,
    );
  }

  @override
  List<Object?> get props => [
        placeId,
        name,
        address,
        location,
        types,
        rating,
        isOpen,
      ];

  @override
  String toString() => 'PlaceEntity(name: $name, address: $address)';
}
