import 'package:drift/drift.dart';
import 'clips.dart';
import 'tags.dart';

class ClipTags extends Table {
  IntColumn get clipId =>
      integer().references(Clips, #id, onDelete: KeyAction.cascade)();
  IntColumn get tagId =>
      integer().references(Tags, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column> get primaryKey => {clipId, tagId};
}
