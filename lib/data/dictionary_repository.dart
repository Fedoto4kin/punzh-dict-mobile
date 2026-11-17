import "package:sqflite/sqflite.dart";

import "../article_links.dart";
import "../krl_query.dart";
import "../levenshtein.dart";
import "../orthography.dart";
import "tag_filter_state.dart";

export "../article_links.dart" show ArticleOutboundLink;

class ArticleSummary {
  const ArticleSummary({
    required this.id,
    required this.word,
    this.wordNormalized,
    this.posTags = const [],
    this.translations = const [],
    this.seeTargets = const [],
    this.derivTargets = const [],
    this.inheritedTranslations = const [],
  });

  final int id;
  final String word;
  final String? wordNormalized;

  /// Short POS marks (`tags.tag`, type=2), already ordered.
  final List<String> posTags;

  /// Own Russian glosses from `translations.rus_word`
  /// (`hide_from_register = 0` only).
  final List<String> translations;

  /// Display headwords of outgoing see/cf targets.
  final List<String> seeTargets;

  /// Display headwords of outgoing deriv targets.
  final List<String> derivTargets;

  /// Glosses inherited from the first see/cf target when [translations] empty.
  final List<String> inheritedTranslations;

  String get displayWord => displayHeadword(word, wordNormalized);

  /// List subtitle: POS, glosses, or см./от when the article is a cross-ref.
  String get previewLine {
    final pos = posTags.take(2).join(", ");
    String glossLine(List<String> glosses) {
      if (glosses.isEmpty) return "";
      final parts = glosses.take(3).toList();
      return parts.join(", ") + (glosses.length > 3 ? "…" : "");
    }

    final ownGloss = glossLine(translations);
    if (ownGloss.isNotEmpty) {
      if (pos.isEmpty) return ownGloss;
      return "$pos · $ownGloss";
    }

    if (seeTargets.isNotEmpty) {
      final see =
          "см. ${seeTargets.take(2).join(", ")}${seeTargets.length > 2 ? "…" : ""}";
      final inh = glossLine(inheritedTranslations);
      if (pos.isEmpty && inh.isEmpty) return see;
      if (pos.isEmpty) return "$see · $inh";
      if (inh.isEmpty) return "$pos · $see";
      return "$pos · $see · $inh";
    }

    if (derivTargets.isNotEmpty) {
      final deriv = "от ${derivTargets.first}";
      if (pos.isEmpty) return deriv;
      return "$pos · $deriv";
    }

    return pos;
  }
}

class ArticleDetail {
  const ArticleDetail({
    required this.id,
    required this.word,
    this.wordNormalized,
    required this.articleHtml,
    required this.additionsHtml,
    this.outboundLinks = const [],
  });

  final int id;
  final String word;
  final String? wordNormalized;
  final String articleHtml;
  final List<String> additionsHtml;
  final List<ArticleOutboundLink> outboundLinks;

  String get displayWord => displayHeadword(word, wordNormalized);

  Map<String, int> get lemmaIds => lemmaIdMap(outboundLinks);
}

class DictionaryRepository {
  DictionaryRepository(this._db);

  final Database _db;
  Set<String>? _italicTagValues;
  List<String>? _wordForms;

  /// Tags eligible for the filter sheet (types 1–4; grammar parents only).
  Future<List<DictTag>> listFilterTags() async {
    final rows = await _db.rawQuery(
      """
      SELECT id, tag, name, type, level, sorting
      FROM tags
      WHERE type IN (1, 2, 3, 4)
        AND NOT (type = 2 AND level != 0)
      ORDER BY type ASC, sorting ASC, name ASC, id ASC
      """,
    );
    return [for (final r in rows) dictTagFromRow(r)];
  }

