import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Everything the app remembers, kept on the phone only.
class Store extends ChangeNotifier {
  Store._();
  static final Store i = Store._();
  late SharedPreferences _p;

  Future<void> init() async {
    _p = await SharedPreferences.getInstance();
    saved = (_p.getStringList('saved') ?? const <String>[]).toSet();
    final l = _json('layers');
    showBo = l['bo'] ?? true;
    showPh = l['ph'] ?? true;
    showEn = l['en'] ?? true;
    textScale = _p.getDouble('size') ?? 1.0;
    scrollSpeed = _p.getInt('speed') ?? 2;
    mala = MalaState.fromJson(_json('mala'));
    recordings = _json('recs').map((k, v) => MapEntry(k as String, Recording.fromJson(v as Map<String, dynamic>)));
    guides = ((_p.getString('guides') != null ? jsonDecode(_p.getString('guides')!) : const []) as List)
        .map((g) => Guide.fromJson(g as Map<String, dynamic>))
        .toList();
    reminders = ReminderSettings.fromJson(_json('reminders'));
  }

  Map<String, dynamic> _json(String k) {
    final s = _p.getString(k);
    if (s == null) return {};
    try {
      return (jsonDecode(s) as Map).cast<String, dynamic>();
    } catch (_) {
      return {};
    }
  }

  // ---- saved prayers ----
  Set<String> saved = {};
  void toggleSaved(String id) {
    saved.contains(id) ? saved.remove(id) : saved.add(id);
    _p.setStringList('saved', saved.toList());
    notifyListeners();
  }

  // ---- reader settings ----
  bool showBo = true, showPh = true, showEn = true;
  double textScale = 1.0;
  int scrollSpeed = 2;
  void setLayers({bool? bo, bool? ph, bool? en}) {
    final nb = bo ?? showBo, np = ph ?? showPh, ne = en ?? showEn;
    if (!nb && !np && !ne) return; // keep at least one layer
    showBo = nb;
    showPh = np;
    showEn = ne;
    _p.setString('layers', jsonEncode({'bo': showBo, 'ph': showPh, 'en': showEn}));
    notifyListeners();
  }

  void setTextScale(double v) {
    textScale = v.clamp(0.8, 1.8);
    _p.setDouble('size', textScale);
    notifyListeners();
  }

  void setScrollSpeed(int v) {
    scrollSpeed = v.clamp(1, 6);
    _p.setInt('speed', scrollSpeed);
    notifyListeners();
  }

  // ---- mala ----
  late MalaState mala;
  void saveMala() {
    _p.setString('mala', jsonEncode(mala.toJson()));
    notifyListeners();
  }

  // ---- recordings ----
  Map<String, Recording> recordings = {};
  void setRecording(String pid, Recording? r) {
    if (r == null) {
      recordings.remove(pid);
    } else {
      recordings[pid] = r;
    }
    _p.setString('recs', jsonEncode(recordings.map((k, v) => MapEntry(k, v.toJson()))));
    notifyListeners();
  }

  // ---- 49-day guides ----
  List<Guide> guides = [];
  void saveGuides() {
    _p.setString('guides', jsonEncode(guides.map((g) => g.toJson()).toList()));
    notifyListeners();
  }

  // ---- reminders ----
  late ReminderSettings reminders;
  void saveReminders() {
    _p.setString('reminders', jsonEncode(reminders.toJson()));
    notifyListeners();
  }
}

String dayKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class MalaCount {
  int total, round, goal, dayCount;
  String day;
  MalaCount({this.total = 0, this.round = 0, this.goal = 100000, this.dayCount = 0, this.day = ''});
  factory MalaCount.fromJson(Map<String, dynamic> j) => MalaCount(
        total: (j['total'] ?? 0) as int,
        round: (j['round'] ?? 0) as int,
        goal: (j['goal'] ?? 100000) as int,
        dayCount: (j['dayCount'] ?? 0) as int,
        day: (j['day'] ?? '') as String,
      );
  Map<String, dynamic> toJson() => {'total': total, 'round': round, 'goal': goal, 'dayCount': dayCount, 'day': day};
}

class MalaState {
  String current;
  final Map<String, MalaCount> counts;
  bool volumeKeys;
  MalaState(this.current, this.counts, this.volumeKeys);
  factory MalaState.fromJson(Map<String, dynamic> j) => MalaState(
        (j['cur'] ?? 'om-mani') as String,
        ((j['m'] ?? {}) as Map).map((k, v) => MapEntry(k as String, MalaCount.fromJson((v as Map).cast<String, dynamic>()))),
        (j['volumeKeys'] ?? true) as bool,
      );
  Map<String, dynamic> toJson() => {'cur': current, 'm': counts.map((k, v) => MapEntry(k, v.toJson())), 'volumeKeys': volumeKeys};

  MalaCount of(String id) {
    final c = counts.putIfAbsent(id, () => MalaCount());
    final today = dayKey(DateTime.now());
    if (c.day != today) {
      c.day = today;
      c.dayCount = 0;
    }
    return c;
  }
}

class Recording {
  final String path, name;
  final List<double?> times;
  Recording(this.path, this.name, this.times);
  factory Recording.fromJson(Map<String, dynamic> j) => Recording(
        j['path'] as String,
        (j['name'] ?? '') as String,
        ((j['times'] ?? const []) as List).map((e) => e == null ? null : (e as num).toDouble()).toList(),
      );
  Map<String, dynamic> toJson() => {'path': path, 'name': name, 'times': times};
  bool get hasTimes => times.any((t) => t != null);
  Recording withTimes(List<double?> t) => Recording(path, name, t);
}

/// A 49-day guide for someone who has passed away.
class Guide {
  final String id;
  String name;
  DateTime passed;
  bool remind;
  final Set<String> doneDays; // day keys on which prayers were done
  Guide(this.id, this.name, this.passed, this.remind, this.doneDays);
  factory Guide.fromJson(Map<String, dynamic> j) => Guide(
        j['id'] as String,
        (j['name'] ?? '') as String,
        DateTime.parse(j['passed'] as String),
        (j['remind'] ?? true) as bool,
        ((j['done'] ?? const []) as List).map((e) => e.toString()).toSet(),
      );
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'passed': dayKey(passed), 'remind': remind, 'done': doneDays.toList()};

  /// Day 1 is the day of passing.
  int dayNumber(DateTime today) =>
      DateTime(today.year, today.month, today.day).difference(DateTime(passed.year, passed.month, passed.day)).inDays + 1;
  DateTime weekDate(int k) => DateTime(passed.year, passed.month, passed.day).add(Duration(days: 7 * k));
  DateTime get finalDate => weekDate(7);
  bool get finished => DateTime.now().isAfter(finalDate.add(const Duration(days: 1)));
}

class ReminderSettings {
  bool festivals, practiceDays, flagDays, guides;
  int hour, minute;
  ReminderSettings(this.festivals, this.practiceDays, this.flagDays, this.guides, this.hour, this.minute);
  factory ReminderSettings.fromJson(Map<String, dynamic> j) => ReminderSettings(
        (j['festivals'] ?? true) as bool,
        (j['practice'] ?? false) as bool,
        (j['flags'] ?? false) as bool,
        (j['guides'] ?? true) as bool,
        (j['hour'] ?? 6) as int,
        (j['minute'] ?? 30) as int,
      );
  Map<String, dynamic> toJson() =>
      {'festivals': festivals, 'practice': practiceDays, 'flags': flagDays, 'guides': guides, 'hour': hour, 'minute': minute};
  bool get any => festivals || practiceDays || flagDays || guides;
}
