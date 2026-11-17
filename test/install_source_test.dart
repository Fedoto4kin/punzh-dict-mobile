import "package:flutter_test/flutter_test.dart";
import "package:punzh_dict/data/install_source.dart";

void main() {
  test("store installer packages include RuStore and Play", () {
    expect(storeInstallerPackages, contains("ru.vk.store"));
    expect(storeInstallerPackages, contains("com.android.vending"));
  });

  test("installerIsStore recognizes stores", () {
    expect(installerIsStore("ru.vk.store"), isTrue);
    expect(installerIsStore("com.android.vending"), isTrue);
    expect(installerIsStore(" com.android.vending "), isTrue);
  });

  test("installerIsStore treats sideload as non-store", () {
    expect(installerIsStore(null), isFalse);
    expect(installerIsStore(""), isFalse);
    expect(installerIsStore("com.android.chrome"), isFalse);
    expect(installerIsStore("com.google.android.packageinstaller"), isFalse);
  });
}
