
import "dart:io";

import "package:flutter_test/flutter_test.dart";
import "package:punzh_dict/data/db.dart";
import "package:punzh_dict/data/dictionary_repository.dart";
import "package:sqflite_common_ffi/sqflite_ffi.dart";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test("exact miss yields nearby suggestion", () async {
    final mini = File("test/fixtures/mini.sqlite").absolute;
    final db = await openDictionaryDbFile(mini.path);
    addTearDown(db.close);
    final repo = DictionaryRepository(db);

    expect(await repo.searchKarelian("bojla"), isEmpty);
    final sugg = await repo.searchKarelianSuggestions("bojla");
    expect(sugg, contains("boila"));
  });

  test("exact hit finds article", () async {
    final mini = File("test/fixtures/mini.sqlite").absolute;
    final db = await openDictionaryDbFile(mini.path);
    addTearDown(db.close);
    final repo = DictionaryRepository(db);
    final hits = await repo.searchKarelian("boila");
    expect(hits.map((a) => a.word), ["boila"]);
  });
}
