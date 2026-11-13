// Port of website `create_ngram` + letter page landmarks for the offline index.

import "orthography.dart";

/// First [n] letters of the normalized headword (Django `create_ngram`).
String createNgram(String word, int n) {
  if (n <= 0 || word.isEmpty) return "";
  var w = normalization(stripKrlApostrophes(word.toLowerCase()));
  w = w.split(RegExp(r"[\s,]")).first;
  if (w.length <= n) return w;
  return w.substring(0, n);
}

class NgramAnchor {
  const NgramAnchor({required this.index, required this.label});

  /// Index into the page list (or legacy continuous list).
  final int index;
  final String label;
}

/// One page of a letter index: half-open `[start, end)` into the bare index.
class LetterPage {
  const LetterPage({
    required this.start,
    required this.end,
    required this.label,
  });

  final int start;
  final int end;
  final String label;

  int get length => end - start;
}

/// Vertical padding inside [NgramScrubber] (top + bottom).
const double kNgramRailVerticalPadding = 24;

/// Minimum tap-band height per n-gram slot on the rail.
const double kNgramRailMinSlotHeight = 28;

/// How many letter-page rail marks fit into [railHeight] on this device.
///
/// Used as `targetPages` for [buildLetterPages]. Falls back to 12 until the
/// rail has a real layout height.
int maxLetterPagesForRailHeight(
  double railHeight, {
  double minSlotHeight = kNgramRailMinSlotHeight,
  double verticalPadding = kNgramRailVerticalPadding,
  int absoluteMin = 2,
  int absoluteMax = 28,
}) {
  if (railHeight <= 0 || minSlotHeight <= 0) return 12;
  final inner = railHeight - verticalPadding;
  if (inner < minSlotHeight * absoluteMin) return absoluteMin;
  return (inner / minSlotHeight).floor().clamp(absoluteMin, absoluteMax);
}

/// Split a letter's headwords into ~[targetPages] pages for rail navigation.
///
/// If [words.length] ≤ [minPageSize], returns a single page (caller hides rail).
List<LetterPage> buildLetterPages(
  List<String> words, {
  int targetPages = 12,
  int minPageSize = 50,
}) {
  if (words.isEmpty) return const [];
  if (words.length <= minPageSize) {
    return [
      LetterPage(
        start: 0,
        end: words.length,
        label: createNgram(words.first, 3),
      ),
    ];
  }

  final pageSize = (words.length / targetPages).ceil().clamp(
    minPageSize,
    words.length,
  );
  final pages = <LetterPage>[];
  for (var start = 0; start < words.length; start += pageSize) {
    final end = (start + pageSize < words.length)
        ? start + pageSize
        : words.length;
    pages.add(
      LetterPage(
        start: start,
        end: end,
        label: createNgram(words[start], 3),
      ),
    );
  }

  // Last rail mark is always the final headword (end-of-letter jump target).
  final labelWords = <String>[
    for (var i = 0; i < pages.length; i++)
      i == pages.length - 1 ? words.last : words[pages[i].start],
  ];

  // Grow n-grams until every rail label is unique across the whole letter
  // (neighbour-only disambiguation misses cases like ter’vewt vs t’erä → "ter").
  for (var idx = 0; idx < pages.length; idx++) {
    final word = labelWords[idx];
    var n = 3;
    var label = createNgram(word, n);
    while (n <= word.length) {
      label = createNgram(word, n);
      var clash = false;
      for (var j = 0; j < pages.length; j++) {
        if (j == idx) continue;
        if (createNgram(labelWords[j], n) == label) {
          clash = true;
          break;
        }
      }
      if (!clash) break;
      n++;
    }
    pages[idx] = LetterPage(
      start: pages[idx].start,
      end: pages[idx].end,
      label: label,
    );
  }

  return pages;
}

/// Scrubber landmarks from letter pages (index = page number).
List<NgramAnchor> anchorsForPages(List<LetterPage> pages) {
  return [
    for (var i = 0; i < pages.length; i++)
      NgramAnchor(index: i, label: pages[i].label),
  ];
}
