import 'package:hive/hive.dart';
import 'package:psga_app/features/auth/data/models/user_model.dart';

/// Hive Type Adapter للمستخدم
class UserModelAdapter extends TypeAdapter<UserModel> {
  @override
  final int typeId = 0; // يجب أن يكون فريداً لكل Model

  @override
  UserModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    
    return UserModel(
      id: fields[0] as String,
      email: fields[1] as String,
      name: fields[2] as String,
      emailVerified: fields[3] as bool,
      createdAt: DateTime.parse(fields[4] as String),
      photoUrl: fields[5] as String?,
      phoneNumber: fields[6] as String?,
      lastLoginAt: fields[7] != null ? DateTime.parse(fields[7] as String) : null,
    );
  }

  @override
  void write(BinaryWriter writer, UserModel obj) {
    writer
      ..writeByte(8) // عدد الحقول
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.email)
      ..writeByte(2)
      ..write(obj.name)
      ..writeByte(3)
      ..write(obj.emailVerified)
      ..writeByte(4)
      ..write(obj.createdAt.toIso8601String())
      ..writeByte(5)
      ..write(obj.photoUrl)
      ..writeByte(6)
      ..write(obj.phoneNumber)
      ..writeByte(7)
      ..write(obj.lastLoginAt?.toIso8601String());
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
