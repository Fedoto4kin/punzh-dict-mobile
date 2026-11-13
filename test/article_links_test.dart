import "dart:convert";

import "package:flutter_test/flutter_test.dart";
import "package:punzh_dict/article_links.dart";

void main() {
  test("foldLemmaKey strips pipes apostrophes sibilants", () {
    expect(foldLemmaKey("abevu||s"), "abevus");
    expect(foldLemmaKey("šeppä"), "seppä");
    expect(foldLemmaKey("mul’l’in"), "mullin");
  });

  test("makeLink wraps see lemmas with article or search href", () {
    final ids = {"ruttoh": 42};
    final html = makeLink("<i>см.</i> ruttoh, foo", ids);
    expect(html, contains('href="punzh://article/42"'));
    expect(html, contains(">ruttoh<"));
    // Comma continues the see-list; unmatched lemma → search URL.
    expect(html, contains('href="punzh://search/foo"'));
  });

  test("makeLink rewraps prelinked second see lemma after comma", () {
    // Seed HTML (breija): first lemma plain, second already a website /search/ a.
    final html = utf8.decode(<int>[
      60, 105, 62, 209, 129, 209, 128, 46, 60, 47, 105, 62, 32, 108, 226, 128,
      153, 101, 105, 107, 97, 116, 97, 44, 32, 60, 97, 32, 104, 114, 101, 102,
      61, 39, 47, 115, 101, 97, 114, 99, 104, 47, 108, 226, 128, 153, 195, 188,
      104, 101, 110, 226, 128, 153, 100, 226, 128, 153, 105, 195, 164, 39, 62,
      108, 226, 128, 153, 195, 188, 104, 101, 110, 226, 128, 153, 100, 226, 128,
      153, 105, 195, 164, 60, 47, 97, 62,
    ]);
    final out = makeLink(html, {"leikata": 4201, "lühendiä": 4781});
    expect(out, contains('href="punzh://article/4201"'));
    expect(out, contains('href="punzh://article/4781"'));
    expect(out.contains("/search/"), isFalse);
  });

  test("makeLink wraps deriv lemmas", () {
    final html = makeLink("<i>freq</i> от abewttua", {"abewttua": 7});
    expect(html, contains('href="punzh://article/7"'));
    expect(html, contains(">abewttua<"));
  });

  test("punzhSearchUrl percent-encodes apostrophes and diacritics", () {
    final lemma = utf8.decode(<int>[
      108, 226, 128, 153, 195, 188, 104, 101, 110, 226, 128, 153, 100, 226, 128,
      153, 105, 195, 164,
    ]);
    final url = punzhSearchUrl(lemma);
    expect(url.startsWith(punzhSearchScheme), isTrue);
    expect(url.contains("’"), isFalse);
    expect(url.contains("ü"), isFalse);
    final parsed = parsePunzhUrl(url);
    expect(parsed, isA<PunzhSearchUrl>());
    expect((parsed as PunzhSearchUrl).query, lemma);
  });

  test("parsePunzhUrl", () {
    expect(parsePunzhUrl("punzh://article/12"), isA<PunzhArticleUrl>());
    expect((parsePunzhUrl("punzh://article/12") as PunzhArticleUrl).articleId, 12);
    expect(parsePunzhUrl("punzh://search/ai%20ga"), isA<PunzhSearchUrl>());
    expect((parsePunzhUrl("punzh://search/ai%20ga") as PunzhSearchUrl).query, "ai ga");
    expect(parsePunzhUrl("https://example.com"), isNull);
  });

  test("parsePunzhUrl accepts raw Unicode website /search/ leftovers", () {
    final lemma = utf8.decode(<int>[
      108, 226, 128, 153, 195, 188, 104, 101, 110, 226, 128, 153, 100, 226, 128,
      153, 105, 195, 164,
    ]);
    final parsed = parsePunzhUrl("/search/$lemma");
    expect(parsed, isA<PunzhSearchUrl>());
    expect((parsed as PunzhSearchUrl).query, lemma);
  });
}
