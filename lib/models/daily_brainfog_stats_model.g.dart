// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'daily_brainfog_stats_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DailyBrainfogStatsAdapter extends TypeAdapter<DailyBrainfogStats> {
  @override
  final int typeId = 2;

  @override
  DailyBrainfogStats read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DailyBrainfogStats(
      date: fields[0] as String,
      totalMinutes: fields[1] as int,
      brainfogScore: fields[3] as int,
      trackedPackagesSnapshot: (fields[4] as List).cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, DailyBrainfogStats obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.date)
      ..writeByte(1)
      ..write(obj.totalMinutes)
      ..writeByte(3)
      ..write(obj.brainfogScore)
      ..writeByte(4)
      ..write(obj.trackedPackagesSnapshot);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailyBrainfogStatsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
