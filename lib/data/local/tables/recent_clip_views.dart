import 'package:drift/drift.dart';
import 'clips.dart';

class RecentClipViews extends Table {
  IntColumn get clipId =>
      integer().references(Clips, #id, onDelete: KeyAction.cascade)();

  IntColumn get lastSeq => integer()();

  @override
  Set<Column> get primaryKey => {clipId};
}
