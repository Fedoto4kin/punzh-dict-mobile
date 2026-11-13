import "package:material_ui/material_ui.dart";

import "../data/bookmark_store.dart";

/// Non-blocking feedback for bookmark add/remove (not a modal dialog).
void showBookmarkSnackBar(
  BuildContext context, {
  required BookmarkToggleResult result,
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.clearSnackBars();
  final text = switch (result) {
    BookmarkToggleResult.added => "Добавлено в закладки",
    BookmarkToggleResult.removed => "Убрано из закладок",
    BookmarkToggleResult.limitReached =>
      "Лимит закладок: $maxBookmarks. Уберите лишние.",
  };
  messenger.showSnackBar(
    SnackBar(
      content: Text(text),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(milliseconds: 1800),
    ),
  );
}
