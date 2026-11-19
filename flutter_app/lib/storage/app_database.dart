import 'package:drift/drift.dart';

import 'database_connection.dart';

part 'app_database.g.dart';

/// Drift schema mapped onto the existing sqflite table so existing documents
/// remain in the same database file during the storage-layer migration.
class JianpuDocuments extends Table {
  @override
  String get tableName => 'documents';

  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get contentJson => text().named('content_json')();
  IntColumn get createdAt => integer().named('created_at')();
  IntColumn get updatedAt => integer().named('updated_at')();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [JianpuDocuments])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await customStatement(
            'CREATE INDEX documents_updated_at ON documents(updated_at DESC)',
          );
        },
        onUpgrade: (m, from, to) async {
          // Future schema changes should be added here. Version 1 deliberately
          // matches the existing sqflite database schema.
        },
      );
}
