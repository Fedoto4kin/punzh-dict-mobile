// Port of website `link_see_lemmas` / `link_deriv_lemmas` for offline nav.
// Hrefs: punzh://article/{id} when an outbound link matches, else punzh://search/{lemma}.

import "krl_query.dart";
import "orthography.dart";

const String punzhArticleScheme = "punzh://article/";
const String punzhSearchScheme = "punzh://search/";

/// Outbound cross-ref from the open article (table `links`).
class ArticleOutboundLink {
  const ArticleOutboundLink({
    required this.toArticleId,
    required this.kind,
    required this.word,
    this.wordNormalized,
  });

  final int toArticleId;

  /// `see` | `cf` | `deriv`
  final String kind;
  final String word;
  final String? wordNormalized;

  String get displayWord => displayHeadword(word, wordNormalized);
}

/// Fold a lemma/headword for matching HTML text to [ArticleOutboundLink].
String foldLemmaKey(String word) {
  if (word.isEmpty) return "";
  var w = stripKrlApostrophes(
    word.toLowerCase().replaceAll("||", "").replaceAll("|", ""),
  );
  w = w.split(",").first.trim();
  w = w.replaceAll(RegExp(r"(?:\s+(?:\d+|[IVXivx]{1,5}))+$"), "").trim();
  w = w.replaceAll("~", "");
  w = foldInteriorHyphens(w);
  return foldKrlSibilants(w);
}

Map<String, int> lemmaIdMap(Iterable<ArticleOutboundLink> links) {
  final map = <String, int>{};
  for (final link in links) {
    for (final raw in [link.word, link.wordNormalized ?? ""]) {
      final key = foldLemmaKey(raw);
      if (key.isEmpty) continue;
      map.putIfAbsent(key, () => link.toArticleId);
    }
  }
  return map;
}

String punzhArticleUrl(int id) => "$punzhArticleScheme$id";

String punzhSearchUrl(String lemma) {
  final cleaned = lemma.replaceAll("(", "").replaceAll(")", "");
  // encodeComponent: Uri.decodeComponent rejects raw code units >127.
  return "$punzhSearchScheme${Uri.encodeComponent(cleaned)}";
}

String _hrefForLemma(String display, Map<String, int> ids) {
  final key = foldLemmaKey(display.replaceAll("(", "").replaceAll(")", ""));
  final id = ids[key];
  if (id != null) return punzhArticleUrl(id);
  return punzhSearchUrl(display.replaceAll("(", "").replaceAll(")", ""));
}

String _anchor(String display, Map<String, int> ids) {
  final href = _hrefForLemma(display, ids);
  return '<a href="$href">$display</a>';
}

/// Decode a query/path component that may be percent-encoded or raw Unicode
/// (seed HTML sometimes keeps website `/search/l’…` with bare apostrophes).
String decodePunzhQuery(String raw) {
  final withSpaces = raw.replaceAll("+", " ");
  if (!withSpaces.contains("%")) return withSpaces;
  try {
    return Uri.decodeComponent(withSpaces);
  } on ArgumentError {
    return withSpaces;
  }
}

// Apostrophe lookalikes + Karelian letters (approx. website KARELIAN_WORD).
const String _aposClass = "'’`ʼʹ´";
final String _krlWord = "[A-Za-z$_aposClassÜüÄäÖöŠšČčŽži̮\\-]+";
final String _roman = "[IVX]{1,5}(?!$_krlWord)";
final String _krlCont =
    "(?!(?:[IVX]{1,5}|\\d+)(?!$_krlWord))$_krlWord";
final String _karelian = "$_krlWord(?:\\s+$_krlCont)*";
final String _homonym = "(?:\\s+(?:\\d+|$_roman))*";
final String _homonymReq = "(?:\\s+(?:\\d+|$_roman))+";
final String _commaSep = "\\s*,\\s*";
final String _optParen = "(?:\\([^)]*\\))?";

