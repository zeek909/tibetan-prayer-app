import 'package:flutter/material.dart';
import '../data/prayers.dart';
import '../data/tibcal.dart';
import '../theme.dart';
import 'reader.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});
  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

Color dotColor(BuildContext c, EvKind k) {
  final p = Pal.of(c);
  return switch (k) {
    EvKind.festival => p.maroon,
    EvKind.practice => p.saffron,
    EvKind.avoidFlags => const Color(0xFFB8322C),
    EvKind.flagDay => const Color(0xFF2F8A4D),
  };
}

class _CalendarScreenState extends State<CalendarScreen> {
  late int y, m;
  late int sel;

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    y = n.year;
    m = n.month;
    sel = todayJd();
  }

  void _openPrayer(String? id) {
    final p = id == null ? null : Library.byId[id];
    if (p != null) Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReaderScreen(p)));
  }

  @override
  Widget build(BuildContext context) {
    final pal = Pal.of(context);
    final today = todayJd();
    final t = TibCal.info(today);
    final now = DateTime.now();
    return SafeArea(
      child: ListView(padding: EdgeInsets.zero, children: [
        const FlagStripe(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Row(children: [
            Expanded(child: Text('Tibetan Calendar', style: serif(context, 22, weight: FontWeight.w600))),
            Text('ལོ་ཐོ།', style: bo(context, 20, color: pal.maroon)),
          ]),
        ),
        if (t != null) _todayCard(context, t, now, pal),
        _monthHeader(pal),
        _grid(context, pal, today),
        _legend(pal),
        _detail(context, pal),
        _section('Great festivals ahead'),
        ..._upcoming(context, pal, festivalsOnly: true, max: 6, span: 400),
        _section('Coming up'),
        ..._upcoming(context, pal, festivalsOnly: false, max: 10, span: 120),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 30),
          child: Text(
            'Dates are calculated with the Phugpa system used by Men-Tsee-Khang, checked against Losar 2021–2026 and a published 1997 prayer-flag list. Local almanacs sometimes move observances when a day is skipped, so confirm important dates with the printed Men-Tsee-Khang calendar.',
            style: TextStyle(fontSize: 12, color: pal.muted),
          ),
        ),
      ]),
    );
  }

  Widget _todayCard(BuildContext context, TibDay t, DateTime now, Pal pal) {
    final l = tibLabel(t);
    final ev = eventsFor(t);
    final avoid = ev.any((e) => e.kind == EvKind.avoidFlags);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: pal.surface, border: Border.all(color: pal.line), borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Today, ${weekdayNames[now.weekday - 1]} ${now.day} ${monthNames[now.month - 1]} ${now.year}',
            style: TextStyle(color: pal.muted, fontSize: 14)),
        Text(l.bo, style: bo(context, 22, color: pal.maroon)),
        Text(l.en, style: serif(context, 19, weight: FontWeight.w600)),
        Text('${l.yr}${t.skippedNext > 0 ? ' · Day ${t.skippedNext} is skipped this month' : ''}', style: TextStyle(color: pal.muted, fontSize: 13)),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final e in ev.where((e) => e.kind != EvKind.avoidFlags))
            ActionChip(label: Text(e.title), onPressed: e.prayerId == null ? null : () => _openPrayer(e.prayerId)),
          _pill(avoid ? 'Avoid hanging prayer flags today' : 'No prayer-flag restriction today', avoid),
        ]),
      ]),
    );
  }

  Widget _pill(String text, bool bad) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: (bad ? const Color(0xFFB8322C) : const Color(0xFF2F8A4D)).withOpacity(0.16),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(text, style: const TextStyle(fontSize: 13)),
      );

  Widget _monthHeader(Pal pal) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 14, 8, 4),
        child: Row(children: [
          IconButton(
              tooltip: 'Previous month',
              onPressed: () => setState(() {
                    m--;
                    if (m < 1) {
                      m = 12;
                      y--;
                    }
                  }),
              icon: const Icon(Icons.chevron_left)),
          Expanded(child: Text('${monthNames[m - 1]} $y', style: serif(context, 18, weight: FontWeight.w600))),
          TextButton(
              onPressed: () => setState(() {
                    final n = DateTime.now();
                    y = n.year;
                    m = n.month;
                    sel = todayJd();
                  }),
              child: const Text('Today')),
          IconButton(
              tooltip: 'Next month',
              onPressed: () => setState(() {
                    m++;
                    if (m > 12) {
                      m = 1;
                      y++;
                    }
                  }),
              icon: const Icon(Icons.chevron_right)),
        ]),
      );

  Widget _grid(BuildContext context, Pal pal, int today) {
    final first = jdOf(DateTime(y, m, 1));
    final last = jdOf(DateTime(m == 12 ? y + 1 : y, m == 12 ? 1 : m + 1, 1)) - 1;
    final lead = DateTime(y, m, 1).weekday - 1; // Monday first
    final cells = <Widget>[
      for (final w in weekdayNames)
        Center(child: Text(w.toUpperCase(), style: TextStyle(fontSize: 10, letterSpacing: 0.5, color: pal.muted))),
      for (var i = 0; i < lead; i++) const SizedBox.shrink(),
    ];
    for (var jd = first; jd <= last; jd++) {
      final ti = TibCal.info(jd);
      final kinds = ti == null ? <EvKind>{} : eventsFor(ti).map((e) => e.kind).toSet();
      final g = fromJd(jd);
      final isToday = jd == today, isSel = jd == sel;
      cells.add(InkWell(
        onTap: () => setState(() => sel = jd),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isSel ? pal.chip : pal.surface,
            border: Border.all(color: isToday ? pal.maroon : pal.line, width: isToday ? 2 : 1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('${g.day}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            Text(
              ti == null ? '' : (ti.day == 1 && !ti.extra ? 'M${ti.month}${ti.leap ? 'L' : ''}·1' : '${ti.day}${ti.extra ? 'a' : ''}'),
              style: TextStyle(fontSize: 10, color: pal.muted),
            ),
            Row(children: [
              for (final k in kinds)
                Container(
                  width: 6, height: 6, margin: const EdgeInsets.only(right: 2),
                  decoration: BoxDecoration(color: dotColor(context, k), shape: BoxShape.circle),
                ),
            ]),
          ]),
        ),
      ));
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: GridView.count(
        crossAxisCount: 7,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
        childAspectRatio: 0.72,
        children: cells,
      ),
    );
  }

  Widget _legend(Pal pal) {
    Widget item(EvKind k, String s) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: dotColor(context, k), shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(s, style: TextStyle(fontSize: 12, color: pal.muted)),
        ]);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Wrap(spacing: 12, runSpacing: 4, children: [
        item(EvKind.festival, 'Festival'),
        item(EvKind.practice, 'Monthly practice day'),
        item(EvKind.flagDay, 'Prayer-flag day'),
        item(EvKind.avoidFlags, 'Avoid prayer flags'),
      ]),
    );
  }

  Widget _detail(BuildContext context, Pal pal) {
    final g = fromJd(sel);
    if (g.year != y || g.month != m) return const SizedBox.shrink();
    final ti = TibCal.info(sel);
    if (ti == null) return const SizedBox.shrink();
    final l = tibLabel(ti);
    final ev = eventsFor(ti);
    final avoid = ev.any((e) => e.kind == EvKind.avoidFlags);
    final wd = DateTime(g.year, g.month, g.day).weekday;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(border: Border.all(color: pal.line), borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${weekdayNames[wd - 1]} ${g.day} ${monthNames[g.month - 1]} ${g.year}', style: serif(context, 17, weight: FontWeight.w600)),
        Text(l.bo, style: bo(context, 19, color: pal.maroon)),
        Text('${l.en} · ${l.yr}'),
        if (ti.skippedNext > 0) Text('Day ${ti.skippedNext} is skipped this month.', style: TextStyle(fontSize: 13, color: pal.muted)),
        const SizedBox(height: 6),
        for (final e in ev.where((e) => e.kind != EvKind.avoidFlags))
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text('${e.title} · ${e.sub}', style: const TextStyle(fontWeight: FontWeight.w500)),
              if (e.prayerId != null && Library.byId[e.prayerId] != null)
                TextButton(onPressed: () => _openPrayer(e.prayerId), child: Text('Read ${Library.byId[e.prayerId]!.en}')),
            ]),
          ),
        _pill(avoid ? 'Avoid hanging prayer flags' : 'No prayer-flag restriction', avoid),
      ]),
    );
  }

  Widget _section(String s) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 26, 16, 4),
        child: Text(s.toUpperCase(), style: TextStyle(fontSize: 12, letterSpacing: 0.8, color: Pal.of(context).muted)),
      );

  List<Widget> _upcoming(BuildContext context, Pal pal, {required bool festivalsOnly, required int max, required int span}) {
    final today = todayJd();
    final out = <Widget>[];
    for (var jd = today + 1; jd < today + span && out.length < max; jd++) {
      final ti = TibCal.info(jd);
      if (ti == null) continue;
      for (final e in eventsFor(ti)) {
        if (e.kind == EvKind.avoidFlags) continue;
        if (festivalsOnly && (e.kind != EvKind.festival || e.title.contains('day 2'))) continue;
        if (out.length >= max) break;
        final g = fromJd(jd);
        final days = jd - today;
        out.add(ListTile(
          dense: true,
          leading: SizedBox(
            width: 64,
            child: Text('${g.day} ${monthNames[g.month - 1].substring(0, 3)}\n${days == 1 ? 'tomorrow' : 'in $days days'}',
                style: TextStyle(fontSize: 12, color: pal.muted)),
          ),
          title: Text(e.title, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(e.sub),
          onTap: e.prayerId == null ? null : () => _openPrayer(e.prayerId),
        ));
      }
    }
    return out;
  }
}
