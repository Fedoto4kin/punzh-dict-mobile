import "dart:io";

import "package:flutter_test/flutter_test.dart";
import "package:punzh_dict/data/db.dart";
import "package:punzh_dict/data/dictionary_repository.dart";
import "package:sqflite_common_ffi/sqflite_ffi.dart";

typedef MiniFixture = ({Database db, DictionaryRepository repo});

/// Shared ffi + binding setup for tests that open `test/fixtures/mini.sqlite`.
void setUpMiniSqlite() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
}

/// Open the mini fixture; registers [Database.close] via [addTearDown].
Future<MiniFixture> openMiniRepo() async {
  final mini = File("test/fixtures/mini.sqlite").absolute;
  expect(mini.existsSync(), isTrue, reason: mini.path);
  final db = await openDictionaryDbFile(mini.path);
  addTearDown(db.close);
  return (db: db, repo: DictionaryRepository(db));
}
