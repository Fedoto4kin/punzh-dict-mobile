import "dart:convert";

import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart";
import "package:punzh_dict/data/app_updater.dart";

void main() {
  Map<String, dynamic> remote({int code = 30, String name = "1.0.5"}) => {
        "version_name": name,
        "version_code": code,
        "apk_url": "https://punzhina.krc.karelia.ru/app/apk/",
        "published_at": "2026-11-17T12:00:00Z",
      };

  test("available when remote version_code is higher", () async {
    final client = MockClient((request) async {
      expect(request.url.path, endsWith("app-manifest.json"));
      return http.Response(jsonEncode(remote(code: 30)), 200);
    });
    final updater = AppUpdater(
      client: client,
      baseUrl: "https://example.test/mobile-pack/",
    );
    final result = await updater.check(localVersionCode: 25);
    expect(result.kind, AppUpdateCheckKind.available);
    expect(result.manifest?.versionCode, 30);
    expect(result.manifest?.versionName, "1.0.5");
  });

  test("upToDate when remote version_code equals local", () async {
    final client = MockClient(
      (_) async => http.Response(jsonEncode(remote(code: 25)), 200),
    );
    final result = await AppUpdater(
      client: client,
      baseUrl: "https://example.test/mobile-pack/",
    ).check(localVersionCode: 25);
    expect(result.kind, AppUpdateCheckKind.upToDate);
  });

  test("upToDate when remote version_code is lower", () async {
    final client = MockClient(
      (_) async => http.Response(jsonEncode(remote(code: 10)), 200),
    );
    final result = await AppUpdater(
      client: client,
      baseUrl: "https://example.test/mobile-pack/",
    ).check(localVersionCode: 25);
    expect(result.kind, AppUpdateCheckKind.upToDate);
  });

  test("badManifest on invalid JSON body", () async {
    final client = MockClient(
      (_) async => http.Response("not-json", 200),
    );
    final result = await AppUpdater(
      client: client,
      baseUrl: "https://example.test/mobile-pack/",
    ).check(localVersionCode: 1);
    expect(result.kind, AppUpdateCheckKind.badManifest);
  });

  test("networkError on non-200", () async {
    final client = MockClient(
      (_) async => http.Response("missing", 404),
    );
    final result = await AppUpdater(
      client: client,
      baseUrl: "https://example.test/mobile-pack/",
    ).check(localVersionCode: 1);
    expect(result.kind, AppUpdateCheckKind.networkError);
  });
}
