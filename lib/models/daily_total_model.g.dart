// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'daily_total_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DailyTotalModelAdapter extends TypeAdapter<DailyTotalModel> {
  @override
  final int typeId = 1;

  @override
  DailyTotalModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DailyTotalModel(
      date: fields[0] as String,
      totalMoney: fields[1] as double,
      totalMinutes: fields[2] as int,
    );
  }

  @override
  void write(BinaryWriter writer, DailyTotalModel obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.date)
      ..writeByte(1)
      ..write(obj.totalMoney)
      ..writeByte(2)
      ..write(obj.totalMinutes);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailyTotalModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
