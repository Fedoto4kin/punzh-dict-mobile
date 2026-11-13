/// Compare dotted numeric versions (e.g. min_app vs package versionName).
/// Returns negative if [a] < [b], 0 if equal, positive if [a] > [b].
int compareVersionStrings(String a, String b) {
  List<int> parts(String v) {
    final core = v.trim().split("+").first.split("-").first;
    return [
      for (final p in core.split(".")) int.tryParse(p) ?? 0,
    ];
  }

  final pa = parts(a);
  final pb = parts(b);
  final n = pa.length > pb.length ? pa.length : pb.length;
  for (var i = 0; i < n; i++) {
    final x = i < pa.length ? pa[i] : 0;
    final y = i < pb.length ? pb[i] : 0;
    if (x != y) return x - y;
  }
  return 0;
}

bool isAppVersionBelowMin(String appVersion, String minApp) {
  return compareVersionStrings(appVersion, minApp) < 0;
}
