import "package:flutter_test/flutter_test.dart";

import "support/mini_repo.dart";

void main() {
  setUpMiniSqlite();

  test("exact miss yields nearby suggestion", () async {
    final repo = (await openMiniRepo()).repo;

    expect(await repo.searchKarelian("bojla"), isEmpty);
    final sugg = await repo.searchKarelianSuggestions("bojla");
    expect(sugg, contains("boila"));
  });

  test("exact hit finds article", () async {
    final repo = (await openMiniRepo()).repo;
    final hits = await repo.searchKarelian("boila");
    expect(hits.map((a) => a.word), ["boila"]);
  });
}
