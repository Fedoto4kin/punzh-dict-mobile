import "package:flutter/foundation.dart";

/// Group order matches website KRL filters (`_KRL_TAG_GROUP_ORDER`).
const List<int> krlTagGroupOrder = [2, 3, 1, 4];

const Map<int, String> krlTagGroupTitles = {
  1: "Населенные пункты",
  2: "Грамматические пометы",
  3: "Нормативно-стилистические и экспрессивно-оценочные пометы",
  4: "Говоры",
};

const String krlPhraseFilterLabel = "словарные статьи с фразеологизмами";

class DictTag {
  const DictTag({
    required this.id,
    required this.tag,
    required this.name,
    required this.type,
    required this.level,
    this.sorting,
  });

  final int id;
  final String tag;
  final String name;
  final int type;
  final int level;
  final int? sorting;

  /// Display label (website uses Tag.name).
  String get label => name.trim().isNotEmpty ? name : tag;
}

/// In-memory filter selection: ≤1 tag per type + optional phraseologism flag.
class TagFilterState extends ChangeNotifier {
  final Map<int, int> _selectedByType = {};
  bool _phrase = false;
  Map<int, DictTag> _catalog = {};

  bool get phrase => _phrase;

  bool get isEmpty => _selectedByType.isEmpty && !_phrase;

  int get activeCount => _selectedByType.length + (_phrase ? 1 : 0);

  /// Selected tag ids in website group order.
  List<int> get tagIds {
    final out = <int>[];
    for (final t in krlTagGroupOrder) {
      final id = _selectedByType[t];
      if (id != null) out.add(id);
    }
    return out;
  }

  void setCatalog(Iterable<DictTag> tags) {
    _catalog = {for (final t in tags) t.id: t};
  }

  DictTag? tagById(int id) => _catalog[id];

  int? selectedIdForType(int type) => _selectedByType[type];

  List<DictTag> tagsOfType(int type) {
    final list = _catalog.values.where((t) => t.type == type).toList();
    list.sort((a, b) {
      final sa = a.sorting ?? 1000000000;
      final sb = b.sorting ?? 1000000000;
      final c = sa.compareTo(sb);
      if (c != 0) return c;
      final n = a.label.compareTo(b.label);
      if (n != 0) return n;
      return a.id.compareTo(b.id);
    });
    return list;
  }

  /// Tap a tag: select it, or clear if already selected (radio toggle).
  void toggleTag(DictTag tag) {
    if (tag.type == 5) return;
    if (tag.type == 2 && tag.level != 0) return;
    final cur = _selectedByType[tag.type];
    if (cur == tag.id) {
      _selectedByType.remove(tag.type);
    } else {
      _selectedByType[tag.type] = tag.id;
    }
    notifyListeners();
  }

  void clearType(int type) {
    if (_selectedByType.remove(type) != null) {
      notifyListeners();
    }
  }

  void removeTagId(int id) {
    final tag = _catalog[id];
    if (tag == null) {
      _selectedByType.removeWhere((_, v) => v == id);
      notifyListeners();
      return;
    }
    clearType(tag.type);
  }

  void togglePhrase() {
    _phrase = !_phrase;
    notifyListeners();
  }

  void setPhrase(bool value) {
    if (_phrase == value) return;
    _phrase = value;
    notifyListeners();
  }

  void clear() {
    if (isEmpty) return;
    _selectedByType.clear();
    _phrase = false;
    notifyListeners();
  }
}

/// Visible facet options for the filter sheet (website-style).
class TagFacets {
  const TagFacets({
    required this.optionsByType,
    required this.enabledTagIds,
    required this.showPhrase,
    required this.phraseEnabled,
  });

  /// All marks of each type present in the *primary* (unfiltered) hit set.
  final Map<int, List<DictTag>> optionsByType;

  /// Tag ids still reachable with the current selection of *other* axes
  /// (AND). Chips outside this set stay visible but disabled.
  final Set<int> enabledTagIds;

  /// Whether the phraseologism control is shown at all (primary diversity).
  final bool showPhrase;

  /// Whether turning phrase on (or keeping it) still yields hits under
  /// the current tag selection.
  final bool phraseEnabled;

  bool get isEmpty => optionsByType.isEmpty && !showPhrase;

  /// True when the sheet can actually narrow the hit set (2+ marks or phrase).
  /// A single shared mark for all hits is not useful — hide the control.
  bool get hasFilterChoices {
    var n = 0;
    for (final tags in optionsByType.values) {
      n += tags.length;
      if (n >= 2) return true;
    }
    return showPhrase;
  }

  List<DictTag> optionsForType(int type) =>
      optionsByType[type] ?? const <DictTag>[];

  bool isTagEnabled(int tagId) => enabledTagIds.contains(tagId);
}
