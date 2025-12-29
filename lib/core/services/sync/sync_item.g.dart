// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_item.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SyncItemAdapter extends TypeAdapter<SyncItem> {
  @override
  final int typeId = 7;

  @override
  SyncItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SyncItem(
      id: fields[0] as String?,
      type: fields[1] as SyncItemType,
      action: fields[2] as SyncAction,
      data: (fields[3] as Map).cast<String, dynamic>(),
      localId: fields[4] as String,
      remoteId: fields[5] as String?,
      createdAt: fields[6] as DateTime,
      attempts: fields[7] as int,
      lastAttempt: fields[8] as DateTime?,
      error: fields[9] as String?,
      status: fields[10] as SyncItemStatus,
    );
  }

  @override
  void write(BinaryWriter writer, SyncItem obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.type)
      ..writeByte(2)
      ..write(obj.action)
      ..writeByte(3)
      ..write(obj.data)
      ..writeByte(4)
      ..write(obj.localId)
      ..writeByte(5)
      ..write(obj.remoteId)
      ..writeByte(6)
      ..write(obj.createdAt)
      ..writeByte(7)
      ..write(obj.attempts)
      ..writeByte(8)
      ..write(obj.lastAttempt)
      ..writeByte(9)
      ..write(obj.error)
      ..writeByte(10)
      ..write(obj.status);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
