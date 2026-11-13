import "package:material_ui/material_ui.dart";

/// Non-blocking feedback for bookmark add/remove (not a modal dialog).
void showBookmarkSnackBar(BuildContext context, {required bool added}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(
      content: Text(added ? "Добавлено в закладки" : "Убрано из закладок"),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(milliseconds: 1800),
    ),
  );
}
