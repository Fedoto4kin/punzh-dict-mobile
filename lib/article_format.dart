// Port of website article HTML display pipeline
// (`dict.tag_highlight.format_article_html` / templatetags filters).

import "article_links.dart";

final RegExp _pipeRe = RegExp(r"([\|]{1,2})");
final RegExp _breakRe = RegExp(r"(◊)");
final RegExp _rusRe = RegExp(r"([А-Яа-яЁё]+)");
final RegExp _italicRe = RegExp(r"<i>([^<]*)</i>");

/// `|nice` — mute morph boundary marks `|/||` inside headword.
String nice(String text) {
  return text.replaceAllMapped(
    _pipeRe,
    (m) =>
        '<span class="text-muted font-weight-normal">${m.group(1)}</span>',
  );
}

/// `|make_break` — phraseology mark.
String makeBreak(String text) {
  return text.replaceAllMapped(_breakRe, (m) => "<hr/>${m.group(1)}");
}

/// `|highlight_rus` — Russian gloss spans.
String highlightRus(String text) {
  return text.replaceAllMapped(
    _rusRe,
    (m) => '<span class="text-rus">${m.group(1)}</span>',
  );
}

/// `tag_highlight.highlight_tags` — known пометы in `<i>`.
String highlightTags(String html, Set<String> italicTagValues) {
  if (html.isEmpty || italicTagValues.isEmpty) return html;
  return html.replaceAllMapped(_italicRe, (m) {
    final inner = m.group(1)!;
    if (italicTagValues.contains(inner)) {
      return '<i class="text-tag">$inner</i>';
    }
    return m.group(0)!;
  });
}

/// Same order as Django `format_article_html` (make_link → nice → …).
String formatArticleHtml(
  String html,
  Set<String> italicTagValues, {
  Map<String, int> lemmaIds = const {},
}) {
  if (html.isEmpty) return "";
  var t = html;
  t = makeLink(t, lemmaIds);
  t = nice(t);
  t = makeBreak(t);
  t = highlightTags(t, italicTagValues);
  t = highlightRus(t);
  return t;
}
