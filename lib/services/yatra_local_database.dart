import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

enum LocalCatalogKind {
  place('place'),
  package('package'),
  route('route');

  const LocalCatalogKind(this.storageName);

  final String storageName;
}

class LocalCatalogRecord {
  final LocalCatalogKind kind;
  final String id;
  final Map<String, dynamic> payload;
  final bool active;

  const LocalCatalogRecord({
    required this.kind,
    required this.id,
    required this.payload,
    required this.active,
  });
}

/// Durable SQLite storage for Yatra's offline catalog.
///
/// Firestore synchronization is deliberately kept outside this class.
/// This layer only owns local persistence.
class YatraLocalDatabase {
  YatraLocalDatabase({DatabaseFactory? factory, String? databasePath})
    : this._(factory ?? databaseFactory, databasePath);

  YatraLocalDatabase._(this._factory, this._databasePath);

  static const int schemaVersion = 1;
  static const String databaseFileName = 'yatra_offline.db';

  static const String _catalogTable = 'catalog_records';
  static const String _metadataTable = 'sync_metadata';

  final DatabaseFactory _factory;
  final String? _databasePath;

  Database? _database;

  Future<Database> get database async {
    final existing = _database;

    if (existing != null) {
      return existing;
    }

    final opened = await _open();
    _database = opened;

    return opened;
  }

  Future<Database> _open() async {
    final databasePath =
        _databasePath ?? p.join(await getDatabasesPath(), databaseFileName);

    return _factory.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onCreate: _createSchema,
      ),
    );
  }

  Future<void> _createSchema(Database database, int version) async {
    await database.execute('''
      CREATE TABLE $_catalogTable (
        kind TEXT NOT NULL,
        id TEXT NOT NULL,
        payload TEXT NOT NULL,
        active INTEGER NOT NULL DEFAULT 1,
        PRIMARY KEY (kind, id)
      )
    ''');

    await database.execute('''
      CREATE INDEX idx_catalog_kind_active
      ON $_catalogTable(kind, active)
    ''');

    await database.execute('''
      CREATE TABLE $_metadataTable (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  Future<void> replaceCatalog(
    LocalCatalogKind kind,
    Iterable<LocalCatalogRecord> records,
  ) async {
    final db = await database;

    await db.transaction((transaction) async {
      await _replaceCatalogInTransaction(transaction, kind, records);
    });
  }

  Future<void> replaceSnapshot(
    Map<LocalCatalogKind, Iterable<LocalCatalogRecord>> catalogs,
  ) async {
    final db = await database;

    await db.transaction((transaction) async {
      for (final entry in catalogs.entries) {
        await _replaceCatalogInTransaction(transaction, entry.key, entry.value);
      }
    });
  }

  Future<void> _replaceCatalogInTransaction(
    Transaction transaction,
    LocalCatalogKind kind,
    Iterable<LocalCatalogRecord> records,
  ) async {
    final validatedRecords = <LocalCatalogRecord>[];

    for (final record in records) {
      if (record.kind != kind) {
        throw ArgumentError(
          'Catalog record ${record.id} belongs to '
          '${record.kind.storageName}, not ${kind.storageName}.',
        );
      }

      if (record.id.trim().isEmpty) {
        throw ArgumentError('Offline catalog records require a non-empty id.');
      }

      validatedRecords.add(record);
    }

    await transaction.delete(
      _catalogTable,
      where: 'kind = ?',
      whereArgs: <Object?>[kind.storageName],
    );

    final batch = transaction.batch();

    for (final record in validatedRecords) {
      batch.insert(_catalogTable, <String, Object?>{
        'kind': kind.storageName,
        'id': record.id.trim(),
        'payload': jsonEncode(record.payload),
        'active': record.active ? 1 : 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    await batch.commit(noResult: true);
  }

  Future<List<LocalCatalogRecord>> readCatalog(
    LocalCatalogKind kind, {
    bool includeInactive = false,
  }) async {
    final db = await database;

    final rows = await db.query(
      _catalogTable,
      where: includeInactive ? 'kind = ?' : 'kind = ? AND active = 1',
      whereArgs: <Object?>[kind.storageName],
      orderBy: 'id COLLATE NOCASE ASC',
    );

    final result = <LocalCatalogRecord>[];

    for (final row in rows) {
      final id = row['id'];
      final encodedPayload = row['payload'];

      if (id is! String || encodedPayload is! String) {
        continue;
      }

      try {
        final decoded = jsonDecode(encodedPayload);

        if (decoded is! Map) {
          continue;
        }

        result.add(
          LocalCatalogRecord(
            kind: kind,
            id: id,
            payload: Map<String, dynamic>.from(decoded),
            active: row['active'] == 1,
          ),
        );
      } on FormatException {
        continue;
      }
    }

    return List<LocalCatalogRecord>.unmodifiable(result);
  }

  Future<void> writeMetadata(String key, String value) async {
    final normalizedKey = key.trim();

    if (normalizedKey.isEmpty) {
      throw ArgumentError('Metadata key cannot be empty.');
    }

    final db = await database;

    await db.insert(_metadataTable, <String, Object?>{
      'key': normalizedKey,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String?> readMetadata(String key) async {
    final normalizedKey = key.trim();

    if (normalizedKey.isEmpty) {
      return null;
    }

    final db = await database;

    final rows = await db.query(
      _metadataTable,
      columns: const <String>['value'],
      where: 'key = ?',
      whereArgs: <Object?>[normalizedKey],
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    final value = rows.first['value'];

    return value is String ? value : null;
  }

  Future<void> close() async {
    final currentDatabase = _database;

    if (currentDatabase == null) {
      return;
    }

    await currentDatabase.close();
    _database = null;
  }
}
