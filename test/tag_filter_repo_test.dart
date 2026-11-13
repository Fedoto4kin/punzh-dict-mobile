import "package:flutter_test/flutter_test.dart";

import "support/mini_repo.dart";

void main() {
  setUpMiniSqlite();

  test("listFilterTags and letter/search AND filters", () async {
    final repo = (await openMiniRepo()).repo;

    final tags = await repo.listFilterTags();
    expect(tags.map((t) => t.id), containsAll([33, 36, 50]));
    expect(tags.any((t) => t.type == 5), isFalse);
    expect(tags.where((t) => t.type == 2).every((t) => t.level == 0), isTrue);

    final nounsA = await repo.articlesByLetter("A", tagIds: [33]);
    expect(nounsA.map((a) => a.word), ["aiga"]);

    final verbsB = await repo.articlesByLetter("B", tagIds: [36]);
    expect(verbsB.map((a) => a.word), ["boila"]);

    final none = await repo.articlesByLetter("A", tagIds: [36]);
    expect(none, isEmpty);

    final phraseB = await repo.articlesByLetter("B", phrase: true);
    expect(phraseB.map((a) => a.word), ["boila"]);

    final krl = await repo.searchKarelian("boi?", tagIds: [36]);
    expect(krl.map((a) => a.word), ["boila"]);

    final krlPhrase = await repo.searchKarelian("boi?", phrase: true);
    expect(krlPhrase.map((a) => a.word), ["boila"]);

    final krlNounMiss = await repo.searchKarelian("boi?", tagIds: [33]);
    expect(krlNounMiss, isEmpty);
  });

  test("facets from article ids show tags present in hits", () async {
    final repo = (await openMiniRepo()).repo;

    final aiga = await repo.tagFacetsForArticleIds([1]);
    expect(aiga.optionsForType(2).map((t) => t.id), [33]);
    expect(aiga.optionsForType(2).map((t) => t.id), isNot(contains(36)));
    expect(aiga.hasFilterChoices, isFalse);

    final both = await repo.tagFacetsForArticleIds([1, 2]);
    expect(both.optionsForType(2).map((t) => t.id).toSet(), {33, 36});
    expect(both.showPhrase, isTrue);
    expect(both.hasFilterChoices, isTrue);

    final boila = await repo.tagFacetsForArticleIds([2]);
    // All hits share one grammar mark; phrase not offered (no contrast).
    expect(boila.hasFilterChoices, isFalse);
    expect(boila.showPhrase, isFalse);

    final selected = await repo.tagFacetsForArticleIds(
      [1],
      selectedTagIds: [33],
    );
    expect(selected.optionsForType(2).map((t) => t.id), [33]);

    final empty = await repo.tagFacetsForArticleIds(const []);
    expect(empty.isEmpty, isTrue);
  });

  test("impossible combinations are disabled", () async {
    final repo = (await openMiniRepo()).repo;

    // Article 1 = noun; article 2 = verb + phrase. Cross-type: select phrase,
    // then only verb (article 2) stays for grammar.
    final facets = await repo.tagFacetsForArticleIds(
      [1, 2],
      selectedTagIds: const [],
      phrase: true,
    );
    expect(facets.isTagEnabled(36), isTrue); // verb on phrased article
    expect(facets.isTagEnabled(33), isFalse); // noun article has no phrase
    expect(facets.optionsForType(2).map((t) => t.id).toSet(), {33, 36});
  });
}
