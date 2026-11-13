import "package:flutter_test/flutter_test.dart";
import "package:punzh_dict/data/pack_manifest.dart";

void main() {
  test("fromJson reads required fields", () {
    final m = PackManifest.fromJson({
      "schema_version": 2,
      "data_version": "abc123def456",
      "built_at": "2026-11-13T00:00:00+00:00",
      "sha256": "a" * 64,
      "size": 12,
      "min_app": "0.1.0",
      "file": "dict.sqlite",
      "url": "dict.sqlite",
    });
    expect(m.schemaVersion, 2);
    expect(m.dataVersion, "abc123def456");
    expect(m.sha256.length, 64);
    expect(m.url, "dict.sqlite");
  });

  test("fromJson defaults url from file", () {
    final m = PackManifest.fromJson({
      "schema_version": "2",
      "data_version": "x",
      "built_at": "",
      "sha256": "b" * 64,
      "size": "10",
      "min_app": "0.1.0",
      "file": "dict.sqlite",
    });
    expect(m.url, "dict.sqlite");
    expect(m.size, 10);
  });

  test("fromJson rejects short sha", () {
    expect(
      () => PackManifest.fromJson({
        "schema_version": 2,
        "data_version": "x",
        "built_at": "",
        "sha256": "dead",
        "size": 1,
        "min_app": "0.1.0",
        "file": "dict.sqlite",
      }),
      throwsFormatException,
    );
  });
}
