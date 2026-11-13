import "dart:async";
import "dart:convert";
import "dart:io";

import "package:crypto/crypto.dart";
import "package:http/http.dart" as http;
import "package:path/path.dart" as p;
import "package:path_provider/path_provider.dart";

import "../schema.dart";
import "app_version.dart";
import "dictionary_session.dart";
import "pack_manifest.dart";

const String defaultMobilePackBaseUrl =
    "https://punzhina.krc.karelia.ru/mobile-pack/";

/// Pack base URL. Override at build/run:
/// `--dart-define=MOBILE_PACK_BASE_URL=http://192.168.x.x:8000/`
String mobilePackBaseUrl() {
  const fromEnv = String.fromEnvironment("MOBILE_PACK_BASE_URL");
  if (fromEnv.isEmpty) return defaultMobilePackBaseUrl;
  return fromEnv.endsWith("/") ? fromEnv : "$fromEnv/";
}


const String noInternetMessage = "Нет подключения к Интернету.";

bool looksLikeConnectivityFailure(Object error) {
  if (error is SocketException) return true;
  if (error is TimeoutException) return true;
  if (error is HandshakeException) return true;
  if (error is http.ClientException) return true;
  final s = "$error".toLowerCase();
  return s.contains("socketexception") ||
      s.contains("clientexception") ||
      s.contains("connection refused") ||
      s.contains("network is unreachable") ||
      s.contains("failed host lookup") ||
      s.contains("timed out") ||
      s.contains("timeout") ||
      s.contains("connection reset") ||
      s.contains("connection abort");
}

enum UpdateCheckKind {
  upToDate,
  available,
  incompatibleSchema,
  appTooOld,
  networkError,
  badManifest,
}

class UpdateCheckResult {
  const UpdateCheckResult({
    required this.kind,
    this.manifest,
    this.localDataVersion,
    this.message,
  });

  final UpdateCheckKind kind;
  final PackManifest? manifest;
  final String? localDataVersion;
  final String? message;
}

class DownloadProgress {
  const DownloadProgress({required this.received, required this.total});

  final int received;

  /// From Content-Length / manifest size; 0 if unknown.
  final int total;

  double? get fraction {
    if (total <= 0) return null;
    return (received / total).clamp(0.0, 1.0);
  }
}

class DbUpdater {
  DbUpdater({
    required this.session,
    http.Client? client,
    String? baseUrl,
  })  : _client = client ?? http.Client(),
        baseUrl = baseUrl ?? mobilePackBaseUrl();

  final DictionarySession session;
  final http.Client _client;
  final String baseUrl;

  Uri get manifestUri => Uri.parse("${baseUrl}manifest.json");

  Future<UpdateCheckResult> check({required String appVersion}) async {
    final local = await session.localMeta();
    late final PackManifest manifest;
    try {
      final res =
          await _client.get(manifestUri).timeout(const Duration(seconds: 30));
      if (res.statusCode != 200) {
        return UpdateCheckResult(
          kind: UpdateCheckKind.networkError,
          localDataVersion: local.dataVersion,
          message: noInternetMessage,
        );
      }
      final decoded = jsonDecode(utf8.decode(res.bodyBytes));
      if (decoded is! Map) {
        throw const FormatException("manifest root");
      }
      manifest = PackManifest.fromJson(Map<String, dynamic>.from(decoded));
    } on FormatException {
      return UpdateCheckResult(
        kind: UpdateCheckKind.badManifest,
        localDataVersion: local.dataVersion,
        message: "Некорректный манифест",
      );
    } catch (e) {
      return UpdateCheckResult(
        kind: UpdateCheckKind.networkError,
        localDataVersion: local.dataVersion,
        message: noInternetMessage,
      );
    }

    if (manifest.schemaVersion != schemaVersion) {
      return UpdateCheckResult(
        kind: UpdateCheckKind.incompatibleSchema,
        manifest: manifest,
        localDataVersion: local.dataVersion,
        message:
            "Пакет schema ${manifest.schemaVersion}, приложение ждёт $schemaVersion",
      );
    }
    if (isAppVersionBelowMin(appVersion, manifest.minApp)) {
      return UpdateCheckResult(
        kind: UpdateCheckKind.appTooOld,
        manifest: manifest,
        localDataVersion: local.dataVersion,
        message:
            "Нужна версия приложения ${manifest.minApp} или новее (сейчас $appVersion)",
      );
    }
    if (local.dataVersion != null &&
        local.dataVersion == manifest.dataVersion) {
      return UpdateCheckResult(
        kind: UpdateCheckKind.upToDate,
        manifest: manifest,
        localDataVersion: local.dataVersion,
        message: "Словарь уже актуален",
      );
    }
    return UpdateCheckResult(
      kind: UpdateCheckKind.available,
      manifest: manifest,
      localDataVersion: local.dataVersion,
    );
  }

  /// Download pack, verify sha256, atomically replace runtime DB.
  Future<void> downloadAndApply(
    PackManifest manifest, {
    void Function(DownloadProgress progress)? onProgress,
  }) async {
    final fileUri = Uri.parse(baseUrl).resolve(manifest.url);
    final tmpDir = await getTemporaryDirectory();
    final tmp = File(
      p.join(tmpDir.path, "punzh-pack-${manifest.dataVersion}.sqlite"),
    );
    if (await tmp.exists()) {
      await tmp.delete();
    }

    final request = http.Request("GET", fileUri);
    final streamed =
        await _client.send(request).timeout(const Duration(seconds: 60));
    if (streamed.statusCode != 200) {
      throw const SocketException(noInternetMessage);
    }
    final total = streamed.contentLength ?? manifest.size;
    final sink = tmp.openWrite();
    var received = 0;
    try {
      await for (final chunk in streamed.stream) {
        sink.add(chunk);
        received += chunk.length;
        onProgress?.call(DownloadProgress(received: received, total: total));
      }
      await sink.flush();
      await sink.close();
    } catch (e) {
      await sink.close();
      if (await tmp.exists()) {
        await tmp.delete();
      }
      rethrow;
    }

    final actual = (await sha256.bind(tmp.openRead()).first).toString();
    if (actual != manifest.sha256) {
      await tmp.delete();
      throw StateError(
        "Контрольная сумма не совпала (ожидали ${manifest.sha256}, получили $actual)",
      );
    }
    if (manifest.size > 0 && received != manifest.size) {
      await tmp.delete();
      throw StateError(
        "Размер файла $received, в манифесте ${manifest.size}",
      );
    }

    try {
      await session.replaceWithFile(tmp);
    } finally {
      if (await tmp.exists()) {
        await tmp.delete();
      }
    }
  }
}
