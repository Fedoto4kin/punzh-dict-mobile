import "package:url_launcher/url_launcher.dart";

/// Open http(s) in the system browser. Returns false if the OS cannot handle it.
Future<bool> openExternalUrl(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return false;
  if (uri.scheme != "http" && uri.scheme != "https") return false;
  if (!await canLaunchUrl(uri)) return false;
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}
