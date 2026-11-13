/// Classic Levenshtein edit distance (insert / delete / substitute = 1).
int levenshtein(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;

  // Keep the inner loop over the shorter string.
  if (a.length > b.length) {
    final t = a;
    a = b;
    b = t;
  }

  var prev = List<int>.generate(a.length + 1, (i) => i);

  for (var j = 1; j <= b.length; j++) {
    final curr = List<int>.filled(a.length + 1, 0);
    curr[0] = j;
    final bj = b.codeUnitAt(j - 1);
    for (var i = 1; i <= a.length; i++) {
      final cost = a.codeUnitAt(i - 1) == bj ? 0 : 1;
      final del = prev[i] + 1;
      final ins = curr[i - 1] + 1;
      final sub = prev[i - 1] + cost;
      var v = del < ins ? del : ins;
      if (sub < v) v = sub;
      curr[i] = v;
    }
    prev = curr;
  }
  return prev[a.length];
}
