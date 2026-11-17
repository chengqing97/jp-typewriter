import 'package:drift/drift.dart';

import '../models/jianpu_document.dart' hide JianpuDocument;
import 'app_database.dart';
import 'local_jianpu_document.dart';

class JianpuDocumentRepository {
  JianpuDocumentRepository({AppDatabase? database})
      : _database = database ?? AppDatabase();

  final AppDatabase _database;

  Future<List<LocalJianpuDocument>> listDocuments() async {
    final rows = await (_database.select(_database.jianpuDocuments)
          ..orderBy([
            (table) => OrderingTerm.desc(table.updatedAt),
          ]))
        .get();
    return rows.map(_toLocalDocument).toList();
  }

  /// Emits an updated list whenever any document is inserted, edited,
  /// renamed, or deleted.
  Stream<List<LocalJianpuDocument>> watchDocuments() {
    return (_database.select(_database.jianpuDocuments)
          ..orderBy([
            (table) => OrderingTerm.desc(table.updatedAt),
          ]))
        .watch()
        .map((rows) => rows.map(_toLocalDocument).toList());
  }

  Future<LocalJianpuDocument?> getDocument(String id) async {
    final row = await (_database.select(_database.jianpuDocuments)
          ..where((table) => table.id.equals(id))
          ..limit(1))
        .getSingleOrNull();
    return row == null ? null : _toLocalDocument(row);
  }

  Future<LocalJianpuDocument> createDocument({
    required String title,
    required List<JianpuRun> runs,
  }) async {
    final now = DateTime.now();
    final document = LocalJianpuDocument(
      id: now.microsecondsSinceEpoch.toString(),
      title: _normalizedTitle(title),
      runs: List<JianpuRun>.of(runs),
      createdAt: now,
      updatedAt: now,
    );
    await _database.into(_database.jianpuDocuments).insert(
          JianpuDocumentsCompanion.insert(
            id: document.id,
            title: document.title,
            contentJson: document.encodeContent(),
            createdAt: now.millisecondsSinceEpoch,
            updatedAt: now.millisecondsSinceEpoch,
          ),
        );
    return document;
  }

  Future<void> saveDocument({
    required String id,
    required String title,
    required List<JianpuRun> runs,
  }) async {
    final now = DateTime.now();
    await (_database.update(_database.jianpuDocuments)
          ..where((table) => table.id.equals(id)))
        .write(
      JianpuDocumentsCompanion(
        title: Value(_normalizedTitle(title)),
        contentJson: Value(
          LocalJianpuDocument(
            id: id,
            title: _normalizedTitle(title),
            runs: runs,
            createdAt: now,
            updatedAt: now,
          ).encodeContent(),
        ),
        updatedAt: Value(now.millisecondsSinceEpoch),
      ),
    );
  }

  Future<void> renameDocument(String id, String title) async {
    await (_database.update(_database.jianpuDocuments)
          ..where((table) => table.id.equals(id)))
        .write(
      JianpuDocumentsCompanion(
        title: Value(_normalizedTitle(title)),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  Future<void> deleteDocument(String id) async {
    await (_database.delete(_database.jianpuDocuments)
          ..where((table) => table.id.equals(id)))
        .go();
  }

  Future<void> close() => _database.close();

  LocalJianpuDocument _toLocalDocument(JianpuDocument row) {
    return LocalJianpuDocument.fromRow({
      'id': row.id,
      'title': row.title,
      'content_json': row.contentJson,
      'created_at': row.createdAt,
      'updated_at': row.updatedAt,
    });
  }

  String _normalizedTitle(String title) =>
      title.trim().isEmpty ? 'Untitled Jianpu' : title.trim();
}
