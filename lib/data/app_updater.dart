import "dart:convert";

import "package:http/http.dart" as http;

import "app_manifest.dart";
import "db_updater.dart";

const String defaultApkDownloadUrl = "https://punzhina.krc.karelia.ru/app/apk/";

enum AppUpdateCheckKind {
  upToDate,
  available,
  networkError,
  badManifest,
}

class AppUpdateCheckResult {
  const AppUpdateCheckResult({
    required this.kind,
    this.manifest,
    this.message,
  });

  final AppUpdateCheckKind kind;
  final AppManifest? manifest;
  final String? message;
}

/// Fetch [app-manifest.json] and compare remote [AppManifest.versionCode] to
/// the installed [localVersionCode] (`PackageInfo.buildNumber`).
class AppUpdater {
  AppUpdater({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? mobilePackBaseUrl();

  final http.Client _client;
  final String _baseUrl;

  Uri get manifestUri => Uri.parse("${_baseUrl}app-manifest.json");

  Future<AppUpdateCheckResult> check({required int localVersionCode}) async {
    if (localVersionCode < 1) {
      return const AppUpdateCheckResult(
        kind: AppUpdateCheckKind.badManifest,
        message: "Не удалось определить версию приложения.",
      );
    }
    late final http.Response response;
    try {
      response = await _client
          .get(manifestUri)
          .timeout(const Duration(seconds: 20));
    } catch (e) {
      return AppUpdateCheckResult(
        kind: AppUpdateCheckKind.networkError,
        message: looksLikeConnectivityFailure(e)
            ? noInternetMessage
            : "Ошибка сети: $e",
      );
    }
    if (response.statusCode != 200) {
      return AppUpdateCheckResult(
        kind: AppUpdateCheckKind.networkError,
        message: "Сервер ответил ${response.statusCode}.",
      );
    }
    late final AppManifest manifest;
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException("root");
      }
      manifest = AppManifest.fromJson(decoded);
    } catch (_) {
      return const AppUpdateCheckResult(
        kind: AppUpdateCheckKind.badManifest,
        message: "Некорректный манифест приложения на сервере.",
      );
    }
    if (manifest.versionCode > localVersionCode) {
      return AppUpdateCheckResult(
        kind: AppUpdateCheckKind.available,
        manifest: manifest,
        message: "Доступна версия ${manifest.versionName}",
      );
    }
    return AppUpdateCheckResult(
      kind: AppUpdateCheckKind.upToDate,
      manifest: manifest,
      message: "Установлена актуальная версия.",
    );
  }
}
