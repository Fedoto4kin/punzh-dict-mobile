import "dart:async";

import "package:flutter_svg/flutter_svg.dart";
import "package:material_ui/material_ui.dart";

import "../article_links.dart";
import "../data/bookmark_store.dart";
import "../data/dictionary_repository.dart";
import "../data/dictionary_session.dart";
import "../data/tag_filter_state.dart";
import "../search_direction.dart";
import "../ngram.dart";
import "../schema.dart";
import "../theme.dart";
import "../widgets/article_sheet.dart";
import "../widgets/menu_drawer.dart";
import "../widgets/ngram_scrubber.dart";
import "../widgets/tag_filters_sheet.dart";

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.session,
    required this.bookmarks,
  });

  final DictionarySession session;
  final BookmarkStore bookmarks;

  DictionaryRepository get repository => session.repository;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static final List<String> _letters = [
    for (final r in krlAbc.runes) String.fromCharCode(r),
  ];

  String _letter = "A";
  final _queryController = TextEditingController();
  final _queryFocus = FocusNode();
  final _listScroll = ScrollController();
  final _abcScroll = ScrollController();
  final _pageIndex = ValueNotifier<int>(0);
  late final PageController _letterPager = PageController(
    initialPage: _letters.indexOf("A").clamp(0, _letters.length - 1),
  );
  late final List<GlobalKey> _chipKeys = [
    for (var i = 0; i < _letters.length; i++) GlobalKey(debugLabel: "abc-$i"),
  ];
  bool _ignoreLetterPageCallback = false;

  /// Bare letter index (id + word).
  List<ArticleSummary> _index = const [];
  List<LetterPage> _pages = const [];
  List<NgramAnchor> _anchors = const [];

  /// Global starts for rail highlights (same semantics as tap targets).
  /// For marks 0..n-2: first lemma matching that n-gram; last mark uses
  /// [_index.length] as a sentinel (activated only near letter end).
  List<int> _railStarts = const [];

  /// Fully enriched pages only.
  final Map<int, List<ArticleSummary>> _pageCache = {};
  final Set<int> _loadingPages = {};

  /// Concat of window pages [_windowLo.._windowHi] (all enriched).
  List<ArticleSummary> _items = const [];
  int _windowLo = 0;
  int _windowHi = -1;

  bool _loading = true;
  bool _searchMode = false;
  String? _error;
  /// Open article cards: last is visible. System back pops; close/drag clears.
  final List<ArticleSummary> _articleStack = [];

  ArticleSummary? get _opened =>
      _articleStack.isEmpty ? null : _articleStack.last;
  int _loadGen = 0;
  bool _windowBusy = false;
  bool _adjustingScroll = false;
  int? _pendingJumpPage;
  DateTime? _ignoreScrollUntil;

  /// Ignore spurious TextField onSubmitted when focus leaves for the drawer.
  DateTime? _ignoreSearchSubmitUntil;
  static const _searchSubmitCooldown = Duration(milliseconds: 600);

  final TagFilterState _filters = TagFilterState();

  /// Unfiltered KRL hit ids for the current query (facet base).
  List<int> _searchFacetBaseIds = const [];

  /// Primary hit set has 2+ marks or phrase — otherwise hide filter bar.
  bool _searchFacetsHaveChoices = false;

  /// Fuzzy KRL suggestions when exact search is empty.
  List<String> _krlSuggestions = const [];

  static const _scrubberWidth = 64.0;
  static const _minPageSize = 40;

  /// Fixed row height: seamless window slides without layout jumps.
  static const _rowExtent = 72.0;
  static const _edgeRows = 6;
  static const _railJumpCooldown = Duration(milliseconds: 400);

  /// Target page count from last measured rail height (device-dependent).
  int _railTargetPages = 12;
  double _railHeight = 0;

  static const _titleStyle = TextStyle(
    color: PunzhColors.brand,
    fontWeight: FontWeight.w600,
  );
  static const _subtitleStyle = TextStyle(
    color: Color(0xFF6C757D),
    fontSize: 13,
    height: 1.25,
  );

  bool get _showScrubber =>
      _opened == null &&
      !_loading &&
      _error == null &&
      _anchors.length >= 2;

  @override
  void initState() {
    super.initState();
    widget.session.addListener(_onDictionarySession);
    _listScroll.addListener(_onListScroll);
    unawaited(_loadFilterCatalog());
    _loadLetter();
  }

  Future<void> _loadFilterCatalog() async {
    final tags = await widget.repository.listFilterTags();
    if (!mounted) return;
    _filters.setCatalog(tags);
  }

  void _onDictionarySession() {
    if (!mounted) return;
    if (_searchMode) {
      final q = _queryController.text.trim();
      if (q.isNotEmpty) {
        unawaited(_runSearch(q));
      } else {
        unawaited(_loadLetter());
      }
    } else {
      unawaited(_loadLetter());
    }
  }

  @override
  void dispose() {
    widget.session.removeListener(_onDictionarySession);
    _filters.dispose();
    _listScroll.removeListener(_onListScroll);
    _listScroll.dispose();
    _abcScroll.dispose();
    _letterPager.dispose();
    _pageIndex.dispose();
    _queryController.dispose();
    _queryFocus.dispose();
    super.dispose();
  }

  void _scrollLetterChipIntoView(int index) {
    if (index < 0 || index >= _chipKeys.length) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = _chipKeys[index].currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.5,
        alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _syncLetterPager(int index) {
    void jump() {
      if (!_letterPager.hasClients) return;
      final page = _letterPager.page?.round() ?? _letterPager.initialPage;
      if (page == index) return;
      _ignoreLetterPageCallback = true;
      _letterPager.jumpToPage(index);
      _ignoreLetterPageCallback = false;
    }

    jump();
    // PageView is unmounted during search — sync on the next frame.
    if (!_letterPager.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) jump();
      });
    }
  }

  void _goToLetter(String letter) {
    final i = _letters.indexOf(letter);
    if (i < 0) return;
    _queryController.clear();
    final leavingSearch = _searchMode;
    final sameLetter = letter == _letter;
    setState(() {
      _letter = letter;
      _searchMode = false;
    });
    _scrollLetterChipIntoView(i);
    _syncLetterPager(i);
    // Always reload when leaving search (_items still hold hit list).
    if (!sameLetter || leavingSearch) {
      _loadLetter();
    }
  }

  void _onLetterPageChanged(int i) {
    if (_ignoreLetterPageCallback || _searchMode) return;
    if (i < 0 || i >= _letters.length) return;
    final letter = _letters[i];
    if (letter == _letter) return;
    setState(() => _letter = letter);
    _scrollLetterChipIntoView(i);
    _loadLetter();
  }

  int _pageForGlobalIndex(int globalIndex) {
    if (_pages.isEmpty) return 0;
    for (var i = 0; i < _pages.length; i++) {
      final p = _pages[i];
      if (globalIndex >= p.start && globalIndex < p.end) return i;
    }
    return _pages.length - 1;
  }

  void _rebuildRailStarts() {
    if (_pages.isEmpty || _index.isEmpty) {
      _railStarts = const [];
      return;
    }
    if (_pages.length == 1) {
      _railStarts = const [0];
      return;
    }
    final starts = <int>[];
    for (var i = 0; i < _pages.length - 1; i++) {
      var start = _anchorIndexForPage(i);
      if (starts.isNotEmpty && start < starts.last) {
        start = starts.last;
      }
      starts.add(start);
    }
    starts.add(_index.length); // last rail mark = end of letter
    _railStarts = starts;
  }

  bool _isNearLetterEnd() {
    if (!_listScroll.hasClients || _pages.isEmpty) return false;
    if (_windowHi < _pages.length - 1) return false;
    final pos = _listScroll.position;
    if (pos.maxScrollExtent <= 0) return true;
    return pos.maxScrollExtent - pos.pixels <= _rowExtent * _edgeRows;
  }

  /// Rail highlight index for the lemma at [globalIndex] (n-gram sections).
  int _railIndexForGlobalIndex(int globalIndex) {
    if (_pages.isEmpty) return 0;
    if (_pages.length == 1) return 0;
    if (_isNearLetterEnd()) return _pages.length - 1;
    if (_railStarts.isEmpty) return _pageForGlobalIndex(globalIndex);

    var active = 0;
    // Ignore the sentinel last entry when matching by index.
    for (var i = 0; i < _railStarts.length - 1; i++) {
      if (_railStarts[i] <= globalIndex) {
        active = i;
      } else {
        break;
      }
    }
    return active;
  }

  void _rebuildItems() {
    if (_windowHi < _windowLo) {
      _items = const [];
      return;
    }
    final out = <ArticleSummary>[];
    for (var p = _windowLo; p <= _windowHi; p++) {
      final chunk = _pageCache[p];
      if (chunk == null) break;
      out.addAll(chunk);
    }
    _items = out;
  }

  Future<void> _enrichPage(int page, int gen) async {
    if (page < 0 || page >= _pages.length) return;
    if (_pageCache.containsKey(page)) return;
    if (_loadingPages.contains(page)) {
      while (_loadingPages.contains(page)) {
        await Future<void>.delayed(const Duration(milliseconds: 16));
        if (!mounted || gen != _loadGen) return;
        if (_pageCache.containsKey(page)) return;
      }
      return;
    }
    _loadingPages.add(page);
    final slice = _pages[page];
    final bare = _index.sublist(slice.start, slice.end);
    try {
      // Search hits are already enriched; letter index still needs POS/glosses.
      if (_searchMode) {
        _pageCache[page] = bare;
      } else {
        final enriched = await widget.repository.enrichSummaries(bare);
        if (!mounted || gen != _loadGen) return;
        _pageCache[page] = enriched;
      }
    } finally {
      _loadingPages.remove(page);
    }
  }

  /// First letter-index row whose n-gram equals [label].
  int _firstIndexForLabel(String label) {
    if (label.isEmpty || _index.isEmpty) return 0;
    final n = label.length;
    for (var i = 0; i < _index.length; i++) {
      if (createNgram(_index[i].word, n) == label) return i;
    }
    return 0;
  }

  /// Jump/highlight target for a rail page.
  ///
  /// Prefers the first letter-wide match when it sits on this page or the
  /// previous one (e.g. "koh" words straddling a chunk boundary). If the first
  /// match is farther away, treat it as a false friend from `ü→y` folding
  /// under SQLite `y`/`ü` sort order and fall back to the chunk start
  /// (e.g. early `yl’bie…` vs later `ül’bie…` both → "ylb").
  int _anchorIndexForPage(int page) {
    if (page < 0 || page >= _pages.length) return 0;
    final chunkStart = _pages[page].start;
    if (page == _pages.length - 1) return chunkStart;
    final label = _pages[page].label;
    final global = _firstIndexForLabel(label);
    final globalPage = _pageForGlobalIndex(global);
    if (globalPage == page || globalPage == page - 1) {
      return global;
    }
    return chunkStart;
  }

  void _jumpToLocalIndex(int localIndex, {int? highlightPage}) {
    if (!_listScroll.hasClients || _items.isEmpty) return;
    final local = localIndex.clamp(0, _items.length - 1);
    final max = _listScroll.position.maxScrollExtent;
    _adjustingScroll = true;
    _listScroll.jumpTo((local * _rowExtent).clamp(0.0, max));
    _adjustingScroll = false;
    if (highlightPage != null) {
      _pageIndex.value = highlightPage;
    }
    _ignoreScrollUntil = DateTime.now().add(_railJumpCooldown);
  }

  /// Scroll so the last row of the current window sits at the bottom edge.
  void _jumpToListEnd({int? highlightPage}) {
    if (!_listScroll.hasClients || _items.isEmpty) return;
    _adjustingScroll = true;
    _listScroll.jumpTo(_listScroll.position.maxScrollExtent);
    _adjustingScroll = false;
    if (highlightPage != null) {
      _pageIndex.value = highlightPage;
    }
    _ignoreScrollUntil = DateTime.now().add(_railJumpCooldown);
  }

  Future<void> _setWindow(
    int center, {
    int? gen,
    int? jumpToGlobalIndex,
    bool jumpToListEnd = false,
    int? highlightPage,
    bool showSpinner = false,
  }) async {
    final loadGen = gen ?? _loadGen;
    if (_pages.isEmpty) return;
    if (_windowBusy) {
      if (jumpToGlobalIndex != null || jumpToListEnd) {
        _pendingJumpPage = highlightPage ?? center;
      }
      return;
    }
    _windowBusy = true;

    final lo = (center - 1).clamp(0, _pages.length - 1);
    final hi = (center + 1).clamp(0, _pages.length - 1);
    final sameWindow =
        lo == _windowLo && hi == _windowHi && _items.isNotEmpty;

    if (sameWindow && !showSpinner) {
      _pageIndex.value = highlightPage ?? center;
      if (jumpToListEnd) {
        _jumpToListEnd(highlightPage: highlightPage ?? center);
      } else if (jumpToGlobalIndex != null) {
        final local = jumpToGlobalIndex - _pages[_windowLo].start;
        _jumpToLocalIndex(local, highlightPage: highlightPage ?? center);
      }
      _windowBusy = false;
      final pending = _pendingJumpPage;
      _pendingJumpPage = null;
      if (pending != null && pending != (highlightPage ?? center)) {
        _selectPage(pending);
      }
      return;
    }

    if (showSpinner || _items.isEmpty) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      await Future.wait([
        for (var p = lo; p <= hi; p++) _enrichPage(p, loadGen),
      ]);
      if (!mounted || loadGen != _loadGen) return;

      // Drop pages outside the window after neighbours are ready.
      _pageCache.removeWhere((p, _) => p < lo || p > hi);

      final oldLo = _windowLo;
      final oldOffset = _listScroll.hasClients ? _listScroll.offset : 0.0;

      setState(() {
        _windowLo = lo;
        _windowHi = hi;
        _pageIndex.value = highlightPage ?? center;
        _rebuildItems();
        _loading = false;
        _error = null;
        _articleStack.clear();
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || loadGen != _loadGen || !_listScroll.hasClients) return;
        if (jumpToListEnd) {
          _jumpToListEnd(highlightPage: highlightPage ?? center);
        } else if (jumpToGlobalIndex != null) {
          final local = jumpToGlobalIndex - _pages[_windowLo].start;
          _jumpToLocalIndex(local, highlightPage: highlightPage ?? center);
        } else if (lo != oldLo && oldLo >= 0 && oldLo < _pages.length) {
          final deltaRows = _pages[lo].start - _pages[oldLo].start;
          final max = _listScroll.position.maxScrollExtent;
          _adjustingScroll = true;
          _listScroll.jumpTo(
            (oldOffset - deltaRows * _rowExtent).clamp(0.0, max),
          );
          _adjustingScroll = false;
        }
      });
    } catch (e) {
      if (!mounted || loadGen != _loadGen) return;
      setState(() {
        _error = "$e";
        _loading = false;
      });
    } finally {
      _windowBusy = false;
      final pending = _pendingJumpPage;
      _pendingJumpPage = null;
      if (pending != null && mounted && loadGen == _loadGen) {
        _selectPage(pending);
      }
    }
  }

  void _onListScroll() {
    if (_adjustingScroll || _windowBusy) return;
    if (_pages.isEmpty || _items.isEmpty || !_listScroll.hasClients) return;
    final until = _ignoreScrollUntil;
    if (until != null && DateTime.now().isBefore(until)) {
      return;
    }

    final localIndex = (_listScroll.offset / _rowExtent).floor().clamp(
      0,
      _items.length - 1,
    );
    final globalIndex = _pages[_windowLo].start + localIndex;
    final rail = _railIndexForGlobalIndex(globalIndex);
    if (rail != _pageIndex.value) {
      _pageIndex.value = rail;
    }

    // Enrich window still follows fixed page chunks.
    final chunkPage = _pageForGlobalIndex(globalIndex);
    final pos = _listScroll.position;
    final nearTop = pos.pixels <= _rowExtent * _edgeRows;
    final nearBottom =
        pos.maxScrollExtent - pos.pixels <= _rowExtent * _edgeRows;

    if (nearBottom &&
        _windowHi < _pages.length - 1 &&
        chunkPage >= _windowHi) {
      _ignoreScrollUntil = DateTime.now().add(_railJumpCooldown);
      unawaited(_setWindow(chunkPage));
    } else if (nearTop && _windowLo > 0 && chunkPage <= _windowLo) {
      _ignoreScrollUntil = DateTime.now().add(_railJumpCooldown);
      unawaited(_setWindow(chunkPage));
    }
  }

  int _currentGlobalIndex() {
    if (_index.isEmpty) return 0;
    if (!_listScroll.hasClients || _items.isEmpty || _windowLo < 0) return 0;
    final local = (_listScroll.offset / _rowExtent).floor().clamp(
      0,
      _items.length - 1,
    );
    return (_pages[_windowLo].start + local).clamp(0, _index.length - 1);
  }

  /// Re-split the current letter when the rail height allows more/fewer marks.
  void _applyRailHeight(double height) {
    if (height <= 0) return;
    final next = maxLetterPagesForRailHeight(height);
    final heightChanged = (height - _railHeight).abs() > 0.5;
    if (!heightChanged && next == _railTargetPages) return;
    _railHeight = height;
    if (next == _railTargetPages) return;
    _railTargetPages = next;
    if (_index.isEmpty || _loading) return;

    final global = _currentGlobalIndex();
    final pages = buildLetterPages(
      [for (final a in _index) a.word],
      targetPages: _railTargetPages,
      minPageSize: _minPageSize,
    );
    setState(() {
      _pages = pages;
      _anchors = anchorsForPages(pages);
      _rebuildRailStarts();
      _pageCache.clear();
      // Search hits are already enriched summaries — refill page cache from index.
      if (_searchMode) {
        for (var i = 0; i < pages.length; i++) {
          final slice = pages[i];
          _pageCache[i] = _index.sublist(slice.start, slice.end);
        }
      }
      _windowLo = 0;
      _windowHi = -1;
      _items = const [];
    });
    final center = _pageForGlobalIndex(global);
    final rail = _railIndexForGlobalIndex(global);
    unawaited(
      _setWindow(
        center,
        jumpToGlobalIndex: global,
        highlightPage: rail,
        showSpinner: true,
      ),
    );
  }

  void _selectPage(int page) {
    if (page < 0 || page >= _pages.length) return;

    // Last rail mark: show the end of the letter (last word at bottom).
    if (page == _pages.length - 1) {
      final lastPage = _pages.length - 1;
      unawaited(
        _setWindow(
          lastPage,
          jumpToListEnd: true,
          highlightPage: page,
          showSpinner: !_pageCache.containsKey(lastPage) && _items.isEmpty,
        ),
      );
      return;
    }

    // Other marks: see [_anchorIndexForPage] (koh straddle vs ü/y false friends).
    final global = _anchorIndexForPage(page);
    final center = _pageForGlobalIndex(global);
    unawaited(
      _setWindow(
        center,
        jumpToGlobalIndex: global,
        highlightPage: page,
        showSpinner: !_pageCache.containsKey(center) && _items.isEmpty,
      ),
    );
  }

  Future<void> _loadLetter() async {
    final gen = ++_loadGen;
    final letter = _letter;
    if (!_filters.isEmpty) {
      _filters.clear();
    }
    _searchFacetBaseIds = const [];
    _searchFacetsHaveChoices = false;
    setState(() {
      _loading = true;
      _error = null;
      _articleStack.clear();
      _searchMode = false;
      _pageCache.clear();
      _loadingPages.clear();
      _items = const [];
      _railStarts = const [];
      _windowLo = 0;
      _windowHi = -1;
      _krlSuggestions = const [];
    });
    try {
      final bare = await widget.repository.articlesByLetter(letter);
      if (!mounted || gen != _loadGen) return;
      final pages = buildLetterPages(
        [for (final a in bare) a.word],
        targetPages: _railTargetPages,
        minPageSize: _minPageSize,
      );
      setState(() {
        _index = bare;
        _pages = pages;
        _anchors = anchorsForPages(pages);
        _rebuildRailStarts();
        _pageIndex.value = 0;
      });
      await _setWindow(
        0,
        gen: gen,
        jumpToGlobalIndex: 0,
        highlightPage: 0,
        showSpinner: true,
      );
    } catch (e) {
      if (!mounted || gen != _loadGen) return;
      setState(() {
        _error = "$e";
        _loading = false;
      });
    }
  }

  Future<void> _runSearch(String raw) async {
    final until = _ignoreSearchSubmitUntil;
    if (until != null && DateTime.now().isBefore(until)) {
      return;
    }
    _queryFocus.unfocus();
    final q = raw.trim();
    if (q.isEmpty) {
      await _loadLetter();
      return;
    }
    final gen = ++_loadGen;
    setState(() {
      _loading = true;
      _error = null;
      _articleStack.clear();
      _searchMode = true;
      _index = const [];
      _pages = const [];
      _anchors = const [];
      _railStarts = const [];
      _pageCache.clear();
      _loadingPages.clear();
      _items = const [];
      _windowLo = 0;
      _windowHi = -1;
      _pageIndex.value = 0;
      _krlSuggestions = const [];
      _searchFacetsHaveChoices = false;
    });
    try {
      final direction = detectDirection(q);
      List<ArticleSummary> items;
      if (direction == SearchDirection.karelian) {
        // Always keep the unfiltered hit set for the pomety sheet, so the
        // user can switch combinations against the original query.
        final baseHits = await widget.repository.searchKarelian(q);
        if (!mounted || gen != _loadGen) return;
        _searchFacetBaseIds = [for (final a in baseHits) a.id];
        if (_searchFacetBaseIds.isEmpty) {
          _searchFacetsHaveChoices = false;
        } else {
          final facets = await widget.repository.tagFacetsForArticleIds(
            _searchFacetBaseIds,
          );
          if (!mounted || gen != _loadGen) return;
          _searchFacetsHaveChoices = facets.hasFilterChoices;
        }
        if (_filters.isEmpty) {
          items = baseHits;
        } else {
          items = await widget.repository.searchKarelian(
            q,
            tagIds: _filters.tagIds,
            phrase: _filters.phrase,
          );
        }
      } else {
        _searchFacetBaseIds = const [];
        _searchFacetsHaveChoices = false;
        items = await widget.repository.searchRussian(q);
      }
      if (!mounted || gen != _loadGen) return;
      if (items.isEmpty) {
        List<String> suggestions = const [];
        if (direction == SearchDirection.karelian) {
          suggestions =
              await widget.repository.searchKarelianSuggestions(q);
          if (!mounted || gen != _loadGen) return;
        }
        setState(() {
          _index = const [];
          _pages = const [];
          _anchors = const [];
          _railStarts = const [];
          _pageCache.clear();
          _items = const [];
          _windowLo = 0;
          _windowHi = -1;
          _loading = false;
          _pageIndex.value = 0;
          _krlSuggestions = suggestions;
        });
        return;
      }
      final pages = buildLetterPages(
        [for (final a in items) a.word],
        targetPages: _railTargetPages,
        minPageSize: _minPageSize,
      );
      setState(() {
        _index = items;
        _pages = pages;
        _anchors = anchorsForPages(pages);
        _rebuildRailStarts();
        _krlSuggestions = const [];
        _pageCache.clear();
        for (var i = 0; i < pages.length; i++) {
          final slice = pages[i];
          _pageCache[i] = items.sublist(slice.start, slice.end);
        }
        _pageIndex.value = 0;
      });
      await _setWindow(
        0,
        gen: gen,
        jumpToGlobalIndex: 0,
        highlightPage: 0,
        showSpinner: true,
      );
    } catch (e) {
      if (!mounted || gen != _loadGen) return;
      setState(() {
        _error = "$e";
        _loading = false;
      });
    }
  }

  void _openArticle(ArticleSummary item) {
    setState(() {
      _articleStack
        ..clear()
        ..add(item);
    });
  }

  /// Open from the drawer: drop search focus first so Android IME does not
  /// re-fire [TextInputAction.search] and call [_runSearch] (which clears the
  /// article stack).
  void _openArticleFromDrawer(ArticleSummary item) {
    _queryFocus.unfocus();
    _ignoreSearchSubmitUntil = DateTime.now().add(_searchSubmitCooldown);
    _openArticle(item);
  }

  /// Close the whole sheet (toolbar X / drag down).
  void _dismissArticleSheet() {
    setState(() => _articleStack.clear());
  }

  /// System back: one step in the see/cf chain, or dismiss if only one.
  void _popArticle() {
    if (_articleStack.isEmpty) return;
    setState(() => _articleStack.removeLast());
  }

  Future<void> _pushArticleById(int id) async {
    if (_articleStack.isNotEmpty && _articleStack.last.id == id) return;
    final summary = await widget.repository.articleSummaryById(id);
    if (!mounted || summary == null) return;
    if (_articleStack.isNotEmpty && _articleStack.last.id == id) return;
    setState(() => _articleStack.add(summary));
  }


  /// Tag filters after a Karelian search that had hits (facet base).
  /// Keep the control even if the current filter combo emptied the list,
  /// so the user can open the sheet and reset.
  bool get _filtersApplyHere {
    if (!_searchMode || _searchFacetBaseIds.isEmpty) return false;
    final q = _queryController.text.trim();
    if (q.isEmpty || detectDirection(q) != SearchDirection.karelian) {
      return false;
    }
    // Single shared mark → nothing to filter; keep bar only to reset.
    return _searchFacetsHaveChoices || !_filters.isEmpty;
  }

  void _applyFiltersNow() {
    if (!_filtersApplyHere) return;
    unawaited(_runSearch(_queryController.text.trim()));
  }

  Future<TagFacets> _loadFacetsForSheet(TagFilterState filters) {
    // Facets against the original (unfiltered) query hits so "Сбросить" /
    // retoggling can show all primary combinations, not the narrowed set.
    final base = _searchFacetBaseIds.isNotEmpty
        ? _searchFacetBaseIds
        : [for (final a in _index) a.id];
    return widget.repository.tagFacetsForArticleIds(
      base,
      selectedTagIds: filters.tagIds,
      phrase: filters.phrase,
    );
  }

  Future<void> _openFiltersSheet() async {
    if (!_filtersApplyHere) return;
    _queryFocus.unfocus();
    _ignoreSearchSubmitUntil = DateTime.now().add(_searchSubmitCooldown);
    await showTagFiltersSheet(
      context: context,
      filters: _filters,
      loadFacets: _loadFacetsForSheet,
    );
    if (!mounted) return;
    _applyFiltersNow();
  }

  Future<bool> _onPunzhUrl(PunzhUrl url) async {
    switch (url) {
      case PunzhArticleUrl(:final articleId):
        await _pushArticleById(articleId);
        return true;
      case PunzhSearchUrl(:final query):
        _dismissArticleSheet();
        _queryController.text = query;
        await _runSearch(query);
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      onDrawerChanged: (opened) {
        if (opened) {
          _queryFocus.unfocus();
          _ignoreSearchSubmitUntil =
              DateTime.now().add(_searchSubmitCooldown);
        }
      },
      drawer: MenuDrawer(
        session: widget.session,
        bookmarks: widget.bookmarks,
        repository: widget.repository,
        onOpenArticle: _openArticleFromDrawer,
      ),
      appBar: AppBar(
        titleSpacing: 8,
        title: Row(
          children: [
            SvgPicture.asset(
              "assets/images/logo.svg",
              height: 36,
              width: 36,
            ),
            const SizedBox(width: 10),
            const Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Словарь карельского языка",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      height: 1.15,
                    ),
                  ),
                  Text(
                    "тверские говоры",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFFADB5BD),
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: SizedBox(
              height: 48,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _queryController,
                      focusNode: _queryFocus,
                      decoration: InputDecoration(
                        hintText: "Поиск по словарю",
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _queryController,
                          builder: (context, value, _) {
                            if (value.text.isEmpty) {
                              return const SizedBox.shrink();
                            }
                            return IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _queryController.clear();
                                _loadLetter();
                              },
                            );
                          },
                        ),
                        border: const OutlineInputBorder(
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(8),
                            bottomLeft: Radius.circular(8),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(8),
                            bottomLeft: Radius.circular(8),
                          ),
                          borderSide: BorderSide(color: theme.dividerColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(8),
                            bottomLeft: Radius.circular(8),
                          ),
                          borderSide: BorderSide(
                            color: theme.colorScheme.primary,
                            width: 2,
                          ),
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                      onSubmitted: _runSearch,
                      textInputAction: TextInputAction.search,
                    ),
                  ),
                  SizedBox(
                    height: 48,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.only(
                            topRight: Radius.circular(8),
                            bottomRight: Radius.circular(8),
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      onPressed: () => _runSearch(_queryController.text),
                      child: const Text("Найти"),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView.separated(
              controller: _abcScroll,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: _letters.length,
              separatorBuilder: (_, _) => const SizedBox(width: 4),
              itemBuilder: (context, index) {
                final letter = _letters[index];
                final selected = letter == _letter && !_searchMode;
                return KeyedSubtree(
                  key: _chipKeys[index],
                  child: ChoiceChip(
                    label: Text(letter),
                    selected: selected,
                    showCheckmark: false,
                    labelStyle: TextStyle(
                      color: selected
                          ? PunzhColors.brandDark
                          : PunzhColors.navbar,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                    backgroundColor: Colors.white,
                    selectedColor: PunzhColors.brand.withValues(alpha: 0.22),
                    side: BorderSide(
                      color: selected
                          ? PunzhColors.brand
                          : const Color(0xFFADB5BD),
                    ),
                    onSelected: (_) => _goToLetter(letter),
                  ),
                );
              },
            ),
          ),
          if (_filtersApplyHere)
            SearchFilterBar(
              filters: _filters,
              onOpenFilters: _openFiltersSheet,
              onChanged: _applyFiltersNow,
            ),
          const Divider(height: 1),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final h = constraints.maxHeight;
                if (h > 0 &&
                    ((h - _railHeight).abs() > 0.5 ||
                        maxLetterPagesForRailHeight(h) != _railTargetPages)) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) _applyRailHeight(h);
                  });
                }
                return PopScope(
                  canPop: _opened == null,
                  onPopInvokedWithResult: (didPop, _) {
                    if (!didPop && _opened != null) {
                      _popArticle();
                    }
                  },
                  child: Stack(
                    children: [
                      if (_searchMode)
                        _buildSearchBody()
                      else
                        PageView.builder(
                          controller: _letterPager,
                          itemCount: _letters.length,
                          onPageChanged: _onLetterPageChanged,
                          physics: _opened != null
                              ? const NeverScrollableScrollPhysics()
                              : null,
                          itemBuilder: (context, i) {
                            if (_letters[i] != _letter) {
                              return const ColoredBox(color: Colors.white);
                            }
                            return _buildLetterPane();
                          },
                        ),
                      if (_opened != null)
                        Positioned.fill(
                          child: ArticleSheetPanel(
                            key: ValueKey(_opened!.id),
                            repository: widget.repository,
                            bookmarks: widget.bookmarks,
                            articleId: _opened!.id,
                            title: _opened!.displayWord,
                            onClose: _dismissArticleSheet,
                            onPunzhUrl: _onPunzhUrl,
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBody() {
    return Stack(
      children: [
        _buildSearchList(),
        if (_showScrubber)
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: RepaintBoundary(
              child: ValueListenableBuilder<int>(
                valueListenable: _pageIndex,
                builder: (context, active, _) {
                  return NgramScrubber(
                    anchors: _anchors,
                    activeAnchor: active,
                    onSelectAnchor: _selectPage,
                    width: _scrubberWidth,
                  );
                },
              ),
            ),
          ),
      ],
    );
  }


  Widget _buildEmptySearch() {
    final suggestions = _krlSuggestions;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      children: [
        Text(
          "Ничего не найдено.",
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: PunzhColors.navbar,
              ),
        ),
        if (suggestions.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            "Возможно вы искали:",
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: const Color(0xFF6C757D),
                  fontWeight: FontWeight.w600,
                ),
              ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final w in suggestions)
                ActionChip(
                  label: Text(w),
                  onPressed: () {
                    _queryController.text = w;
                    _queryController.selection = TextSelection.collapsed(
                      offset: w.length,
                    );
                    unawaited(_runSearch(w));
                  },
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildSearchList() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text(_error!, textAlign: TextAlign.center));
    }
    if (_items.isEmpty) {
      return _buildEmptySearch();
    }
    return _articleList(
      _items,
      padForScrubber: _showScrubber,
      scrollController: _listScroll,
    );
  }

  Widget _buildLetterPane() {
    return Stack(
      children: [
        _buildLetterBody(),
        if (_showScrubber)
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: RepaintBoundary(
              child: ValueListenableBuilder<int>(
                valueListenable: _pageIndex,
                builder: (context, active, _) {
                  return NgramScrubber(
                    anchors: _anchors,
                    activeAnchor: active,
                    onSelectAnchor: _selectPage,
                    width: _scrubberWidth,
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLetterBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text(_error!, textAlign: TextAlign.center));
    }
    if (_items.isEmpty) {
      return const Center(child: Text("Ничего не найдено."));
    }
    return _articleList(
      _items,
      padForScrubber: _showScrubber,
      scrollController: _listScroll,
    );
  }

  Widget _articleList(
    List<ArticleSummary> items, {
    required bool padForScrubber,
    ScrollController? scrollController,
  }) {
    return ListView.builder(
      controller: scrollController,
      itemExtent: _rowExtent,
      addAutomaticKeepAlives: false,
      padding: EdgeInsets.only(left: padForScrubber ? _scrubberWidth : 0),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final preview = item.previewLine;
        return DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Color(0xFFE9ECEF), width: 1),
            ),
          ),
          child: ListTile(
            key: ValueKey("${item.id}-$index"),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            title: Text(
              item.displayWord,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _titleStyle,
            ),
            subtitle: SizedBox(
              height: 32,
              child: preview.isEmpty
                  ? null
                  : Text(
                      preview,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: _subtitleStyle,
                    ),
            ),
            trailing: const Icon(
              Icons.keyboard_arrow_up,
              size: 22,
              color: Color(0xFFADB5BD),
            ),
            onTap: () => _openArticle(item),
          ),
        );
      },
    );
  }
}
