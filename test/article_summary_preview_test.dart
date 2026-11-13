import "package:flutter_test/flutter_test.dart";
import "package:punzh_dict/data/dictionary_repository.dart";

void main() {
  test("previewLine joins POS and glosses with limits", () {
    expect(const ArticleSummary(id: 1, word: "a").previewLine, "");
    expect(
      const ArticleSummary(id: 1, word: "a", posTags: ["сущ."]).previewLine,
      "сущ.",
    );
    expect(
      const ArticleSummary(
        id: 1,
        word: "a",
        translations: ["кошка", "кот"],
      ).previewLine,
      "кошка, кот",
    );
    expect(
      const ArticleSummary(
        id: 1,
        word: "a",
        posTags: ["сущ.", "собир.", "лишнее"],
        translations: ["кошка", "котик", "мур", "ещё"],
      ).previewLine,
      "сущ., собир. · кошка, котик, мур…",
    );
  });

  test("previewLine uses см./от when no own translations", () {
    expect(
      const ArticleSummary(
        id: 1,
        word: "abevus",
        seeTargets: ["abevuo"],
        inheritedTranslations: ["открывать"],
      ).previewLine,
      "см. abevuo · открывать",
    );
    expect(
      const ArticleSummary(
        id: 1,
        word: "x",
        posTags: ["гл."],
        derivTargets: ["juottua"],
      ).previewLine,
      "гл. · от juottua",
    );
  });
}
