import "package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart";
import "package:material_ui/material_ui.dart";

import "../article_format.dart";
import "../article_links.dart";
import "../data/dictionary_repository.dart";
import "../theme.dart";

/// Inline / full article HTML with website display styles.
class ArticleBody extends StatelessWidget {
  const ArticleBody({
    super.key,
    required this.article,
    required this.italicTagValues,
    this.compact = false,
    this.onPunzhUrl,
  });

  final ArticleDetail article;
  final Set<String> italicTagValues;
  final bool compact;
  final Future<bool> Function(PunzhUrl url)? onPunzhUrl;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      for (final raw in [article.articleHtml, ...article.additionsHtml])
        if (raw.trim().isNotEmpty)
          formatArticleHtml(
            raw,
            italicTagValues,
            lemmaIds: article.lemmaIds,
          ),
    ];
    final html = parts.join("<hr/>");
    final base = Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, compact ? 0 : 8, 16, 12),
      child: HtmlWidget(
        html,
        textStyle: base?.copyWith(height: 1.45, fontSize: 15),
        onTapUrl: (url) async {
          final parsed = parsePunzhUrl(url);
          if (parsed == null || onPunzhUrl == null) return false;
          return onPunzhUrl!(parsed);
        },
        customStylesBuilder: (element) {
          final classes = element.classes;
          final tag = element.localName;
          if (tag == "a") {
            // No underline: it clashes with KRL apostrophes (’). Blue +
            // semibold is enough on mobile (no hover).
            return {
              "color": _cssHex(PunzhColors.link),
              "text-decoration": "none",
              "font-weight": "600",
            };
          }
          // Website: .text-tag, .text-tag .text-rus { color: #1B4332 }
          final insideTag = classes.contains("text-tag") ||
              _hasAncestorClass(element, "text-tag");
          if (classes.contains("text-tag") ||
              (classes.contains("text-rus") && insideTag)) {
            return {"color": "#1B4332"};
          }
          if (classes.contains("text-rus")) {
            return {"color": _cssHex(PunzhColors.brand)};
          }
          if (classes.contains("text-muted")) {
            return {"color": "#6c757d"};
          }
          if (classes.contains("font-weight-normal")) {
            return {"font-weight": "400"};
          }
          if (tag == "ol") {
            return {
              "padding-left": "1.25em",
              "margin-bottom": "0.35rem",
            };
          }
          if (tag == "b" || tag == "strong") {
            return {"font-weight": "700"};
          }
          if (tag == "i" || tag == "em") {
            return {"font-style": "italic"};
          }
          if (tag == "hr") {
            return {
              "margin-top": "0.6em",
              "margin-bottom": "0.6em",
              "border-color": "#dee2e6",
            };
          }
          return null;
        },
      ),
    );
  }

  static String _cssHex(Color c) {
    final v = c.toARGB32() & 0xFFFFFF;
    return "#${v.toRadixString(16).padLeft(6, "0")}";
  }

  static bool _hasAncestorClass(dynamic element, String className) {
    var parent = element.parent;
    while (parent != null) {
      try {
        if (parent.classes.contains(className)) return true;
      } catch (_) {
        // Non-element node.
      }
      try {
        parent = parent.parent;
      } catch (_) {
        break;
      }
    }
    return false;
  }
}
