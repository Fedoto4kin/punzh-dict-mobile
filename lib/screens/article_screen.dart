import "package:material_ui/material_ui.dart";

import "../data/dictionary_repository.dart";
import "../widgets/article_body.dart";

/// Kept for deep links / future use; list UI opens a bottom sheet.
class ArticleScreen extends StatefulWidget {
  const ArticleScreen({
    super.key,
    required this.repository,
    required this.articleId,
  });

  final DictionaryRepository repository;
  final int articleId;

  @override
  State<ArticleScreen> createState() => _ArticleScreenState();
}

class _ArticleScreenState extends State<ArticleScreen> {
  late final Future<({ArticleDetail? article, Set<String> tags})> _future =
      _load();

  Future<({ArticleDetail? article, Set<String> tags})> _load() async {
    final article = await widget.repository.articleById(widget.articleId);
    final tags = await widget.repository.italicTagValues();
    return (article: article, tags: tags);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Статья")),
      body: FutureBuilder<({ArticleDetail? article, Set<String> tags})>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("${snapshot.error}"));
          }
          final data = snapshot.data;
          final article = data?.article;
          if (article == null) {
            return const Center(child: Text("Статья не найдена"));
          }
          return SingleChildScrollView(
            child: ArticleBody(
              article: article,
              italicTagValues: data!.tags,
            ),
          );
        },
      ),
    );
  }
}
