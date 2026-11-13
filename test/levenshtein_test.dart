import "package:flutter_test/flutter_test.dart";
import "package:punzh_dict/levenshtein.dart";
import "package:punzh_dict/krl_query.dart";

void main() {
  test("levenshtein basic distances", () {
    expect(levenshtein("", ""), 0);
    expect(levenshtein("a", ""), 1);
    expect(levenshtein("kitten", "sitting"), 3);
    expect(levenshtein("boila", "bojla"), 1);
    expect(levenshtein("boila", "boila"), 0);
  });

  test("prepareKrlFuzzyQuery strips wildcards and folds", () {
    expect(prepareKrlFuzzyQuery("Boi?"), "boi");
    expect(prepareKrlFuzzyQuery("hüč."), "hyc");
  });
}
