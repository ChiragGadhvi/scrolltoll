// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_usage_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AppUsageModelAdapter extends TypeAdapter<AppUsageModel> {
  @override
  final int typeId = 0;

  @override
  AppUsageModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AppUsageModel(
      appName: fields[0] as String,
      packageName: fields[1] as String,
      durationMinutes: fields[2] as int,
      moneyCost: fields[3] as double,
    );
  }

  @override
  void write(BinaryWriter writer, AppUsageModel obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.appName)
      ..writeByte(1)
      ..write(obj.packageName)
      ..writeByte(2)
      ..write(obj.durationMinutes)
      ..writeByte(3)
      ..write(obj.moneyCost);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppUsageModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
