import "package:flutter_test/flutter_test.dart";
import "package:punzh_dict/data/app_manifest.dart";

void main() {
  test("fromJson reads required fields", () {
    final m = AppManifest.fromJson({
      "version_name": "1.0.4",
      "version_code": 25,
      "apk_url": "https://punzhina.krc.karelia.ru/app/apk/",
      "published_at": "2026-11-17T12:00:00Z",
    });
    expect(m.versionName, "1.0.4");
    expect(m.versionCode, 25);
    expect(m.apkUrl, startsWith("https://"));
  });

  test("fromJson parses version_code string", () {
    final m = AppManifest.fromJson({
      "version_name": "1.0.0",
      "version_code": "3",
      "apk_url": "https://example.test/app/apk/",
    });
    expect(m.versionCode, 3);
    expect(m.publishedAt, "");
  });

  test("fromJson rejects missing apk_url", () {
    expect(
      () => AppManifest.fromJson({
        "version_name": "1.0.0",
        "version_code": 1,
      }),
      throwsFormatException,
    );
  });

  test("fromJson rejects non-positive version_code", () {
    expect(
      () => AppManifest.fromJson({
        "version_code": 0,
        "apk_url": "https://example.test/a",
      }),
      throwsFormatException,
    );
  });
}
