/// Same rule as Django `dict.search.common.detect_direction`:
/// any Cyrillic letter → Russian; otherwise Karelian (Latin + diacritics).
enum SearchDirection { karelian, russian }

final RegExp _cyrillic = RegExp(r"[а-яёА-ЯЁ]");

SearchDirection detectDirection(String query) {
  if (_cyrillic.hasMatch(query)) {
    return SearchDirection.russian;
  }
  return SearchDirection.karelian;
}
