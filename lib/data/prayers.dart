import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class Line {
  final String bo, ph, en;
  const Line(this.bo, this.ph, this.en);
}

class Prayer {
  final String id, kind, bo, en, about;
  final String? src;
  final bool verse;
  final List<String> occ, deity, trad;
  final List<Line> lines;
  Prayer({
    required this.id,
    required this.kind,
    required this.bo,
    required this.en,
    required this.about,
    required this.src,
    required this.verse,
    required this.occ,
    required this.deity,
    required this.trad,
    required this.lines,
  });

  factory Prayer.fromJson(Map<String, dynamic> j) {
    List<String> strs(dynamic v) => (v as List? ?? const []).map((e) => e.toString()).toList();
    return Prayer(
      id: j['id'] as String,
      kind: (j['kind'] ?? 'Prayer') as String,
      bo: j['bo'] as String,
      en: j['en'] as String,
      about: (j['about'] ?? '') as String,
      src: j['src'] as String?,
      verse: j['verse'] == true,
      occ: strs(j['occ']),
      deity: strs(j['deity']),
      trad: strs(j['trad']),
      lines: (j['lines'] as List)
          .map((l) => Line(l[0].toString(), l[1].toString(), l[2].toString()))
          .toList(),
    );
  }

  bool get isMantra => kind == 'Mantra';

  /// Number shown in the reader for line [i]: verses are counted only when they have several lines.
  int unitCount() => verse ? lines.where((l) => l.bo.contains('\n')).length : lines.length;
  String unitLabel() {
    final n = unitCount();
    if (verse) return '$n ${n == 1 ? 'verse' : 'verses'}';
    return '$n ${n == 1 ? 'line' : 'lines'}';
  }
}

class Library {
  static List<Prayer> all = [];
  static Map<String, Prayer> byId = {};

  static Future<void> load() async {
    final raw = await rootBundle.loadString('assets/prayers.json');
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    all = list.map(Prayer.fromJson).toList();
    byId = {for (final p in all) p.id: p};
  }

  static List<Prayer> get mantras => all.where((p) => p.isMantra).toList();
}

class Browse {
  static const occasions = [
    'Daily', 'Morning', 'Evening', 'Before meals', 'Before teachings', 'Study & exams',
    'Travel & protection', 'For the sick', 'For the deceased', 'Long life'
  ];
  static const deities = [
    'Buddha', 'Chenrezig', 'Tara', 'Manjushri', 'Medicine Buddha', 'Guru Rinpoche', 'Tsongkhapa', 'Milarepa', 'Karmapa'
  ];
  static const deityBo = {
    'Buddha': 'སངས་རྒྱས།', 'Chenrezig': 'སྤྱན་རས་གཟིགས།', 'Tara': 'སྒྲོལ་མ།', 'Manjushri': 'འཇམ་དབྱངས།',
    'Medicine Buddha': 'སྨན་བླ།', 'Guru Rinpoche': 'གུ་རུ་རིན་པོ་ཆེ།', 'Tsongkhapa': 'ཙོང་ཁ་པ།',
    'Milarepa': 'མི་ལ་རས་པ།', 'Karmapa': 'ཀརྨ་པ།'
  };
  static const traditions = ['All traditions', 'Gelug', 'Nyingma', 'Kagyu', 'Sakya', 'Bon'];
}