/// Seed/export HTML may already wrap some see-lemmas in `/search/…` anchors
/// (often only the 2nd+ after a comma). Strip those so [_seeList] sees plain text.
final RegExp _unwrapSearchAnchor = RegExp(
  "<a\\s+href=['\"](?:/search/|punzh://search/)[^'\"]*['\"]\\s*>"
  "([^<]*)"
  "</a>",
  caseSensitive: false,
);

final RegExp _seeList = RegExp(
  "<i>(см\\.|ср\\.)</i>\\s+"
  "($_karelian$_optParen$_homonym"
  "(?:$_commaSep$_karelian$_optParen$_homonym|\\s*;\\s*$_karelian$_optParen$_homonymReq)*)"
  "(\\s*[;,]?)?",
);

final RegExp _seeToken = RegExp(
  "($_karelian)(\\([^)]*\\))?((?:\\s+(?:\\d+|$_roman))*)|"
  "($_commaSep|\\s*;\\s*)",
);

final RegExp _derivTagged = RegExp(
  "<i>\\s*(freq|caus|mom|refl)\\s*</i>\\s+от\\s+($_karelian)",
  caseSensitive: false,
);

final RegExp _derivLoose = RegExp("(^|[\\s>])от\\s+($_karelian)");

/// Wrap см./ср./от lemmas with punzh:// links (website `make_link` order).
String makeLink(String html, Map<String, int> lemmaIds) {
  var out = html.replaceAllMapped(_unwrapSearchAnchor, (m) => m.group(1)!);
  out = out.replaceAllMapped(_seeList, (m) {
    final mark = m.group(1)!;
    final blob = m.group(2)!;
    final tailSep = m.group(3) ?? "";
    final bits = StringBuffer();
    for (final token in _seeToken.allMatches(blob)) {
      final word = token.group(1);
      final paren = token.group(2);
      final hom = token.group(3);
      final sep = token.group(4);
      if (word != null) {
        final display = word + (paren ?? "");
        bits.write(_anchor(display, lemmaIds));
        if (hom != null && hom.isNotEmpty) bits.write(hom);
      } else if (sep != null) {
        bits.write(sep);
      }
    }
    return "<i>$mark</i> ${bits.toString()}$tailSep";
  });

  out = out.replaceAllMapped(_derivTagged, (m) {
    final tag = m.group(1)!;
    final lemma = m.group(2)!;
    return "<i>$tag</i> от ${_anchor(lemma, lemmaIds)}";
  });

  out = out.replaceAllMapped(_derivLoose, (m) {
    final prefix = m.group(1)!;
    final lemma = m.group(2)!;
    return "$prefixот ${_anchor(lemma, lemmaIds)}";
  });

  return out;
}

sealed class PunzhUrl {
  const PunzhUrl();
}

class PunzhArticleUrl extends PunzhUrl {
  const PunzhArticleUrl(this.articleId);
  final int articleId;
}

class PunzhSearchUrl extends PunzhUrl {
  const PunzhSearchUrl(this.query);
  final String query;
}

/// Parse in-app article / search deep links from HTML taps.
PunzhUrl? parsePunzhUrl(String url) {
  if (url.startsWith(punzhArticleScheme)) {
    final id = int.tryParse(url.substring(punzhArticleScheme.length));
    if (id == null) return null;
    return PunzhArticleUrl(id);
  }
  if (url.startsWith(punzhSearchScheme)) {
    final q = decodePunzhQuery(url.substring(punzhSearchScheme.length));
    if (q.isEmpty) return null;
    return PunzhSearchUrl(q);
  }
  // Website-style leftover (should not appear after makeLink).
  if (url.startsWith("/search/")) {
    final q = decodePunzhQuery(url.substring("/search/".length));
    if (q.isEmpty) return null;
    return PunzhSearchUrl(q);
  }
  return null;
}
