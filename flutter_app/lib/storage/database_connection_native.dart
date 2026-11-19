import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' show getDatabasesPath;

/// Keep the same database location used by the previous sqflite repository,
/// preserving existing iOS and Android documents.
LazyDatabase openConnection() {
  return LazyDatabase(() async {
    final databasePath = p.join(
      await getDatabasesPath(),
      'jianpu_documents.db',
    );
    return NativeDatabase(File(databasePath));
  });
}
