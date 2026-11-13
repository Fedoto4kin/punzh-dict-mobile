import "package:flutter_test/flutter_test.dart";
import "package:punzh_dict/data/tag_filter_state.dart";

void main() {
  const noun = DictTag(
    id: 33,
    tag: "s",
    name: "substantivum",
    type: 2,
    level: 0,
    sorting: 110,
  );
  const verb = DictTag(
    id: 36,
    tag: "v",
    name: "verbum",
    type: 2,
    level: 0,
    sorting: 120,
  );
  const colloq = DictTag(
    id: 50,
    tag: "разг.",
    name: "разговорное",
    type: 3,
    level: 0,
    sorting: 10,
  );

  test("radio within type and AND across types", () {
    final s = TagFilterState()..setCatalog([noun, verb, colloq]);
    s.toggleTag(noun);
    expect(s.tagIds, [33]);
    s.toggleTag(verb);
    expect(s.tagIds, [36]);
    s.toggleTag(colloq);
    expect(s.tagIds, [36, 50]);
    s.toggleTag(verb);
    expect(s.tagIds, [50]);
    s.togglePhrase();
    expect(s.phrase, isTrue);
    expect(s.activeCount, 2);
    s.clear();
    expect(s.isEmpty, isTrue);
  });

  test("hasFilterChoices needs diversity or phrase", () {
    const one = TagFacets(
      optionsByType: {
        2: [noun],
      },
      enabledTagIds: {33},
      showPhrase: false,
      phraseEnabled: false,
    );
    expect(one.hasFilterChoices, isFalse);

    const two = TagFacets(
      optionsByType: {
        2: [noun, verb],
      },
      enabledTagIds: {33, 36},
      showPhrase: false,
      phraseEnabled: false,
    );
    expect(two.hasFilterChoices, isTrue);

    const phraseOnly = TagFacets(
      optionsByType: {
        2: [verb],
      },
      enabledTagIds: {36},
      showPhrase: true,
      phraseEnabled: true,
    );
    expect(phraseOnly.hasFilterChoices, isTrue);
  });
}
