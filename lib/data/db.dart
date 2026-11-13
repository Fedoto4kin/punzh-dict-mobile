import "dart:io";

import "package:flutter/services.dart";
import "package:path/path.dart" as p;
import "package:path_provider/path_provider.dart";
import "package:sqflite/sqflite.dart";

import "../schema.dart";

const String assetDbPath = "assets/dict.sqlite";
const String runtimeDbName = "dict.sqlite";

Future<String> runtimeDictionaryDbPath() async {
  final dir = await getApplicationDocumentsDirectory();
  return p.join(dir.path, runtimeDbName);
}

/// Ensures the APK seed is copied into documents; returns the runtime path.
Future<String> ensureRuntimeDictionaryDb() async {
  final dbPath = await runtimeDictionaryDbPath();
  final file = File(dbPath);
  if (!await file.exists()) {
    final data = await rootBundle.load(assetDbPath);
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    await file.writeAsBytes(bytes, flush: true);
  }
  return dbPath;
}

/// Opens the on-device dictionary DB, copying the APK seed on first launch.
Future<Database> openDictionaryDb() async {
  final dbPath = await ensureRuntimeDictionaryDb();
  final db = await openDatabase(dbPath, readOnly: true);
  await assertDictionarySchema(db);
  return db;
}

/// Opens an arbitrary sqlite file (tests / tooling).
Future<Database> openDictionaryDbFile(String path) async {
  final db = await openDatabase(path, readOnly: true);
  await assertDictionarySchema(db);
  return db;
}

Future<void> assertDictionarySchema(Database db) async {
  final rows = await db.query(
    "meta",
    columns: ["value"],
    where: "key = ?",
    whereArgs: ["schema_version"],
    limit: 1,
  );
  if (rows.isEmpty) {
    throw StateError("meta.schema_version missing in dictionary DB");
  }
  final version = int.tryParse("${rows.first["value"]}");
  if (version != schemaVersion) {
    throw StateError(
      "Unsupported dictionary schema_version=$version "
      "(app expects $schemaVersion)",
    );
  }
}

Future<String?> dictionaryMetaValue(Database db, String key) async {
  final rows = await db.query(
    "meta",
    columns: ["value"],
    where: "key = ?",
    whereArgs: [key],
    limit: 1,
  );
  if (rows.isEmpty) return null;
  final v = rows.first["value"];
  return v?.toString();
}
