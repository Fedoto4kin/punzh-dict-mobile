// Port of `dict.helpers.orphography` (website `|clear` / `normalization`).
// Keep in sync with `app/dict/helpers/orphography.py`.

const String krlApostrophe = "\u2019"; // ’

const Set<String> krlApostrophes = {
  krlApostrophe,
  "'",
  "`",
  "\u02BC", // ʼ
  "\u02B9", // ʹ
  "\u00B4", // ´
};

String stripKrlApostrophes(String text) {
  final buf = StringBuffer();
  for (final ch in text.split("")) {
    if (!krlApostrophes.contains(ch)) buf.write(ch);
  }
  return buf.toString();
}

String canonicalizeKrlApostrophes(String text) {
  var out = text;
  for (final ch in krlApostrophes) {
    if (ch != krlApostrophe) {
      out = out.replaceAll(ch, krlApostrophe);
    }
  }
  return out;
}

/// Standard orthography for a dictionary headword (same as Django `normalization`).
String normalization(String header) {
  String word = header;
  String? variant;
  String? appendix;

  if (header.contains(",")) {
    if (header.contains("~")) {
      final m = RegExp(r"~(.*)").firstMatch(header);
      appendix = m?.group(1);
    } else {
      final m = RegExp(r",\s(.*)").firstMatch(header);
      variant = m?.group(1);
    }
    word = header.split(",")[0];
  }

  final base = word.split(RegExp(r"\|{2}")).first;
  word = word.replaceAll("||", "");
  var result = newOrthography(word);

  if (appendix != null) {
    variant = base + appendix;
  }
  if (variant != null) {
    result = "$result, ${newOrthography(variant)}";
  }
  return result;
}

String newOrthography(String word) {
  String clearPallat(String input) {
    var w = canonicalizeKrlApostrophes(input);
    // Same as Python: ([^aou$]) — `$` is a literal inside the class.
    w = w.replaceAllMapped(
      RegExp("${RegExp.escape(krlApostrophe)}([^aou\$])"),
      (m) => m.group(1)!,
    );
    w = w.replaceAllMapped(
      RegExp("([dlnrszt])(\\w)${RegExp.escape(krlApostrophe)}"),
      (m) => "${m.group(1)}$krlApostrophe${m.group(2)}$krlApostrophe",
    );
    return w;
  }

  String partProc(String input) {
    var w = input.replaceAll("ü", "y").replaceAll("Ü", "Y");
    if (w.contains("w")) {
      for (final part in RegExp(r"(?:\w+w[^|]*)").allMatches(w).map((m) => m[0]!)) {
        final replaced = (part.contains("a") ||
                part.contains("o") ||
                part.contains("u"))
            ? part.replaceAll("w", "u")
            : part.replaceAll("w", "y");
        w = w.replaceAll(part, replaced);
      }
    }
    return w;
  }

  final parts = <String>[];
  if (word.contains("|")) {
    for (final part in word.split("|")) {
      parts.add(partProc(part));
    }
  } else {
    parts.add(partProc(word));
  }
  return clearPallat(parts.join());
}

/// Card title on the website: `word_normalized` as-is, else `|clear` (= normalization).
String displayHeadword(String word, String? wordNormalized) {
  final corrected = wordNormalized?.trim();
  if (corrected != null && corrected.isNotEmpty) {
    return corrected;
  }
  return normalization(word);
}
