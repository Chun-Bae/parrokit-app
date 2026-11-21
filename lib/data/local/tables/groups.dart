import 'package:drift/drift.dart';

class Groups extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get storageMode => text().withDefault(const Constant('local'))();
  TextColumn get remoteId => text().nullable()();
}
