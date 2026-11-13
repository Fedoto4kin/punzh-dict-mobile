import "dart:convert";
import "dart:io";

import "package:flutter/foundation.dart";
import "package:path/path.dart" as p;
import "package:path_provider/path_provider.dart";

const String bookmarksFileName = "bookmarks.json";

/// Cap on stored bookmarks (newest kept if a legacy file exceeds this).
const int maxBookmarks = 100;

enum BookmarkToggleResult { added, removed, limitReached }

class BookmarkEntry {
  const BookmarkEntry({required this.articleId, required this.addedAt});

  final int articleId;
  final int addedAt;

  Map<String, Object> toJson() => {
        "article_id": articleId,
        "added_at": addedAt,
      };

  static BookmarkEntry fromJson(Map<String, Object?> json) {
    final id = json["article_id"];
    final at = json["added_at"];
    if (id is! num || at is! num) {
      throw FormatException("Invalid bookmark entry: $json");
    }
    return BookmarkEntry(articleId: id.toInt(), addedAt: at.toInt());
  }
}

/// Local bookmarks outside the dictionary pack (survives DB updates).
class BookmarkStore extends ChangeNotifier {
  BookmarkStore._(this._file, List<BookmarkEntry> entries)
      : _entries = List<BookmarkEntry>.from(entries);

  final File _file;
  final List<BookmarkEntry> _entries;

  /// Newest first.
  List<int> get ids => [for (final e in _entries) e.articleId];

  List<BookmarkEntry> get entries => List.unmodifiable(_entries);

  int get length => _entries.length;

  bool get isAtLimit => _entries.length >= maxBookmarks;

  bool isBookmarked(int articleId) =>
      _entries.any((e) => e.articleId == articleId);

  static Future<File> defaultFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, bookmarksFileName));
  }

  static Future<BookmarkStore> open({File? file}) async {
    final f = file ?? await defaultFile();
    return BookmarkStore._(f, await _readFile(f));
  }

  static Future<List<BookmarkEntry>> _readFile(File file) async {
    if (!await file.exists()) return const [];
    try {
      final raw = jsonDecode(await file.readAsString());
      if (raw is! List) return const [];
      final out = <BookmarkEntry>[];
      final seen = <int>{};
      for (final item in raw) {
        if (item is! Map) continue;
        final entry = BookmarkEntry.fromJson(
          item.map((k, v) => MapEntry("$k", v)),
        );
        if (!seen.add(entry.articleId)) continue;
        out.add(entry);
      }
      out.sort((a, b) => b.addedAt.compareTo(a.addedAt));
      if (out.length > maxBookmarks) {
        return out.sublist(0, maxBookmarks);
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  Future<void> _persist() async {
    final dir = _file.parent;
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final staging = File("${_file.path}.new");
    final payload = jsonEncode([for (final e in _entries) e.toJson()]);
    await staging.writeAsString(payload, flush: true);
    if (await _file.exists()) {
      await _file.delete();
    }
    await staging.rename(_file.path);
  }

  /// Add / remove; at [maxBookmarks] a new add is refused.
  Future<BookmarkToggleResult> toggle(int articleId, {int? nowMs}) async {
    if (isBookmarked(articleId)) {
      await remove(articleId);
      return BookmarkToggleResult.removed;
    }
    final ok = await add(articleId, nowMs: nowMs);
    return ok ? BookmarkToggleResult.added : BookmarkToggleResult.limitReached;
  }

  /// Returns `false` if already present or [maxBookmarks] reached.
  Future<bool> add(int articleId, {int? nowMs}) async {
    if (isBookmarked(articleId)) return false;
    if (isAtLimit) return false;
    final at = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    _entries.insert(0, BookmarkEntry(articleId: articleId, addedAt: at));
    await _persist();
    notifyListeners();
    return true;
  }

  Future<void> remove(int articleId) async {
    final before = _entries.length;
    _entries.removeWhere((e) => e.articleId == articleId);
    if (_entries.length == before) return;
    await _persist();
    notifyListeners();
  }
}
