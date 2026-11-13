import "package:flutter_test/flutter_test.dart";
import "package:punzh_dict/orthography.dart";

void main() {
  group("normalization (Django orphography.py)", () {
    test("compound and w/ü rules", () {
      expect(normalization("müöd’ä|tuwl’i"), "myödätuuli");
      expect(normalization("olgu|piä|luw"), "olgupiäluu");
      expect(normalization("l’ewhend’el’iečie"), "leyhendeliečie");
    });

    test("comma variants and tilde appendix", () {
      expect(
        normalization("ühekšän|toista, üheks’än|tois’t’a"),
        "yhekšäntoista, yheksäntois’t’a",
      );
      expect(
        normalization("vuat||e, ~ehut, vi̮ate"),
        "vuate, vuatehut, vi̮ate",
      );
      expect(normalization("tuwl’||i, ~ut"), "tuuli, tuul’ut");
    });

    test("simple heads", () {
      expect(normalization("ewle"), "eyle");
      expect(normalization("hüviin"), "hyviin");
      expect(normalization("dar||a II"), "dara II");
      expect(normalization("d’eng||a, ~an’e"), "denga, dengane");
    });
  });

  group("displayHeadword (wordCard.html)", () {
    test("uses word_normalized when set, else normalization(word)", () {
      expect(displayHeadword("ewle", "eule"), "eule");
      expect(displayHeadword("ewle", null), "eyle");
      expect(displayHeadword("ewle", "  "), "eyle");
      expect(displayHeadword("müöd’ä|tuwl’i", null), "myödätuuli");
    });
  });
}
