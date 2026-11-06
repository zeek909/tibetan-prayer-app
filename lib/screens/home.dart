import 'package:flutter/material.dart';
import '../data/prayers.dart';
import '../data/search.dart';
import '../data/store.dart';
import '../theme.dart';
import 'reader.dart';

class PrayersScreen extends StatefulWidget {
  const PrayersScreen({super.key});
  @override
  State<PrayersScreen> createState() => _PrayersScreenState();
}

enum _Tab { occasion, deity, tradition, saved }

class _PrayersScreenState extends State<PrayersScreen> {
  final _q = TextEditingController();
  _Tab tab = _Tab.occasion;
  final Map<_Tab, String?> pick = {};

  @override
  void initState() {
    super.initState();
    Store.i.addListener(_refresh);
  }

  @override
  void dispose() {
    Store.i.removeListener(_refresh);
    _q.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  List<String> _options() => switch (tab) {
        _Tab.occasion => Browse.occasions,
        _Tab.deity => Browse.deities,
        _Tab.tradition => Browse.traditions,
        _Tab.saved => const [],
      };

  List<String> _field(Prayer p) => switch (tab) {
        _Tab.occasion => p.occ,
        _Tab.deity => p.deity,
        _Tab.tradition => p.trad,
        _Tab.saved => const [],
      };

  @override
  Widget build(BuildContext context) {
    final pal = Pal.of(context);
    final query = _q.text.trim();
    List<Widget> body;
    if (query.isNotEmpty) {
      final hits = search(query);
      body = [
        _count('${hits.length} ${hits.length == 1 ? 'result' : 'results'} for “$query”'),
        if (hits.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Text('Nothing found. Try a few syllables like “jangchub”, a word like “compassion”, or Tibetan script.',
                textAlign: TextAlign.center, style: TextStyle(color: pal.muted)),
          ),
        for (final h in hits) PrayerTile(h.prayer, snippet: hitSnippet(h.prayer, h.line, query)),
      ];
    } else {
      List<Prayer> list;
      Widget chips = const SizedBox.shrink();
      if (tab == _Tab.saved) {
        list = Library.all.where((p) => Store.i.saved.contains(p.id)).toList();
      } else {
        final opts = _options();
        var cur = pick[tab];
        if (cur != null && !Library.all.any((p) => _field(p).contains(cur))) cur = null;
        list = cur == null ? Library.all : Library.all.where((p) => _field(p).contains(cur)).toList();
        chips = SizedBox(
          height: 46,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            children: [
              _chip('All', cur == null, () => setState(() => pick[tab] = null)),
              for (final o in opts)
                if (Library.all.any((p) => _field(p).contains(o)))
                  _chip(tab == _Tab.deity ? '$o  ${Browse.deityBo[o] ?? ''}' : o, cur == o, () => setState(() => pick[tab] = o)),
            ],
          ),
        );
      }
      body = [
        chips,
        _count(tab == _Tab.saved
            ? (list.isEmpty ? '' : '${list.length} saved')
            : '${list.length} ${list.length == 1 ? 'text' : 'texts'}'),
        if (tab == _Tab.saved && list.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Text('Tap the bookmark while reading a prayer to keep it here for your daily practice.',
                textAlign: TextAlign.center, style: TextStyle(color: pal.muted)),
          ),
        for (final p in list) PrayerTile(p),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
          child: Text(
            '${Library.all.length} texts. ${Library.all.where((p) => p.src != null).length} follow a printed prayer book; the rest are drafts to be checked. Phonetics and English are drafts.',
            style: TextStyle(color: pal.muted, fontSize: 12),
          ),
        ),
      ];
    }

    return SafeArea(
      child: CustomScrollView(slivers: [
        SliverToBoxAdapter(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const FlagStripe(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Expanded(child: Text('Tibetan Prayers', style: serif(context, 22, weight: FontWeight.w600))),
                Text('ཞལ་འདོན།', style: bo(context, 20, color: pal.maroon)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _q,
                onChanged: (_) => setState(() {}),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search in Tibetan, phonetics or English',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _q.text.isEmpty
                      ? null
                      : IconButton(icon: const Icon(Icons.close), tooltip: 'Clear', onPressed: () => setState(_q.clear)),
                  filled: true,
                  fillColor: pal.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: pal.line)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: pal.line)),
                ),
              ),
            ),
            if (query.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: SegmentedButton<_Tab>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: _Tab.occasion, label: Text('Occasion')),
                    ButtonSegment(value: _Tab.deity, label: Text('Deity')),
                    ButtonSegment(value: _Tab.tradition, label: Text('Tradition')),
                    ButtonSegment(value: _Tab.saved, label: Text('Saved')),
                  ],
                  selected: {tab},
                  onSelectionChanged: (s) => setState(() => tab = s.first),
                  style: ButtonStyle(visualDensity: VisualDensity.compact, textStyle: WidgetStatePropertyAll(const TextStyle(fontSize: 13))),
                ),
              ),
          ]),
        ),
        SliverList(delegate: SliverChildListDelegate(body)),
      ]),
    );
  }

  Widget _count(String s) => s.isEmpty
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: Text(s, style: TextStyle(color: Pal.of(context).muted, fontSize: 13)),
        );

  Widget _chip(String label, bool on, VoidCallback tap) {
    final pal = Pal.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label, style: TextStyle(color: on ? pal.surface : pal.ink, fontFamilyFallback: const ['Jomolhari'])),
        selected: on,
        showCheckmark: false,
        onSelected: (_) => tap(),
      ),
    );
  }
}

class PrayerTile extends StatelessWidget {
  final Prayer p;
  final String snippet;
  const PrayerTile(this.p, {super.key, this.snippet = ''});

  @override
  Widget build(BuildContext context) {
    final pal = Pal.of(context);
    final rec = Store.i.recordings.containsKey(p.id);
    final trads = p.trad.where((t) => t != 'All traditions');
    return InkWell(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReaderScreen(p))),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: pal.line))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.bo, style: bo(context, 20)),
              Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, runSpacing: 4, children: [
                Text(p.en, style: serif(context, 16)),
                for (final t in trads)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                    decoration: BoxDecoration(color: pal.maroon.withOpacity(0.12), borderRadius: BorderRadius.circular(99)),
                    child: Text(t, style: TextStyle(fontSize: 11, color: pal.maroon)),
                  ),
              ]),
              if (snippet.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(snippet, style: TextStyle(fontSize: 13, color: pal.muted, fontFamilyFallback: const ['Jomolhari'])),
                ),
            ]),
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(border: Border.all(color: pal.line), borderRadius: BorderRadius.circular(4)),
              child: Text(p.kind.toUpperCase(), style: TextStyle(fontSize: 10, letterSpacing: 0.6, color: pal.muted)),
            ),
            const SizedBox(height: 4),
            Text('${p.unitLabel()}${rec ? ' ♪' : ''}', style: TextStyle(fontSize: 12, color: pal.muted)),
          ]),
        ]),
      ),
    );
  }
}