  /// Fast letter index without POS/gloss enrich (for progressive UI).
  Future<List<ArticleSummary>> articlesByLetter(
    String letter, {
    List<int> tagIds = const [],
    bool phrase = false,
  }) async {
    final letterArg = letter.toUpperCase();
    if (tagIds.isEmpty && !phrase) {
      final rows = await _db.query(
        "articles",
        columns: ["id", "word", "word_normalized"],
        where: "first_letter = ?",
        whereArgs: [letterArg],
        orderBy: "sort_key ASC, id ASC",
      );
      return _mapSummaries(rows);
    }
    final sql = StringBuffer(
      """
      SELECT a.id, a.word, a.word_normalized
      FROM articles a
      WHERE a.first_letter = ?
      """,
    );
    final args = <Object?>[letterArg];
    _appendTagFilters(sql, args, tagIds: tagIds, phrase: phrase, alias: "a");
    sql.write(" ORDER BY a.sort_key ASC, a.id ASC");
    final rows = await _db.rawQuery(sql.toString(), args);
    return _mapSummaries(rows);
  }

  /// Fill POS / translations / see-previews for an already loaded list.
  ///
  /// Large batches are chunked so SQLite variable limits and peak RAM stay
  /// bounded (big letters like K have ~3k rows).
  Future<List<ArticleSummary>> enrichSummaries(
    List<ArticleSummary> items, {
    int chunkSize = 200,
  }) async {
    if (items.isEmpty) return items;
    if (items.length <= chunkSize) return _enrich(items);
    final out = <ArticleSummary>[];
    for (var i = 0; i < items.length; i += chunkSize) {
      final end = (i + chunkSize < items.length) ? i + chunkSize : items.length;
      out.addAll(await _enrich(items.sublist(i, end)));
    }
    return out;
  }

