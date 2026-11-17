/// Remote app release stub (`app-manifest.json` next to the stable APK).
/// Written by [scripts/publish_downloads.sh]; independent of dictionary pack
/// `manifest.json`.
class AppManifest {
  const AppManifest({
    required this.versionName,
    required this.versionCode,
    required this.apkUrl,
    required this.publishedAt,
  });

  final String versionName;
  final int versionCode;
  final String apkUrl;
  final String publishedAt;

  factory AppManifest.fromJson(Map<String, dynamic> json) {
    final name = "${json["version_name"] ?? ""}".trim();
    final codeRaw = json["version_code"];
    final code = codeRaw is int
        ? codeRaw
        : int.tryParse("$codeRaw") ??
            (throw const FormatException("version_code"));
    if (code < 1) {
      throw const FormatException("version_code");
    }
    final apkUrl = "${json["apk_url"] ?? ""}".trim();
    if (apkUrl.isEmpty) {
      throw const FormatException("apk_url");
    }
    final publishedAt = "${json["published_at"] ?? ""}".trim();
    return AppManifest(
      versionName: name.isEmpty ? "$code" : name,
      versionCode: code,
      apkUrl: apkUrl,
      publishedAt: publishedAt,
    );
  }
}
