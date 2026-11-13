import "package:material_ui/material_ui.dart";

import "../article_links.dart";
import "../data/bookmark_store.dart";
import "bookmark_feedback.dart";
import "../data/dictionary_repository.dart";
import "../theme.dart";
import "article_body.dart";

/// Article panel that fills the list area under the alphabet strip.
/// Drag down (handle or content at top) to dismiss, like a modal sheet.
class ArticleSheetPanel extends StatefulWidget {
  const ArticleSheetPanel({
    super.key,
    required this.repository,
    required this.bookmarks,
    required this.articleId,
    required this.title,
    required this.onClose,
    this.onPunzhUrl,
  });

  final DictionaryRepository repository;
  final BookmarkStore bookmarks;
  final int articleId;
  final String title;
  final VoidCallback onClose;
  final Future<bool> Function(PunzhUrl url)? onPunzhUrl;

  @override
  State<ArticleSheetPanel> createState() => _ArticleSheetPanelState();
}

class _ArticleSheetPanelState extends State<ArticleSheetPanel> {
  late Future<({ArticleDetail? article, Set<String> tags})> _future = _load();
  bool _closing = false;

  @override
  void didUpdateWidget(covariant ArticleSheetPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.articleId != widget.articleId) {
      _closing = false;
      _future = _load();
    }
  }

  Future<({ArticleDetail? article, Set<String> tags})> _load() async {
    final article = await widget.repository.articleById(widget.articleId);
    final tags = await widget.repository.italicTagValues();
    return (article: article, tags: tags);
  }

  bool _onSheetNotification(DraggableScrollableNotification notification) {
    if (!_closing && notification.extent <= 0.12) {
      _closing = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onClose();
      });
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return NotificationListener<DraggableScrollableNotification>(
      onNotification: _onSheetNotification,
      child: DraggableScrollableSheet(
        expand: true,
        initialChildSize: 1,
        minChildSize: 0,
        maxChildSize: 1,
        snap: true,
        snapSizes: const [1],
        shouldCloseOnMinExtent: false,
        builder: (context, scrollController) {
          return Material(
            elevation: 6,
            color: Colors.white,
            child: FutureBuilder<({ArticleDetail? article, Set<String> tags})>(
              future: _future,
              builder: (context, snapshot) {
                final header = <Widget>[
                  const SizedBox(height: 8),
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFADB5BD),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 4, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.title,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        ListenableBuilder(
                          listenable: widget.bookmarks,
                          builder: (context, _) {
                            final on = widget.bookmarks.isBookmarked(
                              widget.articleId,
                            );
                            return IconButton(
                              tooltip: on
                                  ? "Убрать из закладок"
                                  : "В закладки",
                              icon: Icon(
                                on
                                    ? Icons.bookmark
                                    : Icons.bookmark_border,
                                color: on ? PunzhColors.brand : null,
                              ),
                              onPressed: () async {
                                final result = await widget.bookmarks.toggle(
                                  widget.articleId,
                                );
                                if (!context.mounted) return;
                                showBookmarkSnackBar(
                                  context,
                                  result: result,
                                );
                              },
                            );
                          },
                        ),
                        IconButton(
                          tooltip: "Закрыть",
                          icon: const Icon(Icons.close),
                          onPressed: widget.onClose,
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                ];

                if (snapshot.connectionState != ConnectionState.done) {
                  return ListView(
                    controller: scrollController,
                    children: [
                      ...header,
                      const Padding(
                        padding: EdgeInsets.all(48),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ],
                  );
                }
                if (snapshot.hasError) {
                  return ListView(
                    controller: scrollController,
                    children: [
                      ...header,
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text("${snapshot.error}"),
                      ),
                    ],
                  );
                }
                final data = snapshot.data;
                final article = data?.article;
                if (article == null) {
                  return ListView(
                    controller: scrollController,
                    children: [
                      ...header,
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text("Статья не найдена"),
                      ),
                    ],
                  );
                }
                return ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.only(bottom: 24),
                  children: [
                    ...header,
                    ArticleBody(
                      article: article,
                      italicTagValues: data!.tags,
                      onPunzhUrl: widget.onPunzhUrl,
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }
}
