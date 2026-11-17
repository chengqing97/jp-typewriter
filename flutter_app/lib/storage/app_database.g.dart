// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $JianpuDocumentsTable extends JianpuDocuments
    with TableInfo<$JianpuDocumentsTable, JianpuDocument> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $JianpuDocumentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _contentJsonMeta =
      const VerificationMeta('contentJson');
  @override
  late final GeneratedColumn<String> contentJson = GeneratedColumn<String>(
      'content_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
      'created_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [id, title, contentJson, createdAt, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'documents';
  @override
  VerificationContext validateIntegrity(Insertable<JianpuDocument> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('content_json')) {
      context.handle(
          _contentJsonMeta,
          contentJson.isAcceptableOrUnknown(
              data['content_json']!, _contentJsonMeta));
    } else if (isInserting) {
      context.missing(_contentJsonMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  JianpuDocument map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return JianpuDocument(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      contentJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}content_json'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $JianpuDocumentsTable createAlias(String alias) {
    return $JianpuDocumentsTable(attachedDatabase, alias);
  }
}

class JianpuDocument extends DataClass implements Insertable<JianpuDocument> {
  final String id;
  final String title;
  final String contentJson;
  final int createdAt;
  final int updatedAt;
  const JianpuDocument(
      {required this.id,
      required this.title,
      required this.contentJson,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['content_json'] = Variable<String>(contentJson);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  JianpuDocumentsCompanion toCompanion(bool nullToAbsent) {
    return JianpuDocumentsCompanion(
      id: Value(id),
      title: Value(title),
      contentJson: Value(contentJson),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory JianpuDocument.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return JianpuDocument(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      contentJson: serializer.fromJson<String>(json['contentJson']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'contentJson': serializer.toJson<String>(contentJson),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  JianpuDocument copyWith(
          {String? id,
          String? title,
          String? contentJson,
          int? createdAt,
          int? updatedAt}) =>
      JianpuDocument(
        id: id ?? this.id,
        title: title ?? this.title,
        contentJson: contentJson ?? this.contentJson,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  JianpuDocument copyWithCompanion(JianpuDocumentsCompanion data) {
    return JianpuDocument(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      contentJson:
          data.contentJson.present ? data.contentJson.value : this.contentJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('JianpuDocument(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('contentJson: $contentJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, title, contentJson, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is JianpuDocument &&
          other.id == this.id &&
          other.title == this.title &&
          other.contentJson == this.contentJson &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class JianpuDocumentsCompanion extends UpdateCompanion<JianpuDocument> {
  final Value<String> id;
  final Value<String> title;
  final Value<String> contentJson;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const JianpuDocumentsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.contentJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  JianpuDocumentsCompanion.insert({
    required String id,
    required String title,
    required String contentJson,
    required int createdAt,
    required int updatedAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        title = Value(title),
        contentJson = Value(contentJson),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt);
  static Insertable<JianpuDocument> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? contentJson,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (contentJson != null) 'content_json': contentJson,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  JianpuDocumentsCompanion copyWith(
      {Value<String>? id,
      Value<String>? title,
      Value<String>? contentJson,
      Value<int>? createdAt,
      Value<int>? updatedAt,
      Value<int>? rowid}) {
    return JianpuDocumentsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      contentJson: contentJson ?? this.contentJson,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (contentJson.present) {
      map['content_json'] = Variable<String>(contentJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('JianpuDocumentsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('contentJson: $contentJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $JianpuDocumentsTable jianpuDocuments =
      $JianpuDocumentsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [jianpuDocuments];
}

typedef $$JianpuDocumentsTableCreateCompanionBuilder = JianpuDocumentsCompanion
    Function({
  required String id,
  required String title,
  required String contentJson,
  required int createdAt,
  required int updatedAt,
  Value<int> rowid,
});
typedef $$JianpuDocumentsTableUpdateCompanionBuilder = JianpuDocumentsCompanion
    Function({
  Value<String> id,
  Value<String> title,
  Value<String> contentJson,
  Value<int> createdAt,
  Value<int> updatedAt,
  Value<int> rowid,
});

class $$JianpuDocumentsTableFilterComposer
    extends Composer<_$AppDatabase, $JianpuDocumentsTable> {
  $$JianpuDocumentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get contentJson => $composableBuilder(
      column: $table.contentJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$JianpuDocumentsTableOrderingComposer
    extends Composer<_$AppDatabase, $JianpuDocumentsTable> {
  $$JianpuDocumentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get contentJson => $composableBuilder(
      column: $table.contentJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$JianpuDocumentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $JianpuDocumentsTable> {
  $$JianpuDocumentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get contentJson => $composableBuilder(
      column: $table.contentJson, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$JianpuDocumentsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $JianpuDocumentsTable,
    JianpuDocument,
    $$JianpuDocumentsTableFilterComposer,
    $$JianpuDocumentsTableOrderingComposer,
    $$JianpuDocumentsTableAnnotationComposer,
    $$JianpuDocumentsTableCreateCompanionBuilder,
    $$JianpuDocumentsTableUpdateCompanionBuilder,
    (
      JianpuDocument,
      BaseReferences<_$AppDatabase, $JianpuDocumentsTable, JianpuDocument>
    ),
    JianpuDocument,
    PrefetchHooks Function()> {
  $$JianpuDocumentsTableTableManager(
      _$AppDatabase db, $JianpuDocumentsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$JianpuDocumentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$JianpuDocumentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$JianpuDocumentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String> contentJson = const Value.absent(),
            Value<int> createdAt = const Value.absent(),
            Value<int> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              JianpuDocumentsCompanion(
            id: id,
            title: title,
            contentJson: contentJson,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String title,
            required String contentJson,
            required int createdAt,
            required int updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              JianpuDocumentsCompanion.insert(
            id: id,
            title: title,
            contentJson: contentJson,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$JianpuDocumentsTable, JianpuDocument>(table),
                    BaseReferences<_$AppDatabase, $JianpuDocumentsTable,
                        JianpuDocument>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$JianpuDocumentsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $JianpuDocumentsTable,
    JianpuDocument,
    $$JianpuDocumentsTableFilterComposer,
    $$JianpuDocumentsTableOrderingComposer,
    $$JianpuDocumentsTableAnnotationComposer,
    $$JianpuDocumentsTableCreateCompanionBuilder,
    $$JianpuDocumentsTableUpdateCompanionBuilder,
    (
      JianpuDocument,
      BaseReferences<_$AppDatabase, $JianpuDocumentsTable, JianpuDocument>
    ),
    JianpuDocument,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$JianpuDocumentsTableTableManager get jianpuDocuments =>
      $$JianpuDocumentsTableTableManager(_db, _db.jianpuDocuments);
}
