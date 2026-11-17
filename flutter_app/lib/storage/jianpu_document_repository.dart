import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/jianpu_document.dart';
import 'local_jianpu_document.dart';

class JianpuDocumentRepository {
  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    final path = p.join(await getDatabasesPath(), 'jianpu_documents.db');
    _database = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE documents (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            content_json TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
        await db.execute(
          'CREATE INDEX documents_updated_at ON documents(updated_at DESC)',
        );
      },
    );
    return _database!;
  }

  Future<List<LocalJianpuDocument>> listDocuments() async {
    final db = await database;
    final rows = await db.query('documents', orderBy: 'updated_at DESC');
    return rows.map(LocalJianpuDocument.fromRow).toList();
  }

  Future<LocalJianpuDocument?> getDocument(String id) async {
    final db = await database;
    final rows = await db.query(
      'documents',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : LocalJianpuDocument.fromRow(rows.first);
  }

  Future<LocalJianpuDocument> createDocument({
    required String title,
    required List<JianpuRun> runs,
  }) async {
    final now = DateTime.now();
    final document = LocalJianpuDocument(
      id: now.microsecondsSinceEpoch.toString(),
      title: title.trim().isEmpty ? 'Untitled Jianpu' : title.trim(),
      runs: List<JianpuRun>.of(runs),
      createdAt: now,
      updatedAt: now,
    );
    await (await database).insert('documents', {
      'id': document.id,
      'title': document.title,
      'content_json': document.encodeContent(),
      'created_at': now.millisecondsSinceEpoch,
      'updated_at': now.millisecondsSinceEpoch,
    });
    return document;
  }

  Future<void> saveDocument({
    required String id,
    required String title,
    required List<JianpuRun> runs,
  }) async {
    final db = await database;
    await db.update(
      'documents',
      {
        'title': title.trim().isEmpty ? 'Untitled Jianpu' : title.trim(),
        'content_json': LocalJianpuDocument(
          id: id,
          title: title,
          runs: runs,
          createdAt: DateTime.fromMillisecondsSinceEpoch(0),
          updatedAt: DateTime.now(),
        ).encodeContent(),
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> renameDocument(String id, String title) async {
    await (await database).update(
      'documents',
      {
        'title': title.trim().isEmpty ? 'Untitled Jianpu' : title.trim(),
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteDocument(String id) async {
    await (await database).delete(
      'documents',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
