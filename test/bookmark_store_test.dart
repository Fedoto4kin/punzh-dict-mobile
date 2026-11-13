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
    await store.toggle(10, nowMs: 100);
    await store.toggle(20, nowMs: 200);
    await store.toggle(30, nowMs: 300);
    expect(store.ids, [30, 20, 10]);
    expect(store.isBookmarked(20), isTrue);

    await store.toggle(20, nowMs: 400);
    expect(store.ids, [30, 10]);
    expect(store.isBookmarked(20), isFalse);
  });

  test("persist round-trip", () async {
    final store = await BookmarkStore.open(file: file);
    await store.add(7, nowMs: 50);
    await store.add(8, nowMs: 60);

    final reopened = await BookmarkStore.open(file: file);
    expect(reopened.ids, [8, 7]);
  });

  test("duplicate add is ignored", () async {
    final store = await BookmarkStore.open(file: file);
    await store.add(1, nowMs: 1);
    await store.add(1, nowMs: 2);
    expect(store.ids, [1]);
  });
}
