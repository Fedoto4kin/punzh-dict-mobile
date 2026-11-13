import "package:flutter_test/flutter_test.dart";
import "package:punzh_dict/search_direction.dart";

void main() {
  test("Cyrillic anywhere → russian, else karelian", () {
    expect(detectDirection("время"), SearchDirection.russian);
    expect(detectDirection("aiga"), SearchDirection.karelian);
    expect(detectDirection("hyvä"), SearchDirection.karelian);
    expect(detectDirection("aiga время"), SearchDirection.russian);
    expect(detectDirection(""), SearchDirection.karelian);
  });
}
