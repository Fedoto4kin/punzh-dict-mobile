import "package:flutter_test/flutter_test.dart";
import "package:punzh_dict/data/app_version.dart";

void main() {
  test("compareVersionStrings numeric dotted", () {
    expect(compareVersionStrings("0.1.0", "0.1.0"), 0);
    expect(compareVersionStrings("0.1.0", "0.2.0"), lessThan(0));
    expect(compareVersionStrings("0.2.0", "0.1.9"), greaterThan(0));
    expect(compareVersionStrings("1.0", "1.0.0"), 0);
    expect(compareVersionStrings("0.1.0+5", "0.1.0"), 0);
  });

  test("isAppVersionBelowMin", () {
    expect(isAppVersionBelowMin("0.1.0", "0.2.0"), isTrue);
    expect(isAppVersionBelowMin("0.2.0", "0.2.0"), isFalse);
    expect(isAppVersionBelowMin("0.2.1", "0.2.0"), isFalse);
  });
}
