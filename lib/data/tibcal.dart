/// Tibetan calendar, Phugpa system (as used by Men-Tsee-Khang),
/// following Svante Janson, "Tibetan calendar mathematics".
/// Checked against Losar 2021–2026, Saga Dawa 2025 and a published 1997 prayer-flag list.
import 'prayers.dart';

class TibDay {
  final int jd, year, month, day;
  final bool leap; // leap (first) month
  final bool extra; // first of a doubled day
  final int skippedNext; // if the next day number is skipped, that number, else 0
  TibDay(this.jd, this.year, this.month, this.day, this.leap, this.extra, this.skippedNext);
}

class TibCal {
  static const _m0 = 2015501 + 4783 / 5656, _m1 = 167025 / 5656, _s0 = 743 / 804, _s1 = 65 / 804;
  static const _a0 = 475 / 3528, _a1 = 253 / 3528, _a2 = 1 / 28;
  static const _mt = [0, 5, 10, 15, 19, 22, 24, 25];
  static const _st = [0, 6, 10, 11];
  static double get _m2 => _m1 / 30;
  static double get _s2 => _s1 / 30;

  static int _mtab(int i) {
    i = i % 28;
    if (i <= 7) return _mt[i];
    if (i <= 14) return _mt[14 - i];
    if (i <= 21) return -_mt[i - 14];
    return -_mt[28 - i];
  }

  static int _stab(int i) {
    i = i % 12;
    if (i <= 3) return _st[i];
    if (i <= 6) return _st[6 - i];
    if (i <= 9) return -_st[i - 6];
    return -_st[12 - i];
  }

  static double _interp(int Function(int) tab, double x) {
    final f = x.floor();
    final r = x - f;
    return tab(f) + r * (tab(f + 1) - tab(f));
  }

  static double trueDate(int d, int n) {
    final md = n * _m1 + d * _m2 + _m0, ms = n * _s1 + d * _s2 + _s0, am = n * _a1 + d * _a2 + _a0;
    return md + _interp(_mtab, 28 * am) / 60 - _interp(_stab, 12 * (ms - 0.25)) / 60;
  }

  static int _ix(int y, int m) => (67 * (12 * (y - 806) + m - 3) + 61) % 65;
  static bool isLeap(int y, int m) {
    final x = _ix(y, m);
    return x == 48 || x == 49;
  }

  static int _monthN(int y, int m, bool leap) => ((67 * (12 * (y - 806) + m - 3) + 61 + 17) ~/ 65) - (leap ? 1 : 0);

  static final Map<int, List<TibDay>> _cache = {};
  static List<TibDay> year(int y) {
    return _cache.putIfAbsent(y, () {
      final days = <TibDay>[];
      for (var m = 1; m <= 12; m++) {
        for (final leap in isLeap(y, m) ? [true, false] : [false]) {
          final n = _monthN(y, m, leap);
          final e = List<int>.filled(31, 0);
          e[0] = trueDate(30, n - 1).floor();
          for (var d = 1; d <= 30; d++) {
            e[d] = trueDate(d, n).floor();
          }
          final skipped = <int>{};
          for (var d = 1; d <= 30; d++) {
            if (e[d] == e[d - 1]) skipped.add(d);
          }
          for (var jd = e[0] + 1; jd <= e[30]; jd++) {
            var d = 0;
            for (var k = 1; k <= 30; k++) {
              if (e[k] == jd) {
                d = k;
                break;
              }
            }
            var extra = false;
            if (d == 0) {
              for (var k = 1; k <= 30; k++) {
                if (e[k] > jd) {
                  d = k;
                  break;
                }
              }
              extra = true;
            }
            days.add(TibDay(jd, y, m, d, leap, extra, skipped.contains(d + 1) ? d + 1 : 0));
          }
        }
      }
      return days;
    });
  }

  static TibDay? info(int jd) {
    final g = fromJd(jd);
    for (final y in [g.year, g.year - 1, g.year + 1]) {
      for (final t in year(y)) {
        if (t.jd == jd) return t;
      }
    }
    return null;
  }

  static TibDay? forDate(DateTime d) => info(jdOf(d));
}

int jdOf(DateTime d) => DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/ 86400000 + 2440588;
DateTime fromJd(int jd) => DateTime.fromMillisecondsSinceEpoch((jd - 2440588) * 86400000, isUtc: true);
DateTime localFromJd(int jd) {
  final u = fromJd(jd);
  return DateTime(u.year, u.month, u.day);
}

int todayJd() => jdOf(DateTime.now());

const _el = ['Wood', 'Fire', 'Earth', 'Iron', 'Water'];
const _elBo = ['ཤིང་', 'མེ་', 'ས་', 'ལྕགས་', 'ཆུ་'];
const _an = ['Rat', 'Ox', 'Tiger', 'Rabbit', 'Dragon', 'Snake', 'Horse', 'Sheep', 'Monkey', 'Bird', 'Dog', 'Pig'];
const _anBo = ['བྱི་', 'གླང་', 'སྟག་', 'ཡོས་', 'འབྲུག་', 'སྦྲུལ་', 'རྟ་', 'ལུག་', 'སྤྲེལ་', 'བྱ་', 'ཁྱི་', 'ཕག་'];
const _mBo = ['དང་པོ', 'གཉིས་པ', 'གསུམ་པ', 'བཞི་པ', 'ལྔ་པ', 'དྲུག་པ', 'བདུན་པ', 'བརྒྱད་པ', 'དགུ་པ', 'བཅུ་པ', 'བཅུ་གཅིག་པ', 'བཅུ་གཉིས་པ'];
const monthNames = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
const weekdayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

