import "package:flutter_test/flutter_test.dart";
import "package:punzh_dict/data/dictionary_repository.dart";
import "package:punzh_dict/schema.dart";

import "support/mini_repo.dart";

void main() {
  setUpMiniSqlite();

  test("mini fixture: letter A and Russian substring", () async {
    final mini = await openMiniRepo();
    final repo = mini.repo;

    final meta = await mini.db.query(
      "meta",
      where: "key = ?",
      whereArgs: ["schema_version"],
    );
    expect(meta.first["value"], "$schemaVersion");

    final letterA = await repo.articlesByLetter("A");
    expect(letterA, isNotEmpty);
    // Enrich is best-effort: fixture may lack tags/translations.
    final enriched = await repo.enrichSummaries(letterA, chunkSize: 1);
    expect(enriched.length, letterA.length);
    for (final item in enriched) {
      expect(item.previewLine, isA<String>());
    }

    final rus = await repo.searchRussian("а");
    expect(rus, isA<List<ArticleSummary>>());

    final first = letterA.first;
    final detail = await repo.articleById(first.id);
    expect(detail, isNotNull);
    expect(detail!.articleHtml, isNotEmpty);
  });
}
