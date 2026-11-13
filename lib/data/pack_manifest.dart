/// Remote mobile pack manifest (`manifest.json` next to dict.sqlite).
class PackManifest {
  const PackManifest({
    required this.schemaVersion,
    required this.dataVersion,
    required this.builtAt,
    required this.sha256,
    required this.size,
    required this.minApp,
    required this.file,
    required this.url,
  });

  final int schemaVersion;
  final String dataVersion;
  final String builtAt;
  final String sha256;
  final int size;
  final String minApp;
  final String file;
  final String url;

  factory PackManifest.fromJson(Map<String, dynamic> json) {
    final schema = json["schema_version"];
    final schemaVersion = schema is int
        ? schema
        : int.tryParse("$schema") ?? (throw const FormatException("schema_version"));
    final sha = "${json["sha256"] ?? ""}".trim().toLowerCase();
    if (sha.length != 64) {
      throw const FormatException("sha256");
    }
    final sizeRaw = json["size"];
    final size = sizeRaw is int
        ? sizeRaw
        : int.tryParse("$sizeRaw") ?? (throw const FormatException("size"));
    final file = "${json["file"] ?? "dict.sqlite"}".trim();
    final url = "${json["url"] ?? file}".trim();
    if (file.isEmpty || url.isEmpty) {
      throw const FormatException("file/url");
    }
    final dataVersion = "${json["data_version"] ?? ""}".trim();
    final minApp = "${json["min_app"] ?? ""}".trim();
    final builtAt = "${json["built_at"] ?? ""}".trim();
    if (dataVersion.isEmpty || minApp.isEmpty) {
      throw const FormatException("data_version/min_app");
    }
    return PackManifest(
      schemaVersion: schemaVersion,
      dataVersion: dataVersion,
      builtAt: builtAt,
      sha256: sha,
      size: size,
      minApp: minApp,
      file: file,
      url: url,
    );
  }
}