  Future<ArticleDetail?> articleById(int id) async {
    final rows = await _db.query(
      "articles",
      columns: ["id", "word", "word_normalized", "article_html"],
      where: "id = ?",
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final r = rows.first;
    final additions = await _db.query(
      "additions",
      columns: ["article_html"],
      where: "article_id = ?",
      whereArgs: [id],
      orderBy: "id DESC",
    );
    final linkRows = await _db.rawQuery(
      """
      SELECT l.to_article_id AS to_article_id, l.kind AS kind,
             a.word AS word, a.word_normalized AS word_normalized
      FROM links l
      JOIN articles a ON a.id = l.to_article_id
      WHERE l.from_article_id = ?
      ORDER BY l.id
      """,
      [id],
    );
    return ArticleDetail(
      id: r["id"] as int,
      word: r["word"] as String,
      wordNormalized: r["word_normalized"] as String?,
      articleHtml: r["article_html"] as String? ?? "",
      additionsHtml: additions
          .map((a) => a["article_html"] as String? ?? "")
          .where((h) => h.isNotEmpty)
          .toList(),
      outboundLinks: [
        for (final row in linkRows)
          ArticleOutboundLink(
            toArticleId: row["to_article_id"] as int,
            kind: row["kind"] as String? ?? "see",
            word: row["word"] as String? ?? "",
            wordNormalized: row["word_normalized"] as String?,
          ),
      ],
    );
  }

  Future<ArticleSummary?> articleSummaryById(int id) async {
    final rows = await _db.query(
      "articles",
      columns: ["id", "word", "word_normalized"],
      where: "id = ?",
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final list = await _enrich(_mapSummaries(rows));
    return list.isEmpty ? null : list.first;
  }

  /// Resolve summaries for [ids] in the same order; missing ids are null.
  Future<List<ArticleSummary?>> summariesByIds(List<int> ids) async {
    if (ids.isEmpty) return const [];
    final placeholders = List.filled(ids.length, "?").join(",");
    final rows = await _db.rawQuery(
      """
      SELECT id, word, word_normalized
      FROM articles
      WHERE id IN ($placeholders)
      """,
      ids,
    );
    final enriched = await enrichSummaries(_mapSummaries(rows));
    final byId = {for (final a in enriched) a.id: a};
    return [for (final id in ids) byId[id]];
  }

  /// Karelian search as on the web: fold query like
  /// `prepare_krl_ilike_query`, match `words` with LIKE (exact unless
  /// user uses wildcards `.` / `?`).
  Future<List<ArticleSummary>> searchKarelian(
    String query, {
    List<int> tagIds = const [],
    bool phrase = false,
  }) async {
    final pattern = prepareKrlIlikeQuery(query.trim());
    if (pattern.isEmpty) return const [];
    final sql = StringBuffer(
      """
      SELECT DISTINCT a.id, a.word, a.word_normalized
      FROM words w
      JOIN articles a ON a.id = w.article_id
      WHERE w.word LIKE ? COLLATE NOCASE
      """,
    );
    final args = <Object?>[pattern];
    _appendTagFilters(sql, args, tagIds: tagIds, phrase: phrase, alias: "a");
    sql.write(" ORDER BY a.sort_key ASC, a.id ASC LIMIT 200");
    final rows = await _db.rawQuery(sql.toString(), args);
    return _enrich(_mapSummaries(rows));
  }

  /// Near-miss headwords when exact KRL LIKE is empty (web `search_possible`
  /// spirit: Levenshtein ≤ 2 on `words`; no PG trigrams).
  Future<List<String>> searchKarelianSuggestions(
    String query, {
    int maxDistance = 2,
    int limit = 20,
  }) async {
    final folded = prepareKrlFuzzyQuery(query.trim());
    if (folded.length < 2) return const [];

    final forms = await _cachedWordForms();
    final qLen = folded.length;
    final hits = <({String word, int dist, int len})>[];
    for (final raw in forms) {
      final w = raw.toLowerCase();
      final len = w.length;
      if ((len - qLen).abs() > maxDistance) continue;
      final d = levenshtein(folded, w);
      if (d == 0 || d > maxDistance) continue;
      hits.add((word: raw, dist: d, len: len));
    }
    hits.sort((a, b) {
      final c = a.dist.compareTo(b.dist);
      if (c != 0) return c;
      final l = a.len.compareTo(b.len);
      if (l != 0) return l;
      return a.word.toLowerCase().compareTo(b.word.toLowerCase());
    });
    final seen = <String>{};
    final out = <String>[];
    for (final h in hits) {
      final key = h.word.toLowerCase();
      if (!seen.add(key)) continue;
      out.add(h.word);
      if (out.length >= limit) break;
    }
    return out;
  }

  Future<List<String>> _cachedWordForms() async {
    if (_wordForms != null) return _wordForms!;
    final rows = await _db.rawQuery(
      "SELECT DISTINCT word FROM words WHERE word IS NOT NULL AND word != ''",
    );
    _wordForms = [
      for (final r in rows) r["word"] as String,
    ];
    return _wordForms!;
  }

  /// Russian search as on the early web index: prefix in translations
  /// (`кош` → кошка, кошелёк…), ё→е like the translate index.
  Future<List<ArticleSummary>> searchRussian(String query) async {
    final q = query.trim().replaceAll("ё", "е").replaceAll("Ё", "Е");
    if (q.isEmpty) return const [];
    final pattern = q.endsWith("%") ? q : "$q%";
    final rows = await _db.rawQuery(
      """
      SELECT DISTINCT a.id, a.word, a.word_normalized
      FROM translations t
      JOIN articles a ON a.id = t.article_id
      WHERE t.rus_word LIKE ? COLLATE NOCASE
      ORDER BY a.sort_key ASC, a.id ASC
      LIMIT 200
      """,
      [pattern],
    );
    return _enrich(_mapSummaries(rows));
  }

  /// Tag.tag values for types 1–4 (website italic пометы).
  Future<Set<String>> italicTagValues() async {
    if (_italicTagValues != null) return _italicTagValues!;
    final rows = await _db.query(
      "tags",
      columns: ["tag"],
      where: "type IN (1, 2, 3, 4) AND tag IS NOT NULL AND tag != ''",
    );
    _italicTagValues = {
      for (final r in rows) r["tag"] as String,
    };
    return _italicTagValues!;
  }





  /// Facets from an explicit article-id set (current search hits).
  ///
  /// Prefer this over re-running LIKE on device — 200 ids stay cheap.
  ///
  /// [optionsByType] lists every mark present on the primary hit set.
  /// [enabledTagIds] is recomputed from other selected axes so impossible
  /// AND combinations are visible but disabled in the sheet.
  Future<TagFacets> tagFacetsForArticleIds(
    List<int> baseIds, {
    List<int> selectedTagIds = const [],
    bool phrase = false,
  }) async {
    if (baseIds.isEmpty) {
      return const TagFacets(
        optionsByType: {},
        enabledTagIds: {},
        showPhrase: false,
        phraseEnabled: false,
      );
    }

    final typeById = await _tagTypesById(selectedTagIds);
    final rows = await _tagRowsForArticles(baseIds);
    final byArticle = <int, List<_TagRow>>{};
    for (final row in rows) {
      byArticle.putIfAbsent(row.articleId, () => []).add(row);
    }

    Set<int> applyFilters(Set<int> ids, List<int> tagIds, bool wantPhrase) {
      var out = Set<int>.from(ids);
      for (final tagId in tagIds) {
        out = {
          for (final id in out)
            if ((byArticle[id] ?? const []).any((t) => t.tagId == tagId)) id,
        };
      }
      if (wantPhrase) {
        out = {
          for (final id in out)
            if ((byArticle[id] ?? const []).any((t) => t.type == 5)) id,
        };
      }
      return out;
    }

    List<DictTag> tagsOfTypeOn(Set<int> articleIds, int type) {
      final seen = <int>{};
      final tags = <DictTag>[];
      for (final articleId in articleIds) {
        for (final row in byArticle[articleId] ?? const <_TagRow>[]) {
          if (row.type != type) continue;
          if (type == 2 && row.level != 0) continue;
          if (!seen.add(row.tagId)) continue;
          tags.add(
            DictTag(
              id: row.tagId,
              tag: row.tag,
              name: row.name,
              type: row.type,
              level: row.level,
              sorting: row.sorting,
            ),
          );
        }
      }
      tags.sort(compareDictTags);
      return tags;
    }

    final baseSet = baseIds.toSet();
    final primary = applyFilters(baseSet, const [], false);
    final optionsByType = <int, List<DictTag>>{};
    final enabledTagIds = <int>{};

    for (final type in krlTagGroupOrder) {
      final allOfType = tagsOfTypeOn(primary, type);
      int? selectedInGroup;
      for (final id in selectedTagIds) {
        if (typeById[id] == type) {
          selectedInGroup = id;
          break;
        }
      }
      if (selectedInGroup != null &&
          !allOfType.any((t) => t.id == selectedInGroup)) {
        final selectedTag = await _dictTagById(selectedInGroup);
        if (selectedTag != null) allOfType.insert(0, selectedTag);
      }
      if (allOfType.isEmpty) continue;
      optionsByType[type] = allOfType;

      // Applicable = co-occurs with other axes (+ phrase) on primary hits.
      final others = [
        for (final id in selectedTagIds)
          if (typeById[id] != type) id,
      ];
      final reachable = applyFilters(baseSet, others, phrase);
      for (final t in tagsOfTypeOn(reachable, type)) {
        enabledTagIds.add(t.id);
      }
      // Always keep the active chip tappable (toggle off).
      if (selectedInGroup != null) {
        enabledTagIds.add(selectedInGroup);
      }
    }

    final withPhrasePrimary = applyFilters(baseSet, const [], true);
    final withoutPhrasePrimary = {
      for (final id in primary)
        if (!(byArticle[id] ?? const []).any((t) => t.type == 5)) id,
    };
    final showPhrase =
        phrase || (withPhrasePrimary.isNotEmpty && withoutPhrasePrimary.isNotEmpty);

    final withPhraseNow = applyFilters(baseSet, selectedTagIds, true);
    final phraseEnabled = phrase || withPhraseNow.isNotEmpty;

    return TagFacets(
      optionsByType: optionsByType,
      enabledTagIds: enabledTagIds,
      showPhrase: showPhrase,
      phraseEnabled: phraseEnabled,
    );
  }

  Future<List<_TagRow>> _tagRowsForArticles(List<int> articleIds) async {
    if (articleIds.isEmpty) return const [];
    final out = <_TagRow>[];
    const chunk = 400;
    for (var i = 0; i < articleIds.length; i += chunk) {
      final slice = articleIds.sublist(
        i,
        i + chunk > articleIds.length ? articleIds.length : i + chunk,
      );
      final placeholders = List.filled(slice.length, "?").join(",");
      final rows = await _db.rawQuery(
        """
        SELECT at.article_id AS article_id,
               t.id AS tag_id, t.tag AS tag, t.name AS name,
               t.type AS type, t.level AS level, t.sorting AS sorting
        FROM article_tags at
        JOIN tags t ON t.id = at.tag_id
        WHERE at.article_id IN ($placeholders)
        """,
        slice,
      );
      for (final r in rows) {
        out.add(
          _TagRow(
            articleId: _asInt(r["article_id"])!,
            tagId: _asInt(r["tag_id"])!,
            tag: r["tag"] as String? ?? "",
            name: r["name"] as String? ?? "",
            type: _asInt(r["type"]) ?? 0,
            level: _asInt(r["level"]) ?? 0,
            sorting: _asInt(r["sorting"]),
          ),
        );
      }
    }
    return out;
  }

  Future<Map<int, int>> _tagTypesById(List<int> ids) async {
    if (ids.isEmpty) return {};
    final placeholders = List.filled(ids.length, "?").join(",");
    final rows = await _db.rawQuery(
      "SELECT id, type FROM tags WHERE id IN ($placeholders)",
      ids,
    );
    return {
      for (final r in rows) r["id"] as int: r["type"] as int,
    };
  }

  Future<DictTag?> _dictTagById(int id) async {
    final rows = await _db.query(
      "tags",
      columns: ["id", "tag", "name", "type", "level", "sorting"],
      where: "id = ?",
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return dictTagFromRow(rows.first);
  }

  static int? _asInt(Object? v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse("$v");
  }

  void _appendTagFilters(
    StringBuffer sql,
    List<Object?> args, {
    required List<int> tagIds,
    required bool phrase,
    required String alias,
  }) {
    for (final tagId in tagIds) {
      sql.write(
        """
      AND EXISTS (
        SELECT 1 FROM article_tags at
        WHERE at.article_id = $alias.id AND at.tag_id = ?
      )
      """,
      );
      args.add(tagId);
    }
    if (phrase) {
      sql.write(
        """
      AND EXISTS (
        SELECT 1
        FROM article_tags at
        JOIN tags t ON t.id = at.tag_id
        WHERE at.article_id = $alias.id AND t.type = 5
      )
      """,
      );
    }
  }

  List<ArticleSummary> _mapSummaries(List<Map<String, Object?>> rows) {
    return rows
        .map(
          (r) => ArticleSummary(
            id: r["id"] as int,
            word: r["word"] as String,
            wordNormalized: r["word_normalized"] as String?,
          ),
        )
        .toList();
  }

  /// Batch-load POS, glosses, and outbound see/cf/deriv for list previews.
  Future<List<ArticleSummary>> _enrich(List<ArticleSummary> base) async {
    if (base.isEmpty) return base;
    final ids = [for (final a in base) a.id];
    final placeholders = List.filled(ids.length, "?").join(",");

    final transRows = await _db.rawQuery(
      """
      SELECT article_id, rus_word
      FROM translations
      WHERE article_id IN ($placeholders)
        AND hide_from_register = 0
      ORDER BY id
      """,
      ids,
    );
    final posRows = await _db.rawQuery(
      """
      SELECT at.article_id AS article_id, t.tag AS tag
      FROM article_tags at
      JOIN tags t ON t.id = at.tag_id
      WHERE at.article_id IN ($placeholders) AND t.type = 2
      ORDER BY t.level ASC, t.sorting ASC, t.id ASC
      """,
      ids,
    );
    final linkRows = await _db.rawQuery(
      """
      SELECT l.from_article_id AS from_id, l.to_article_id AS to_id,
             l.kind AS kind, a.word AS word, a.word_normalized AS word_normalized
      FROM links l
      JOIN articles a ON a.id = l.to_article_id
      WHERE l.from_article_id IN ($placeholders)
      ORDER BY l.id
      """,
      ids,
    );

    final transMap = <int, List<String>>{};
    for (final r in transRows) {
      final id = r["article_id"] as int;
      final word = (r["rus_word"] as String?)?.trim() ?? "";
      if (word.isEmpty) continue;
      (transMap[id] ??= <String>[]).add(word);
    }

    final posMap = <int, List<String>>{};
    for (final r in posRows) {
      final id = r["article_id"] as int;
      final tag = (r["tag"] as String?)?.trim() ?? "";
      if (tag.isEmpty) continue;
      final list = posMap[id] ??= <String>[];
      if (!list.contains(tag)) list.add(tag);
    }

    final seeMap = <int, List<String>>{};
    final derivMap = <int, List<String>>{};
    final inheritFrom = <int, int>{}; // fromId → first see/cf toId
    for (final r in linkRows) {
      final fromId = r["from_id"] as int;
      final toId = r["to_id"] as int;
      final kind = r["kind"] as String? ?? "see";
      final display = displayHeadword(
        r["word"] as String? ?? "",
        r["word_normalized"] as String?,
      );
      if (display.isEmpty) continue;
      if (kind == "deriv") {
        (derivMap[fromId] ??= <String>[]).add(display);
      } else if (kind == "see" || kind == "cf") {
        (seeMap[fromId] ??= <String>[]).add(display);
        inheritFrom.putIfAbsent(fromId, () => toId);
      }
    }

    final needInherit = <int>[];
    for (final a in base) {
      final own = transMap[a.id];
      if (own != null && own.isNotEmpty) continue;
      final toId = inheritFrom[a.id];
      if (toId != null) needInherit.add(toId);
    }

    final inheritedMap = <int, List<String>>{};
    if (needInherit.isNotEmpty) {
      final uniq = needInherit.toSet().toList();
      final ph = List.filled(uniq.length, "?").join(",");
      final inhRows = await _db.rawQuery(
        """
        SELECT article_id, rus_word
        FROM translations
        WHERE article_id IN ($ph)
          AND hide_from_register = 0
        ORDER BY id
        """,
        uniq,
      );
      for (final r in inhRows) {
        final id = r["article_id"] as int;
        final word = (r["rus_word"] as String?)?.trim() ?? "";
        if (word.isEmpty) continue;
        (inheritedMap[id] ??= <String>[]).add(word);
      }
    }

    return [
      for (final a in base)
        ArticleSummary(
          id: a.id,
          word: a.word,
          wordNormalized: a.wordNormalized,
          posTags: posMap[a.id] ?? const [],
          translations: transMap[a.id] ?? const [],
          seeTargets: seeMap[a.id] ?? const [],
          derivTargets: derivMap[a.id] ?? const [],
          inheritedTranslations: () {
            final own = transMap[a.id];
            if (own != null && own.isNotEmpty) return const <String>[];
            final toId = inheritFrom[a.id];
            if (toId == null) return const <String>[];
            return inheritedMap[toId] ?? const <String>[];
          }(),
        ),
    ];
  }
}


class _TagRow {
  const _TagRow({
    required this.articleId,
    required this.tagId,
    required this.tag,
    required this.name,
    required this.type,
    required this.level,
    this.sorting,
  });

  final int articleId;
  final int tagId;
  final String tag;
  final String name;
  final int type;
  final int level;
  final int? sorting;
}
