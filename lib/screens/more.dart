import 'package:flutter/material.dart';
import '../data/prayers.dart';
import '../data/store.dart';
import '../services/reminders.dart';
import '../theme.dart';
import 'deceased.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final pal = Pal.of(context);
    Widget tile(IconData i, String t, String s, Widget page) => ListTile(
          leading: Icon(i, color: pal.maroon),
          title: Text(t, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(s),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page)),
        );
    return SafeArea(
      child: ListView(children: [
        const FlagStripe(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Text('More', style: serif(context, 22, weight: FontWeight.w600)),
        ),
        tile(Icons.local_florist_outlined, '49 days of prayers', 'A day-by-day guide after someone passes away', const GuidesScreen()),
        tile(Icons.notifications_outlined, 'Reminders', 'Festivals, practice days and prayer-flag days', const ReminderScreen()),
        tile(Icons.info_outline, 'About and sources', 'Where the texts come from, and who made this app', const AboutScreen()),
      ]),
    );
  }
}

class ReminderScreen extends StatefulWidget {
  const ReminderScreen({super.key});
  @override
  State<ReminderScreen> createState() => _ReminderScreenState();
}

class _ReminderScreenState extends State<ReminderScreen> {
  String _note = '';

  Future<void> _changed() async {
    Store.i.saveReminders();
    setState(() {});
    if (Store.i.reminders.any) {
      final ok = await Reminders.requestPermission();
      if (!ok) setState(() => _note = 'Notifications are turned off for this app. Turn them on in your phone’s Settings to get reminders.');
    }
    await Reminders.reschedule();
  }

  @override
  Widget build(BuildContext context) {
    final r = Store.i.reminders;
    final pal = Pal.of(context);
    final time = TimeOfDay(hour: r.hour, minute: r.minute);
    return Scaffold(
      appBar: AppBar(title: const Text('Reminders')),
      body: ListView(children: [
        SwitchListTile(
          title: const Text('Great festivals'),
          subtitle: const Text('Losar, Saga Dawa, Chökhor Düchen, Lhabab Düchen and more'),
          value: r.festivals,
          onChanged: (v) {
            r.festivals = v;
            _changed();
          },
        ),
        SwitchListTile(
          title: const Text('Monthly practice days'),
          subtitle: const Text('8th, 10th, 15th, 25th and 30th of each Tibetan month'),
          value: r.practiceDays,
          onChanged: (v) {
            r.practiceDays = v;
            _changed();
          },
        ),
        SwitchListTile(
          title: const Text('Prayer-flag days'),
          subtitle: const Text('Days to avoid hanging prayer flags, and the Losar flag day'),
          value: r.flagDays,
          onChanged: (v) {
            r.flagDays = v;
            _changed();
          },
        ),
        SwitchListTile(
          title: const Text('49-day prayers'),
          subtitle: const Text('Each weekly day in your 49-day guides'),
          value: r.guides,
          onChanged: (v) {
            r.guides = v;
            _changed();
          },
        ),
        ListTile(
          title: const Text('Reminder time'),
          subtitle: Text(time.format(context)),
          trailing: const Icon(Icons.schedule),
          onTap: () async {
            final t = await showTimePicker(context: context, initialTime: time);
            if (t == null) return;
            r.hour = t.hour;
            r.minute = t.minute;
            _changed();
          },
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            _note.isNotEmpty ? _note : 'Reminders are set for the next 45 days and refreshed each time you open the app.',
            style: TextStyle(color: pal.muted, fontSize: 13),
          ),
        ),
      ]),
    );
  }
}

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final pal = Pal.of(context);
    final books = <String, int>{};
    for (final p in Library.all) {
      if (p.src != null) books[p.src!] = (books[p.src!] ?? 0) + 1;
    }
    final drafts = Library.all.where((p) => p.src == null).length;
    return Scaffold(
      appBar: AppBar(title: const Text('About and sources')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text('Tibetan Prayers', style: serif(context, 22, weight: FontWeight.w600)),
        Text('ཞལ་འདོན།', style: bo(context, 20, color: pal.maroon)),
        const SizedBox(height: 8),
        const Text('Developed by Tenzing Tsewang.'),
        const SizedBox(height: 4),
        Text('Free, with no advertising. Everything works without internet.', style: TextStyle(color: pal.muted)),
        const SizedBox(height: 20),
        Text('WHERE THE TEXTS COME FROM', style: TextStyle(fontSize: 12, letterSpacing: 0.8, color: pal.muted)),
        const SizedBox(height: 6),
        for (final e in books.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('• ${e.key}: ${e.value} ${e.value == 1 ? 'text' : 'texts'}'),
          ),
        Text('• $drafts texts have no printed source yet and are drafts to be checked.'),
        const SizedBox(height: 12),
        Text(
          'The Tibetan text of each prayer is taken from the book named on its page. The phonetics and English translations are drafts written for this app and still need checking by a teacher.',
          style: TextStyle(color: pal.muted),
        ),
        const SizedBox(height: 20),
        Text('CALENDAR', style: TextStyle(fontSize: 12, letterSpacing: 0.8, color: pal.muted)),
        const SizedBox(height: 6),
        const Text(
            'Tibetan dates use the Phugpa calculation followed by Men-Tsee-Khang, after Svante Janson’s “Tibetan calendar mathematics”. Prayer-flag days follow the traditional rule of avoided month and day pairs.'),
        const SizedBox(height: 20),
        Text('FONTS', style: TextStyle(fontSize: 12, letterSpacing: 0.8, color: pal.muted)),
        const SizedBox(height: 6),
        const Text('Jomolhari by Christopher J. Fynn, Noto Serif Tibetan by Google, and Spectral by Production Type, all under the SIL Open Font License.'),
      ]),
    );
  }
}
