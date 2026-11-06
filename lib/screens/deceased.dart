import 'package:flutter/material.dart';
import '../data/prayers.dart';
import '../data/store.dart';
import '../data/tibcal.dart';
import '../services/reminders.dart';
import '../theme.dart';
import 'reader.dart';

/// Prayers often recited for the dead during the 49 days.
const guidePrayers = [
  'dewachen-short', 'samantabhadra-dedication', 'om-mani', 'medicine-buddha-praise', 'heart-sutra', 'dedication', 'twenty-one-taras'
];

String fmtDate(DateTime d) => '${weekdayNames[d.weekday - 1]} ${d.day} ${monthNames[d.month - 1]} ${d.year}';

class GuidesScreen extends StatefulWidget {
  const GuidesScreen({super.key});
  @override
  State<GuidesScreen> createState() => _GuidesScreenState();
}

class _GuidesScreenState extends State<GuidesScreen> {
  Future<void> _add() async {
    final name = TextEditingController();
    DateTime date = DateTime.now();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setLocal) => AlertDialog(
          title: const Text('New 49-day guide'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Name (optional)')),
            const SizedBox(height: 14),
            const Text('Date of passing'),
            TextButton.icon(
              icon: const Icon(Icons.event),
              label: Text(fmtDate(date)),
              onPressed: () async {
                final d = await showDatePicker(
                  context: c,
                  initialDate: date,
                  firstDate: DateTime.now().subtract(const Duration(days: 120)),
                  lastDate: DateTime.now(),
                );
                if (d != null) setLocal(() => date = d);
              },
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Start guide')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final g = Guide(DateTime.now().millisecondsSinceEpoch.toString(), name.text.trim(), date, true, <String>{});
    Store.i.guides.insert(0, g);
    Store.i.saveGuides();
    Reminders.reschedule();
    if (!mounted) return;
    setState(() {});
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => GuideScreen(g)));
  }

  @override
  Widget build(BuildContext context) {
    final pal = Pal.of(context);
    final gs = Store.i.guides;
    return Scaffold(
      appBar: AppBar(title: const Text('49 days of prayers')),
      floatingActionButton: FloatingActionButton.extended(onPressed: _add, icon: const Icon(Icons.add), label: const Text('New guide')),
      body: ListView(padding: const EdgeInsets.only(bottom: 90), children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'After a death, families recite prayers every day for 49 days, with special prayers each week. This guide counts the days, shows the weekly days, and lists prayers commonly recited. Customs differ between families and monasteries, so ask your lama about the rites for your family.',
            style: TextStyle(color: pal.muted),
          ),
        ),
        if (gs.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text('No guides yet. Tap “New guide” to start one.', textAlign: TextAlign.center, style: TextStyle(color: pal.muted)),
          ),
        for (final g in gs)
          ListTile(
            title: Text(g.name.isEmpty ? 'Guide from ${fmtDate(g.passed)}' : g.name, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(g.finished ? 'Completed the 49 days' : 'Day ${g.dayNumber(DateTime.now()).clamp(1, 49)} of 49'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              await Navigator.of(context).push(MaterialPageRoute(builder: (_) => GuideScreen(g)));
              setState(() {});
            },
          ),
      ]),
    );
  }
}

class GuideScreen extends StatefulWidget {
  final Guide g;
  const GuideScreen(this.g, {super.key});
  @override
  State<GuideScreen> createState() => _GuideScreenState();
}

class _GuideScreenState extends State<GuideScreen> {
  Guide get g => widget.g;

  Future<void> _delete() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete this guide?'),
        content: const Text('Its reminders and ticked days will be removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
        ],
      ),
    );
    if (yes != true) return;
    Store.i.guides.removeWhere((x) => x.id == g.id);
    Store.i.saveGuides();
    Reminders.reschedule();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final pal = Pal.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final n = g.dayNumber(today);
    final week = ((n - 1) ~/ 7 + 1).clamp(1, 7);
    final todayKey = dayKey(today);
    final doneToday = g.doneDays.contains(todayKey);
    final t = TibCal.forDate(g.passed);
    return Scaffold(
      appBar: AppBar(
        title: Text(g.name.isEmpty ? '49 days of prayers' : g.name),
        actions: [IconButton(tooltip: 'Delete guide', onPressed: _delete, icon: const Icon(Icons.delete_outline))],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: pal.surface, border: Border.all(color: pal.line), borderRadius: BorderRadius.circular(12)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              n > 49 ? 'The 49 days are complete' : 'Day $n of 49 · week $week',
              style: serif(context, 22, weight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text('Passed away ${fmtDate(g.passed)}${t != null ? ' (${tibLabel(t).en})' : ''}', style: TextStyle(color: pal.muted)),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(value: (n.clamp(0, 49)) / 49, minHeight: 8, backgroundColor: pal.chip, color: pal.maroon),
            ),
            if (n <= 49) ...[
              const SizedBox(height: 12),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: doneToday,
                title: const Text('Prayers done today'),
                onChanged: (v) {
                  v == true ? g.doneDays.add(todayKey) : g.doneDays.remove(todayKey);
                  Store.i.saveGuides();
                  setState(() {});
                },
              ),
              Text('${g.doneDays.length} of ${n.clamp(1, 49)} days ticked so far', style: TextStyle(color: pal.muted, fontSize: 13)),
            ],
          ]),
        ),
        const SizedBox(height: 18),
        Text('THE SEVEN WEEKLY DAYS', style: TextStyle(fontSize: 12, letterSpacing: 0.8, color: pal.muted)),
        Text('On the same weekday as the passing, for seven weeks.', style: TextStyle(fontSize: 13, color: pal.muted)),
        for (var w = 1; w <= 7; w++)
          Builder(builder: (_) {
            final d = g.weekDate(w);
            final past = d.isBefore(today);
            final isToday = d == today;
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: isToday ? pal.maroon : (past ? pal.chip : pal.surface),
                foregroundColor: isToday ? pal.surface : pal.ink,
                child: Text('$w'),
              ),
              title: Text(w == 7 ? 'The 49th day' : 'Week $w', style: TextStyle(fontWeight: isToday ? FontWeight.w700 : FontWeight.w500)),
              subtitle: Text('${fmtDate(d)}${isToday ? ' · today' : ''}'),
            );
          }),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Remind me on each weekly day'),
          value: g.remind,
          onChanged: (v) {
            g.remind = v;
            Store.i.saveGuides();
            Reminders.reschedule();
            setState(() {});
          },
        ),
        const SizedBox(height: 10),
        Text('PRAYERS OFTEN RECITED', style: TextStyle(fontSize: 12, letterSpacing: 0.8, color: pal.muted)),
        for (final id in guidePrayers)
          if (Library.byId[id] != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(Library.byId[id]!.en),
              subtitle: Text(Library.byId[id]!.bo, style: bo(context, 16, color: pal.muted)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReaderScreen(Library.byId[id]!))),
            ),
        const SizedBox(height: 16),
        Text(
          'Customs vary: some families count the first week from the day of passing, others hold the rites on different days. Follow the advice of your lama or monastery.',
          style: TextStyle(fontSize: 12, color: pal.muted),
        ),
      ]),
    );
  }
}
