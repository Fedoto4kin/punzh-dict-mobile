import "package:flutter_test/flutter_test.dart";
import "package:punzh_dict/ngram.dart";

void main() {
  test("createNgram mirrors Django create_ngram", () {
    expect(createNgram("aiga", 3), "aig");
    expect(createNgram("mul’l’in", 3), "mul");
    expect(createNgram("tuwl’i", 3).length, lessThanOrEqualTo(3));
    expect(createNgram("tuwl’i", 3), isNotEmpty);
  });

  test("maxLetterPagesForRailHeight fits slots into height", () {
    expect(maxLetterPagesForRailHeight(0), 12);
    // ~700px list → about 24 slots at 28px; capped by absoluteMax default 28.
    final n = maxLetterPagesForRailHeight(700);
    expect(n, greaterThanOrEqualTo(21));
    expect(n, lessThanOrEqualTo(28));
    expect(maxLetterPagesForRailHeight(100), greaterThanOrEqualTo(2));
    expect(
      maxLetterPagesForRailHeight(700, absoluteMax: 21),
      lessThanOrEqualTo(21),
    );
  });

  test("buildLetterPages keeps small letters as one page", () {
    final words = [for (var i = 0; i < 40; i++) "yö$i"];
    final pages = buildLetterPages(words, minPageSize: 50);
    expect(pages, hasLength(1));
    expect(pages.first.start, 0);
    expect(pages.first.end, 40);
  });

  test("buildLetterPages splits N-scale list into about 12 pages", () {
    final words = [
      for (var i = 0; i < 573; i++) "n${i.toString().padLeft(4, '0')}",
    ];
    final pages = buildLetterPages(
      words,
      targetPages: 12,
      minPageSize: 50,
    );
    expect(pages.length, inInclusiveRange(10, 13));
    expect(pages.first.start, 0);
    expect(pages.last.end, 573);
    for (var i = 1; i < pages.length; i++) {
      expect(pages[i].start, pages[i - 1].end);
    }
    final covered = pages.fold<int>(0, (s, p) => s + p.length);
    expect(covered, 573);
    expect(pages.every((p) => p.length >= 50 || p == pages.last), isTrue);
  });

  test("buildLetterPages caps K-scale list near 12 pages", () {
    final words = [
      for (var i = 0; i < 2859; i++) "k${i.toString().padLeft(4, '0')}",
    ];
    final pages = buildLetterPages(
      words,
      targetPages: 12,
      minPageSize: 50,
    );
    expect(pages.length, inInclusiveRange(11, 13));
    expect(pages.last.end, 2859);
    // ~2859/12 ≈ 239 rows per page — fits full enrich.
    expect(pages.first.length, greaterThanOrEqualTo(200));
    expect(pages.first.length, lessThanOrEqualTo(250));
  });

  test("buildLetterPages last label is final headword n-gram", () {
    final words = [
      for (var i = 0; i < 200; i++) "kaa${i.toString().padLeft(3, '0')}",
    ];
    words[0] = "akka";
    words[199] = "züütti";
    final pages = buildLetterPages(
      words,
      targetPages: 4,
      minPageSize: 50,
    );
    expect(pages.length, greaterThanOrEqualTo(2));
    expect(pages.last.label, createNgram("züütti", 3));
    expect(pages.first.label, isNot(pages.last.label));
  });

  test("buildLetterPages uniquifies non-neighbour n-gram clashes", () {
    // Mimic T: ter’vewt… vs later t’erä… → same 3-gram after apostrophe strip.
    final words = [
      for (var i = 0; i < 200; i++) "taa${i.toString().padLeft(3, '0')}",
    ];
    words[0] = "tabakka";
    words[50] = "ter’vewt’tiä";
    words[100] = "toko";
    words[150] = "t’eräwdüö";
    words[199] = "työ";
    final pages = buildLetterPages(
      words,
      targetPages: 4,
      minPageSize: 50,
    );
    final labels = [for (final p in pages) p.label];
    expect(labels.toSet().length, labels.length);
    expect(labels.where((l) => l == "ter").length, lessThan(2));
  });

  test("buildLetterPages disambiguates colliding prefixes", () {
    final words = [
      for (var i = 0; i < 200; i++) "kaa${i.toString().padLeft(3, '0')}",
    ];
    // Page starts land on colliding 3-grams; lengthen labels.
    words[0] = "akka";
    words[50] = "akku";
    words[100] = "akky";
    final pages = buildLetterPages(
      words,
      targetPages: 4,
      minPageSize: 50,
    );
    expect(pages.length, greaterThanOrEqualTo(3));
    final labels = [for (final p in pages) p.label];
    expect(labels.toSet().length, labels.length);
  });

  test("anchorsForPages uses page ordinal as index", () {
    final pages = buildLetterPages(
      [for (var i = 0; i < 120; i++) "m$i"],
      targetPages: 12,
      minPageSize: 50,
    );
    final anchors = anchorsForPages(pages);
    expect(anchors.length, pages.length);
    expect(anchors.first.index, 0);
    expect(anchors.last.index, pages.length - 1);
  });

  test("buildNgramAnchors spaces landmarks and disambiguates", () {
    final words = [
      for (var i = 0; i < 100; i++) "kaa${i.toString().padLeft(3, '0')}",
    ];
    words[0] = "akka";
    words[8] = "muše";
    final anchors = buildNgramAnchors(words, targetCount: 12);
    expect(anchors.length, greaterThan(10));
    expect(anchors.first.index, 0);
    expect(anchors.last.index, 99);
  });

  test("activeAnchorForListIndex picks last landmark at or before index", () {
    const anchors = [
      NgramAnchor(index: 0, label: "a"),
      NgramAnchor(index: 10, label: "b"),
      NgramAnchor(index: 20, label: "c"),
    ];
    expect(activeAnchorForListIndex(anchors, 0), 0);
    expect(activeAnchorForListIndex(anchors, 9), 0);
    expect(activeAnchorForListIndex(anchors, 10), 1);
    expect(activeAnchorForListIndex(anchors, 25), 2);
  });
}
