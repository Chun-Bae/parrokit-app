import 'package:drift/drift.dart';
import 'clips.dart';

class Segments extends Table {
  IntColumn get id => integer().autoIncrement()(); // segment_id
  IntColumn get clipId => integer().references(Clips, #id)();
  IntColumn get startMs => integer()();
  IntColumn get endMs => integer()();
  TextColumn get original => text()(); // 일본어 원문
  TextColumn get pron => text()(); // 발음(로마자/가타카나 등)
  TextColumn get trans => text()(); // 해석(한국어 등)
}
