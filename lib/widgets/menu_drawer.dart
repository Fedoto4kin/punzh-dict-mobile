import "package:flutter/services.dart";
import "package:flutter_svg/flutter_svg.dart";
import "package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart";
import "package:material_ui/material_ui.dart";
import "package:package_info_plus/package_info_plus.dart";

import "../content/about_copy.dart";
import "../data/bookmark_store.dart";
import "bookmark_feedback.dart";
import "../data/dictionary_repository.dart";
import "../data/db_updater.dart";
import "../data/dictionary_session.dart";
import "../data/pack_manifest.dart";
import "../open_external_url.dart";
import "../theme.dart";

enum _DrawerPane {
  menu,
  bookmarks,
  searchHelp,
  aboutDictionary,
  aboutApp,
  updateDb,
}

/// Left drawer: brand + about / DB-update panes in-place (no route push).
const String bookmarksMenuLabel = "Закладки";

class MenuDrawer extends StatefulWidget {
  const MenuDrawer({
    super.key,
    required this.session,
    required this.bookmarks,
    required this.repository,
    required this.onOpenArticle,
  });

  final DictionarySession session;
  final BookmarkStore bookmarks;
  final DictionaryRepository repository;
  final void Function(ArticleSummary summary) onOpenArticle;

  @override
  State<MenuDrawer> createState() => _MenuDrawerState();
}

class _MenuDrawerState extends State<MenuDrawer> {
  _DrawerPane _pane = _DrawerPane.menu;
  Animation<double>? _drawerAnimation;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final anim = ModalRoute.of(context)?.animation;
    if (!identical(anim, _drawerAnimation)) {
      _drawerAnimation?.removeStatusListener(_onDrawerAnim);
      _drawerAnimation = anim;
      _drawerAnimation?.addStatusListener(_onDrawerAnim);
    }
  }

  void _onDrawerAnim(AnimationStatus status) {
    if (status == AnimationStatus.dismissed && _pane != _DrawerPane.menu) {
      setState(() => _pane = _DrawerPane.menu);
    }
  }

  @override
  void dispose() {
    _drawerAnimation?.removeStatusListener(_onDrawerAnim);
    super.dispose();
  }

  void _goMenu() => setState(() => _pane = _DrawerPane.menu);

  @override
  Widget build(BuildContext context) {
    // Keep dark status icons + same header height on every pane (no flash/jump).
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: punzhStatusOnDark,
      child: Drawer(
        backgroundColor: Colors.white,
        child: SafeArea(
          top: false,
          child: PopScope(
            canPop: _pane == _DrawerPane.menu,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) _goMenu();
            },
            child: switch (_pane) {
              _DrawerPane.menu => _MenuPane(
                  onBookmarks: () =>
                      setState(() => _pane = _DrawerPane.bookmarks),
                  onSearchHelp: () =>
                      setState(() => _pane = _DrawerPane.searchHelp),
                  onAboutDictionary: () =>
                      setState(() => _pane = _DrawerPane.aboutDictionary),
                  onAboutApp: () =>
                      setState(() => _pane = _DrawerPane.aboutApp),
                  onUpdateDb: () =>
                      setState(() => _pane = _DrawerPane.updateDb),
                ),
              _DrawerPane.bookmarks => _BookmarksPane(
                  bookmarks: widget.bookmarks,
                  repository: widget.repository,
                  onBack: _goMenu,
                  onOpenArticle: (summary) {
                    FocusManager.instance.primaryFocus?.unfocus();
                    Navigator.of(context).pop();
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      widget.onOpenArticle(summary);
                    });
                  },
                ),
              _DrawerPane.searchHelp => _AboutPane(
                  title: searchHelpTitle,
                  onBack: _goMenu,
                  child: const _AboutHtml(searchHelpBody),
                ),
              _DrawerPane.aboutDictionary => _AboutPane(
                  title: aboutDictionaryTitle,
                  onBack: _goMenu,
                  child: const _AboutHtml(aboutDictionaryBody),
                ),
              _DrawerPane.aboutApp => _AboutPane(
                  title: aboutAppTitle,
                  onBack: _goMenu,
                  child: FutureBuilder<PackageInfo>(
                    future: PackageInfo.fromPlatform(),
                    builder: (context, snapshot) {
                      final version = snapshot.data?.version ?? "…";
                      final theme = Theme.of(context);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Версия $version",
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: PunzhColors.brandDark,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const _AboutHtml(aboutAppBody),
                        ],
                      );
                    },
                  ),
                ),
              _DrawerPane.updateDb => _AboutPane(
                  title: updateDbPaneTitle,
                  onBack: _goMenu,
                  child: _UpdateDbPane(session: widget.session),
                ),
            },
          ),
        ),
      ),
    );
  }
}