String tibNum(int n) => n.toString().split('').map((c) => '༠༡༢༣༤༥༦༧༨༩'[int.parse(c)]).join();

class YearName {
  final String en, bo;
  final int royal;
  YearName(this.en, this.bo, this.royal);
}

YearName yearName(int y) {
  final e = ((y - 4) % 10) ~/ 2, a = (y - 4) % 12;
  return YearName('${y.isOdd ? 'Female' : 'Male'} ${_el[e]} ${_an[a]}', '${_elBo[e]}${_anBo[a]}ལོ།', y + 127);
}

class TibLabel {
  final String bo, en, yr;
  TibLabel(this.bo, this.en, this.yr);
}

TibLabel tibLabel(TibDay t) {
  final yn = yearName(t.year);
  return TibLabel(
    '${yn.bo} ${t.leap ? 'ཟླ་ལྷག་' : 'ཟླ་བ་'}${_mBo[t.month - 1]}འི་ཚེས་${tibNum(t.day)}',
    'Day ${t.day}${t.extra ? ' (first of two)' : ''} of ${t.leap ? 'leap ' : ''}month ${t.month}',
    '${yn.en} year ${yn.royal}',
  );
}

enum EvKind { festival, practice, avoidFlags, flagDay }

class CalEvent {
  final EvKind kind;
  final String title, sub;
  final String? prayerId;
  CalEvent(this.kind, this.title, this.sub, [this.prayerId]);
}

const _flagAvoid = {
  1: [10, 22], 5: [10, 22], 9: [10, 22],
  2: [7, 19], 6: [7, 19], 10: [7, 19],
  3: [4, 16], 7: [4, 16], 11: [4, 16],
  4: [1, 13], 8: [1, 13], 12: [1, 13],
};

List<CalEvent> eventsFor(TibDay t) {
  final ev = <CalEvent>[];
  final g = fromJd(t.jd);
  final main = !t.leap;
  if (main && t.month == 1 && t.day == 1) ev.add(CalEvent(EvKind.festival, 'Losar', 'Tibetan New Year'));
  if (main && t.month == 1 && t.day == 2) ev.add(CalEvent(EvKind.festival, 'Losar, day 2', 'Tibetan New Year'));
  if (main && t.month == 1 && t.day == 3) ev.add(CalEvent(EvKind.flagDay, 'Losar, day 3', 'Traditional day to raise new prayer flags'));
  if (main && t.month == 1 && t.day == 15) ev.add(CalEvent(EvKind.festival, 'Chötrul Düchen', 'Day of Miracles, end of Monlam', 'shakyamuni'));
  if (main && t.month == 4 && t.day == 15) ev.add(CalEvent(EvKind.festival, 'Saga Dawa Düchen', "Buddha's enlightenment and parinirvana", 'shakyamuni'));
  if (main && t.month == 6 && t.day == 4) ev.add(CalEvent(EvKind.festival, 'Chökhor Düchen', "Buddha's first teaching", 'heart-sutra'));
  if (main && t.month == 9 && t.day == 22) ev.add(CalEvent(EvKind.festival, 'Lhabab Düchen', "Buddha's descent from the god realm", 'shakyamuni'));
  if (main && t.month == 10 && t.day == 25) ev.add(CalEvent(EvKind.festival, 'Ganden Ngamchö', 'Anniversary of Je Tsongkhapa', 'ganden-lhagyama'));
  if (g.month == 7 && g.day == 6) ev.add(CalEvent(EvKind.festival, 'Birthday of His Holiness the Dalai Lama', 'Gregorian date', 'long-life-hhdl'));
  if (t.day == 8) ev.add(CalEvent(EvKind.practice, 'Medicine Buddha and Tara day', '8th of the Tibetan month', 'medicine-buddha-praise'));
  if (t.day == 10) ev.add(CalEvent(EvKind.practice, 'Guru Rinpoche day', '10th of the Tibetan month', 'seven-line'));
  if (t.day == 15) ev.add(CalEvent(EvKind.practice, 'Full moon', 'Amitabha day; merit is multiplied', 'dewachen-short'));
  if (t.day == 25) ev.add(CalEvent(EvKind.practice, 'Dakini day', '25th of the Tibetan month', 'twenty-one-taras'));
  if (t.day == 30) ev.add(CalEvent(EvKind.practice, 'New moon', 'Shakyamuni Buddha day', 'shakyamuni'));
  if ((_flagAvoid[t.month] ?? const []).contains(t.day)) {
    ev.add(CalEvent(EvKind.avoidFlags, 'Avoid hanging prayer flags', 'Traditional rule for this month and day'));
  }
  // Keep every event, but drop a prayer link the library doesn't have.
  return ev
      .map((e) => e.prayerId != null && Library.byId.isNotEmpty && !Library.byId.containsKey(e.prayerId)
          ? CalEvent(e.kind, e.title, e.sub)
          : e)
      .toList();
}

bool avoidFlags(TibDay t) => eventsFor(t).any((e) => e.kind == EvKind.avoidFlags);
