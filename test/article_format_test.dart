import "package:flutter_test/flutter_test.dart";
import "package:punzh_dict/article_format.dart";

void main() {
  test("nice mutes pipe marks", () {
    expect(
      nice("<b>dar||a II</b>"),
      '<b>dar<span class="text-muted font-weight-normal">||</span>a II</b>',
    );
  });

  test("highlightRus wraps Cyrillic", () {
    expect(
      highlightRus("да, и"),
      '<span class="text-rus">да</span>, <span class="text-rus">и</span>',
    );
  });

  test("highlightTags only known italic tags", () {
    final tags = {"s", "conj"};
    expect(
      highlightTags("<i>s</i> <i>unknown</i>", tags),
      '<i class="text-tag">s</i> <i>unknown</i>',
    );
  });

  test("makeBreak inserts hr before lozenge", () {
    expect(makeBreak("foo ◊ bar"), "foo <hr/>◊ bar");
  });

  test("formatArticleHtml pipeline order", () {
    final out = formatArticleHtml(
      "<b>da</b> <i>conj</i> да; x ◊ y",
      {"conj"},
    );
    expect(out, contains('class="text-tag">conj</i>'));
    expect(out, contains('class="text-rus">да</span>'));
    expect(out, contains("<hr/>◊"));
  });
}
