import "dart:convert";
import "dart:io";

import "package:flutter_test/flutter_test.dart";
import "package:punzh_dict/data/bookmark_store.dart";

void main() {
  late Directory tmp;
  late File file;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp("punzh_bookmarks_");
    file = File("${tmp.path}/bookmarks.json");
  });

  tearDown(() async {
    if (await tmp.exists()) {
      await tmp.delete(recursive: true);
    }
  });

  test("toggle add/remove and newest-first order", () async {
    final store = await BookmarkStore.open(file: file);
    expect(await store.toggle(10, nowMs: 100), BookmarkToggleResult.added);
    expect(await store.toggle(20, nowMs: 200), BookmarkToggleResult.added);
    expect(await store.toggle(30, nowMs: 300), BookmarkToggleResult.added);
    expect(store.ids, [30, 20, 10]);
    expect(store.isBookmarked(20), isTrue);

    expect(await store.toggle(20, nowMs: 400), BookmarkToggleResult.removed);
    expect(store.ids, [30, 10]);
    expect(store.isBookmarked(20), isFalse);
  });

  test("persist round-trip", () async {
    final store = await BookmarkStore.open(file: file);
    expect(await store.add(7, nowMs: 50), isTrue);
    expect(await store.add(8, nowMs: 60), isTrue);

    final reopened = await BookmarkStore.open(file: file);
    expect(reopened.ids, [8, 7]);
  });

  test("duplicate add is ignored", () async {
    final store = await BookmarkStore.open(file: file);
    expect(await store.add(1, nowMs: 1), isTrue);
    expect(await store.add(1, nowMs: 2), isFalse);
    expect(store.ids, [1]);
  });

  test("refuses add at maxBookmarks", () async {
    final store = await BookmarkStore.open(file: file);
    for (var i = 0; i < maxBookmarks; i++) {
      expect(await store.add(i, nowMs: i), isTrue);
    }
    expect(store.length, maxBookmarks);
    expect(store.isAtLimit, isTrue);
    expect(await store.add(9999, nowMs: 9999), isFalse);
    expect(
      await store.toggle(9999, nowMs: 10000),
      BookmarkToggleResult.limitReached,
    );
    expect(store.ids.contains(9999), isFalse);
    expect(store.ids.first, maxBookmarks - 1);

    expect(await store.toggle(0, nowMs: 10001), BookmarkToggleResult.removed);
    expect(await store.add(9999, nowMs: 10002), isTrue);
    expect(store.ids.first, 9999);
  });

  test("open trims legacy file above maxBookmarks", () async {
    final raw = [
      for (var i = 0; i < maxBookmarks + 25; i++)
        {"article_id": i, "added_at": i},
    ];
    await file.writeAsString(jsonEncode(raw));
    final store = await BookmarkStore.open(file: file);
    expect(store.length, maxBookmarks);
    expect(store.ids.first, maxBookmarks + 24);
    expect(store.ids.last, 25);
  });
}
