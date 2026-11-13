// Port of `dict.search.krl.prepare_krl_ilike_query` (+ helpers it uses).
// First-web-version contract from index.html: ignore soft marks / ||, fold
// w-variants via the word index, allow š/č/ž without carons, ü↔y on the
// query side, `.` = one char, `?` = any run. Do not fold ä/ö (vowel harmony).

import "orthography.dart";

final RegExp _interiorHyphen = RegExp(r"(?<=\w)-(?=\w)", unicode: true);

/// Interior hyphen ≈ space: mul’l’in-mal’l’in ↔ mullin mallin.
String foldInteriorHyphens(String text) {
  return text.replaceAllMapped(_interiorHyphen, (_) => " ");
}

/// Map a user query to a SQLite/Postgres LIKE/ILIKE pattern.
String prepareKrlIlikeQuery(String query) {
  var q = stripKrlApostrophes(query);
  // Same keys as `_KRL_ILIKE_TRANS` in app/dict/search/krl.py.
  const map = <String, String>{
    ";": "",
    ",": "",
    "(": "",
    ")": "",
    "š": "s",
    "Š": "S",
    "č": "c",
    "Č": "C",
    "ž": "z",
    "Ž": "Z",
    "ü": "y",
    "Ü": "Y",
    "…": "",
    "?": "%",
    ".": "_",
  };
  final buf = StringBuffer();
  for (final unit in q.split("")) {
    buf.write(map[unit] ?? unit);
  }
  q = buf.toString();
  // Ves’egonsk i̮ may be typed as plain i (documented on the first index page).
  q = q.replaceAll("i̮", "i");
  return foldInteriorHyphens(q);
}

/// Fold for fuzzy suggestions: strip user wildcards, then same as ILIKE prep.
String prepareKrlFuzzyQuery(String query) {
  final stripped = query.replaceAll(RegExp(r"[?.]"), "");
  return prepareKrlIlikeQuery(stripped).toLowerCase();
}