/// Shared dark drawer header (same padding/colors on every pane).
class _DrawerTopBar extends StatelessWidget {
  const _DrawerTopBar({required this.child});

  static const double leadingSize = 44;
  static const double padV = 16;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    return Material(
      color: PunzhColors.navbar,
      child: Padding(
        padding: EdgeInsets.fromLTRB(8, topInset + padV, 16, padV),
        child: child,
      ),
    );
  }
}

class _MenuPane extends StatelessWidget {
  const _MenuPane({
    required this.onBookmarks,
    required this.onSearchHelp,
    required this.onAboutDictionary,
    required this.onAboutApp,
    required this.onUpdateDb,
  });

  final VoidCallback onBookmarks;
  final VoidCallback onSearchHelp;
  final VoidCallback onAboutDictionary;
  final VoidCallback onAboutApp;
  final VoidCallback onUpdateDb;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const menuIconColor = PunzhColors.navbar;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DrawerTopBar(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: _DrawerTopBar.leadingSize,
                height: _DrawerTopBar.leadingSize,
                child: SvgPicture.asset(
                  "assets/images/logo.svg",
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Словарь карельского языка",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                    ),
                    Text(
                      "тверские говоры",
                      style: TextStyle(
                        color: Color(0xFFADB5BD),
                        fontSize: 13,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: IconTheme(
            data: const IconThemeData(color: menuIconColor),
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                ListTile(
                  leading: const Icon(Icons.bookmark_outline),
                  title: const Text(bookmarksMenuLabel),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: onBookmarks,
                ),
                ListTile(
                  leading: const Icon(Icons.help_outline),
                  title: const Text(searchHelpTitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: onSearchHelp,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.menu_book_outlined),
                  title: const Text(aboutDictionaryTitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: onAboutDictionary,
                ),
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text(aboutAppTitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: onAboutApp,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.cloud_download_outlined),
                  title: const Text(updateDbMenuLabel),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: onUpdateDb,
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Text(
            rightsHolderLine,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF6C757D),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _UpdateDbPane extends StatefulWidget {
  const _UpdateDbPane({required this.session});

  final DictionarySession session;

  @override
  State<_UpdateDbPane> createState() => _UpdateDbPaneState();
}

class _UpdateDbPaneState extends State<_UpdateDbPane> {
  late final DbUpdater _updater = DbUpdater(session: widget.session);

  String? _localVersion;
  String? _localBuiltAt;
  UpdateCheckResult? _check;
  PackManifest? _readyManifest;
  String? _status;
  String? _error;
  bool _busy = false;
  double? _progress;

  @override
  void initState() {
    super.initState();
    _loadLocal();
  }

  Future<void> _loadLocal() async {
    final meta = await widget.session.localMeta();
    if (!mounted) return;
    setState(() {
      _localVersion = meta.dataVersion;
      _localBuiltAt = meta.builtAt;
    });
  }

  Future<void> _checkForUpdate() async {
    setState(() {
      _busy = true;
      _error = null;
      _status = "Проверка…";
      _progress = null;
      _check = null;
      _readyManifest = null;
    });
    try {
      final info = await PackageInfo.fromPlatform();
      final result = await _updater.check(appVersion: info.version);
      if (!mounted) return;
      setState(() {
        _check = result;
        _status = result.message;
        _busy = false;
        if (result.kind == UpdateCheckKind.available) {
          _readyManifest = result.manifest;
          _status = null;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = looksLikeConnectivityFailure(e) ? noInternetMessage : "$e";
        _status = null;
      });
    }
  }

  Future<void> _download() async {
    final manifest = _readyManifest;
    if (manifest == null) return;
    setState(() {
      _busy = true;
      _error = null;
      _status = "Скачивание…";
      _progress = 0;
    });
    try {
      await _updater.downloadAndApply(
        manifest,
        onProgress: (p) {
          if (!mounted) return;
          setState(() {
            _progress = p.fraction;
            final mb = (p.received / (1024 * 1024)).toStringAsFixed(1);
            final total = p.total > 0
                ? " / ${(p.total / (1024 * 1024)).toStringAsFixed(1)} МБ"
                : " МБ";
            _status = "Скачивание… $mb$total";
          });
        },
      );
      if (!mounted) return;
      final meta = await widget.session.localMeta();
      setState(() {
        _busy = false;
        _progress = 1;
        _readyManifest = null;
        _localVersion = meta.dataVersion;
        _localBuiltAt = meta.builtAt;
        _status = "Словарь обновлён";
        _check = UpdateCheckResult(
          kind: UpdateCheckKind.upToDate,
          localDataVersion: meta.dataVersion,
          message: _status,
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _progress = null;
        _error = looksLikeConnectivityFailure(e) ? noInternetMessage : "$e";
        _status = null;
      });
    }
  }

  String _formatBytes(int n) {
    if (n < 1024 * 1024) {
      return "${(n / 1024).toStringAsFixed(0)} КБ";
    }
    return "${(n / (1024 * 1024)).toStringAsFixed(1)} МБ";
  }

  /// ISO `built_at` → calendar date only (no time).
  String _formatBuiltDate(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed != null) {
      final d = parsed.toLocal();
      final y = d.year.toString().padLeft(4, "0");
      final m = d.month.toString().padLeft(2, "0");
      final day = d.day.toString().padLeft(2, "0");
      return "$y-$m-$day";
    }
    if (raw.length >= 10) return raw.substring(0, 10);
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final body = theme.textTheme.bodyLarge?.copyWith(
      height: 1.45,
      color: PunzhColors.navbar,
    );
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: const Color(0xFF6C757D),
      height: 1.35,
    );
    final manifest = _readyManifest ?? _check?.manifest;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text("На устройстве", style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(
          _localVersion == null
              ? "Версия данных: предустановленный пакет"
              : "Версия данных: $_localVersion",
          style: body,
        ),
        if (_localBuiltAt != null && _localBuiltAt!.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text("Сборка: ${_formatBuiltDate(_localBuiltAt!)}", style: muted),
        ],
        const SizedBox(height: 16),
        if (_status != null) Text(_status!, style: body),
        if (_error != null) ...[
          Text(
            _error!,
            style: body?.copyWith(color: const Color(0xFFB00020)),
          ),
        ],
        if (manifest != null &&
            _check?.kind == UpdateCheckKind.available) ...[
          const SizedBox(height: 8),
          Text("Доступно обновление", style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text("Версия данных: ${manifest.dataVersion}", style: body),
          if (manifest.builtAt.isNotEmpty)
            Text(
              "Сборка: ${_formatBuiltDate(manifest.builtAt)}",
              style: muted,
            ),
          Text("Размер: ${_formatBytes(manifest.size)}", style: muted),
        ],
        if (_progress != null) ...[
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: _progress,
            color: PunzhColors.brand,
            backgroundColor: const Color(0xFFE9ECEF),
          ),
        ],
        const SizedBox(height: 20),
        if (_readyManifest != null)
          FilledButton(
            onPressed: _busy ? null : _download,
            child: const Text("Загрузить и установить"),
          )
        else
          FilledButton(
            onPressed: _busy ? null : _checkForUpdate,
            child: Text(_busy ? "Подождите…" : "Проверить обновление"),
          ),
        const SizedBox(height: 12),
        Text(
          "Для загрузки актуальной базы словаря требуется подключение к Интернету.\n\n"
          "Обновления расширяют словарь или содержат исправления ошибок.",
          style: muted,
        ),
      ],
    );
  }
}

class _AboutHtml extends StatelessWidget {
  const _AboutHtml(this.html);

  final String html;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).textTheme.bodyLarge;
    return HtmlWidget(
      html.trim(),
      textStyle: base?.copyWith(height: 1.45, color: PunzhColors.navbar),
      onTapUrl: (url) => openExternalUrl(url),
      customStylesBuilder: (element) {
        if (element.localName == "a") {
          return {
            "color": _cssHex(PunzhColors.link),
            "text-decoration": "none",
            "font-weight": "600",
          };
        }
        if (element.localName == "p") {
          return {"margin-bottom": "0.75em"};
        }
        return null;
      },
    );
  }

  static String _cssHex(Color c) {
    final v = c.toARGB32() & 0xFFFFFF;
    return "#${v.toRadixString(16).padLeft(6, "0")}";
  }
}


class _BookmarksPane extends StatefulWidget {
  const _BookmarksPane({
    required this.bookmarks,
    required this.repository,
    required this.onBack,
    required this.onOpenArticle,
  });

  final BookmarkStore bookmarks;
  final DictionaryRepository repository;
  final VoidCallback onBack;
  final void Function(ArticleSummary summary) onOpenArticle;

  @override
  State<_BookmarksPane> createState() => _BookmarksPaneState();
}

class _BookmarksPaneState extends State<_BookmarksPane> {
  late Future<List<ArticleSummary?>> _future = _load();

  @override
  void initState() {
    super.initState();
    widget.bookmarks.addListener(_onBookmarksChanged);
  }

  @override
  void dispose() {
    widget.bookmarks.removeListener(_onBookmarksChanged);
    super.dispose();
  }

  void _onBookmarksChanged() {
    setState(() => _future = _load());
  }

  Future<List<ArticleSummary?>> _load() {
    return widget.repository.summariesByIds(widget.bookmarks.ids);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DrawerTopBar(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: _DrawerTopBar.leadingSize,
                height: _DrawerTopBar.leadingSize,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  tooltip: "Назад",
                  padding: EdgeInsets.zero,
                  onPressed: widget.onBack,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  bookmarksMenuLabel,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<ArticleSummary?>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text("${snapshot.error}"));
              }
              final rows = snapshot.data ?? const [];
              final ids = widget.bookmarks.ids;
              if (ids.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                  child: Text(
                    "Пока нет закладок.\n\n"
                    "Откройте статью и нажмите значок закладки в шапке.",
                    style: theme.textTheme.bodyLarge?.copyWith(
                      height: 1.45,
                      color: PunzhColors.navbar,
                    ),
                  ),
                );
              }
              return ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: ids.length,
                itemBuilder: (context, index) {
                  final id = ids[index];
                  final summary =
                      index < rows.length ? rows[index] : null;
                  final title = summary?.displayWord ??
                      "Статья удалена из словаря";
                  final subtitle = summary?.previewLine;
                  return Dismissible(
                    key: ValueKey("bm-$id"),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      color: const Color(0xFFB00020),
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    onDismissed: (_) async {
                      await widget.bookmarks.remove(id);
                      if (!context.mounted) return;
                      showBookmarkSnackBar(context, added: false);
                    },
                    child: ListTile(
                      title: Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: summary == null
                              ? const Color(0xFF6C757D)
                              : null,
                        ),
                      ),
                      subtitle: subtitle == null || subtitle.isEmpty
                          ? null
                          : Text(subtitle),
                      onTap: summary == null
                          ? null
                          : () => widget.onOpenArticle(summary),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AboutPane extends StatelessWidget {
  const _AboutPane({
    required this.title,
    required this.onBack,
    required this.child,
  });

  final String title;
  final VoidCallback onBack;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DrawerTopBar(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: _DrawerTopBar.leadingSize,
                height: _DrawerTopBar.leadingSize,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  tooltip: "Назад",
                  padding: EdgeInsets.zero,
                  onPressed: onBack,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: child,
          ),
        ),
      ],
    );
  }
}
