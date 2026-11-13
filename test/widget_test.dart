import "package:flutter_test/flutter_test.dart";
import "package:punzh_dict/schema.dart";

void main() {
  test("schema version and KRL alphabet are non-empty", () {
    expect(schemaVersion, 2);
    expect(krlAbc, contains("A"));
    expect(krlAbc, contains("Ö"));
  });
}
