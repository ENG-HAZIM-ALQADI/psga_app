import 'package:hive/hive.dart';
import 'package:psga_app/features/maps/domain/entities/place_entity.dart';
import 'package:psga_app/features/routes/domain/entities/location.dart';

/// Hive Adapter لتخزين PlaceEntity
class PlaceAdapter extends TypeAdapter<PlaceEntity> {
  @override
  final int typeId = 21; // معرف فريد

  @override
  PlaceEntity read(BinaryReader reader) {
    final id = reader.readString();
    final name = reader.readString();
    final description = reader.readString();
    final lat = reader.readDouble();
    final lon = reader.readDouble();
    final address = reader.readString();
    final typeIndex = reader.readInt();
    final rating = reader.readDouble();
    final reviewCount = reader.readInt();
    final phoneNumber = reader.readString();
    final website = reader.readString();
    final isOpen = reader.readBool();
    final openingHours = reader.readString();
    final photoUrl = reader.readString();
    final distance = reader.readDouble();

    return PlaceEntity(
      id: id,
      name: name,
      description: description.isEmpty ? null : description,
      location: Location(
        latitude: lat,
        longitude: lon,
        timestamp: DateTime.now(),
      ),
      address: address.isEmpty ? null : address,
      type: PlaceType.values[typeIndex],
      rating: rating == -1 ? null : rating,
      reviewCount: reviewCount == -1 ? null : reviewCount,
      phoneNumber: phoneNumber.isEmpty ? null : phoneNumber,
      website: website.isEmpty ? null : website,
      isOpen: isOpen,
      openingHours: openingHours.isEmpty ? null : openingHours,
      photoUrl: photoUrl.isEmpty ? null : photoUrl,
      distance: distance == -1 ? null : distance,
    );
  }

  @override
  void write(BinaryWriter writer, PlaceEntity obj) {
    writer.writeString(obj.id);
    writer.writeString(obj.name);
    writer.writeString(obj.description ?? '');
    writer.writeDouble(obj.location.latitude);
    writer.writeDouble(obj.location.longitude);
    writer.writeString(obj.address ?? '');
    writer.writeInt(obj.type.index);
    writer.writeDouble(obj.rating ?? -1);
    writer.writeInt(obj.reviewCount ?? -1);
    writer.writeString(obj.phoneNumber ?? '');
    writer.writeString(obj.website ?? '');
    writer.writeBool(obj.isOpen);
    writer.writeString(obj.openingHours ?? '');
    writer.writeString(obj.photoUrl ?? '');
    writer.writeDouble(obj.distance ?? -1);
  }
}
