import 'package:hive/hive.dart';
import 'package:psga_app/features/alerts/data/models/contact_model.dart';
import 'package:psga_app/features/alerts/domain/entities/contact_entity.dart';

class ContactModelAdapter extends TypeAdapter<ContactModel> {
  @override
  final int typeId = 5;

  @override
  ContactModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    
    return ContactModel(
      id: fields[0] as String,
      userId: fields[1] as String,
      name: fields[2] as String,
      phoneNumber: fields[3] as String,
      email: fields[4] as String?,
      type: ContactType.values[fields[5] as int],
      isPrimary: fields[6] as bool? ?? false,
      receivesSMS: fields[7] as bool? ?? true,
      receivesEmail: fields[8] as bool? ?? false,
      receivesPushNotification: fields[9] as bool? ?? false,
      priority: fields[10] as int? ?? 999,
      createdAt: DateTime.parse(fields[11] as String),
      updatedAt: fields[12] != null ? DateTime.parse(fields[12] as String) : null,
    );
  }

  @override
  void write(BinaryWriter writer, ContactModel obj) {
    writer
      ..writeByte(13)
      ..writeByte(0) ..write(obj.id)
      ..writeByte(1) ..write(obj.userId)
      ..writeByte(2) ..write(obj.name)
      ..writeByte(3) ..write(obj.phoneNumber)
      ..writeByte(4) ..write(obj.email)
      ..writeByte(5) ..write(obj.type.index)
      ..writeByte(6) ..write(obj.isPrimary)
      ..writeByte(7) ..write(obj.receivesSMS)
      ..writeByte(8) ..write(obj.receivesEmail)
      ..writeByte(9) ..write(obj.receivesPushNotification)
      ..writeByte(10) ..write(obj.priority)
      ..writeByte(11) ..write(obj.createdAt.toIso8601String())
      ..writeByte(12) ..write(obj.updatedAt?.toIso8601String());
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ContactModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
