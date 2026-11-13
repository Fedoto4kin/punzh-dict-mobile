import "dart:io";

import "package:flutter/foundation.dart";
import "package:sqflite/sqflite.dart";

import "db.dart";
import "dictionary_repository.dart";

/// Owns the open dictionary [Database] and recreates [repository] after replace.
class DictionarySession extends ChangeNotifier {
  DictionarySession._(this._db) : repository = DictionaryRepository(_db);

  Database _db;
  DictionaryRepository repository;

  static Future<DictionarySession> open() async {
    final db = await openDictionaryDb();
    return DictionarySession._(db);
  }

  Future<String?> metaValue(String key) => dictionaryMetaValue(_db, key);

  Future<LocalDictionaryMeta> localMeta() async {
    return LocalDictionaryMeta(
      schemaVersion: await metaValue("schema_version"),
      dataVersion: await metaValue("data_version"),
      builtAt: await metaValue("built_at"),
      minApp: await metaValue("min_app"),
    );
  }

  /// Atomically replace runtime sqlite with a verified download; reopen DB.
  /// On failure restores the previous file when a backup was made.
  Future<void> replaceWithFile(File verifiedSqlite) async {
    final path = await runtimeDictionaryDbPath();
    final dest = File(path);
    final backup = File("$path.bak");
    final staging = File("$path.new");

    if (await staging.exists()) {
      await staging.delete();
    }
    await verifiedSqlite.copy(staging.path);

    await _db.close();

    if (await backup.exists()) {
      await backup.delete();
    }
    if (await dest.exists()) {
      await dest.rename(backup.path);
    }
    await staging.rename(path);

    try {
      final opened = await openDatabase(path, readOnly: true);
      await assertDictionarySchema(opened);
      _db = opened;
      repository = DictionaryRepository(_db);
      if (await backup.exists()) {
        await backup.delete();
      }
      notifyListeners();
    } catch (e) {
      try {
        await _db.close();
      } catch (_) {}
      if (await File(path).exists()) {
        await File(path).delete();
      }
      if (await backup.exists()) {
        await backup.rename(path);
      }
      _db = await openDatabase(path, readOnly: true);
      repository = DictionaryRepository(_db);
      notifyListeners();
      rethrow;
    }
  }

  @override
  void dispose() {
    _db.close();
    super.dispose();
  }
}

class LocalDictionaryMeta {
  const LocalDictionaryMeta({
    this.schemaVersion,
    this.dataVersion,
    this.builtAt,
    this.minApp,
  });

  final String? schemaVersion;
  final String? dataVersion;
  final String? builtAt;
  final String? minApp;
}
