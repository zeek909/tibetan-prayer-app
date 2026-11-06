import 'prayers.dart';

/// Search across Tibetan script, phonetics and English, tolerant of spaces, tsheg and accents.
class SearchHit {
  final Prayer prayer;
  final int score;
  final int line; // -1 when the match is not in a particular line
  SearchHit(this.prayer, this.score, this.line);
}

const _accents = {
  'á': 'a', 'à': 'a', 'â': 'a', 'ä': 'a', 'ã': 'a', 'å': 'a', 'ā': 'a',
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e', 'ē': 'e',
  'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i', 'ī': 'i',
  'ó': 'o', 'ò': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o', 'ō': 'o',
  'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u', 'ū': 'u',
  'ñ': 'n', 'ṅ': 'n', 'ṇ': 'n', 'ṃ': 'm', 'ś': 's', 'ṣ': 's', 'ṭ': 't', 'ḍ': 'd', 'ḥ': 'h', 'ç': 'c', 'ṛ': 'r',
};

String latin(String s) {
  final b = StringBuffer();
  for (final r in s.toLowerCase().runes) {
    final ch = String.fromCharCode(r);
    b.write(_accents[ch] ?? ch);
  }
  return b.toString().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
}

String compact(String s) => latin(s).replaceAll(' ', '');

bool isTibetan(String s) => RegExp(r'[ༀ-࿿]').hasMatch(s);

String tib(String s) => s
    .replaceAll(RegExp(r'[^ༀ-࿿]'), '')
    .replaceAll(RegExp(r'[་-༔ཿ྄]'), '');

class _Index {
  final String tibAll, latAll, title;
  final List<String> ph, tibLines;
  _Index(this.tibAll, this.latAll, this.title, this.ph, this.tibLines);
}

final Map<String, _Index> _idx = {};

_Index _indexOf(Prayer p) => _idx.putIfAbsent(p.id, () {
      final latText = [p.en, p.about, ...p.occ, ...p.deity, ...p.trad, for (final l in p.lines) ...[l.ph, l.en]].join(' ');
      return _Index(
        tib(p.bo + p.lines.map((l) => l.bo).join()),
        compact(latText),
        compact(p.en),
        p.lines.map((l) => compact(l.ph)).toList(),
        p.lines.map((l) => tib(l.bo)).toList(),
      );
    });

List<SearchHit> search(String query) {
  final q = query.trim();
  if (q.isEmpty) return [];
  final out = <SearchHit>[];
  if (isTibetan(q)) {
    final t = tib(q);
    if (t.isEmpty) return [];
    for (final p in Library.all) {
      final ix = _indexOf(p);
      if (!ix.tibAll.contains(t)) continue;
      out.add(SearchHit(p, tib(p.bo).contains(t) ? 3 : 1, ix.tibLines.indexWhere((x) => x.contains(t))));
    }
  } else {
    final words = latin(q).split(' ').where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return [];
    final cq = words.join();
    for (final p in Library.all) {
      final ix = _indexOf(p);
      if (!words.every(ix.latAll.contains)) continue;
      var score = 1;
      if (ix.title.contains(cq)) score += 3;
      var line = ix.ph.indexWhere((x) => x.contains(cq));
      if (line < 0) line = p.lines.indexWhere((l) => compact(l.en).contains(cq));
      if (line >= 0) score += 1;
      out.add(SearchHit(p, score, line));
    }
  }
  out.sort((a, b) => b.score.compareTo(a.score));
  return out;
}

/// The one line (of a multi-line verse) that best shows why a hit matched.
String hitSnippet(Prayer p, int line, String query) {
  if (line < 0 || line >= p.lines.length) return '';
  final l = p.lines[line];
  final bos = l.bo.split('\n'), phs = l.ph.split('\n');
  final cq = compact(query), tq = tib(query);
  var k = cq.isEmpty ? -1 : phs.indexWhere((x) => compact(x).contains(cq));
  if (k < 0 && tq.isNotEmpty) k = bos.indexWhere((x) => tib(x).contains(tq));
  if (k < 0) k = 0;
  String short(String s) => s.length > 80 ? '${s.substring(0, 78)}…' : s;
  final b = k < bos.length ? bos[k] : bos.first;
  final ph = k < phs.length ? phs[k] : phs.first;
  return '${short(b)} · ${short(ph)}';
}
