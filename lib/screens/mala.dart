import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../data/prayers.dart';
import '../data/store.dart';
import '../services/native.dart';
import '../theme.dart';

const malaSize = 108;

class MalaScreen extends StatefulWidget {
  final bool active; // true while the Mala tab is showing
  const MalaScreen({super.key, required this.active});
  @override
  State<MalaScreen> createState() => _MalaScreenState();
}

class _MalaScreenState extends State<MalaScreen> {
  String _done = '';
  bool _armRestart = false;
  final _goal = TextEditingController();

  @override
  void initState() {
    super.initState();
    VolumeKeys.onKey = (_) => _count(1);
    Store.i.addListener(_refresh);
    _apply();
  }

  @override
  void didUpdateWidget(MalaScreen old) {
    super.didUpdateWidget(old);
    if (old.active != widget.active) _apply();
  }

  void _apply() {
    final on = widget.active;
    VolumeKeys.setActive(on && Store.i.mala.volumeKeys);
    on ? WakelockPlus.enable() : WakelockPlus.disable();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    VolumeKeys.setActive(false);
    Store.i.removeListener(_refresh);
    _goal.dispose();
    super.dispose();
  }

  List<_Mantra> get _mantras => [
        for (final p in Library.mantras) _Mantra(p.id, p.en.replaceAll(RegExp(r' Mantra.*$'), '').replaceAll(RegExp(r'\s*\(.*\)'), ''), p.lines.first.bo, p.lines.first.ph),
        _Mantra('other', 'Any other mantra', '', ''),
      ];

  void _count(int d) {
    if (!widget.active) return;
    final st = Store.i.mala;
    final c = st.of(st.current);
    if (d < 0) {
      if (c.total == 0) return;
      c.total--;
      c.dayCount = math.max(0, c.dayCount - 1);
      c.round = c.round > 0 ? c.round - 1 : malaSize - 1;
      _done = '';
    } else {
      c.total++;
      c.dayCount++;
      c.round++;
      if (c.round >= malaSize) {
        c.round = 0;
        _done = 'Mala ${_n(c.total ~/ malaSize)} complete';
        HapticFeedback.heavyImpact();
      } else {
        HapticFeedback.selectionClick();
        if (c.round > 3) _done = '';
      }
    }
    Store.i.saveMala();
  }

  String _n(int v) {
    // Indian grouping, as in 1,00,000
    final s = v.toString();
    if (s.length <= 3) return s;
    final last3 = s.substring(s.length - 3);
    var rest = s.substring(0, s.length - 3);
    final parts = <String>[];
    while (rest.length > 2) {
      parts.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) parts.insert(0, rest);
    return '${parts.join(',')},$last3';
  }

  @override
  Widget build(BuildContext context) {
    final pal = Pal.of(context);
    final st = Store.i.mala;
    final list = _mantras;
    if (!list.any((x) => x.id == st.current)) st.current = list.first.id;
    final cur = list.firstWhere((x) => x.id == st.current);
    final c = st.of(cur.id);
    if (_goal.text != '${c.goal}' && !FocusScope.of(context).hasFocus) _goal.text = '${c.goal}';
    final pct = math.min(100.0, c.total / c.goal * 100);

    return SafeArea(
      child: ListView(padding: EdgeInsets.zero, children: [
        const FlagStripe(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          child: Row(children: [
            Expanded(child: Text('Mala Counter', style: serif(context, 22, weight: FontWeight.w600))),
            Text('ཕྲེང་བ།', style: bo(context, 20, color: pal.maroon)),
          ]),
        ),
        SizedBox(
          height: 48,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), children: [
            for (final x in list)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(x.name, style: TextStyle(color: x.id == cur.id ? pal.surface : pal.ink)),
                  selected: x.id == cur.id,
                  showCheckmark: false,
                  onSelected: (_) {
                    st.current = x.id;
                    _done = '';
                    Store.i.saveMala();
                  },
                ),
              ),
          ]),
        ),
        SizedBox(
          height: 80,
          child: Center(
            child: cur.bo.isEmpty
                ? Text('Count any mantra or prayer you are reciting.', style: serif(context, 15, italic: true, color: pal.saffron))
                : Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(cur.bo, style: bo(context, 24, color: pal.maroon), textAlign: TextAlign.center),
                    Text(cur.ph, style: serif(context, 15, italic: true, color: pal.saffron), textAlign: TextAlign.center),
                  ]),
          ),
        ),
        Center(
          child: Semantics(
            button: true,
            label: 'Count one bead',
            child: GestureDetector(
              onTapDown: (_) => _count(1),
              child: SizedBox(
                width: 320,
                height: 320,
                child: CustomPaint(
                  painter: _BeadRing(c.round, pal),
                  child: Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text('${c.round}', style: serif(context, 64, weight: FontWeight.w600)),
                      Text('of $malaSize · tap to count', style: TextStyle(fontSize: 13, color: pal.muted)),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
        SizedBox(
          height: 26,
          child: Center(child: Text(_done, style: TextStyle(fontWeight: FontWeight.w600, color: pal.maroon))),
        ),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          OutlinedButton(onPressed: () => _count(-1), child: const Text('− Undo')),
          const SizedBox(width: 10),
          OutlinedButton(
            onPressed: () {
              if (!_armRestart) {
                setState(() => _armRestart = true);
                Future.delayed(const Duration(seconds: 3), () {
                  if (mounted) setState(() => _armRestart = false);
                });
                return;
              }
              c.round = 0;
              _armRestart = false;
              Store.i.saveMala();
            },
            child: Text(_armRestart ? 'Tap again to restart' : 'Restart round'),
          ),
        ]),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
          child: Row(children: [
            _stat('Today', _n(c.dayCount), pal),
            const SizedBox(width: 8),
            _stat('Malas', _n(c.total ~/ malaSize), pal),
            const SizedBox(width: 8),
            _stat('All time', _n(c.total), pal),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('Goal', style: TextStyle(color: pal.muted, fontSize: 13)),
              const Spacer(),
              Text('${_n(c.total)} of ${_n(c.goal)} · ${pct < 1 && c.total > 0 ? pct.toStringAsFixed(2) : pct.floor()}%',
                  style: TextStyle(color: pal.muted, fontSize: 13)),
            ]),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(value: pct / 100, minHeight: 10, backgroundColor: pal.chip, color: pal.maroon),
            ),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
              SizedBox(
                width: 120,
                child: TextField(
                  controller: _goal,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Target', isDense: true, border: OutlineInputBorder()),
                  onSubmitted: (v) {
                    c.goal = math.max(108, int.tryParse(v) ?? 108);
                    Store.i.saveMala();
                  },
                ),
              ),
              for (final g in const [10000, 100000, 1000000])
                ActionChip(
                  label: Text(g == 1000000 ? '10 lakh' : g == 100000 ? '1 lakh' : '10,000'),
                  onPressed: () {
                    c.goal = g;
                    _goal.text = '$g';
                    Store.i.saveMala();
                  },
                ),
            ]),
          ]),
        ),
        SwitchListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          title: const Text('Count with the volume buttons'),
          subtitle: const Text('Either volume button counts one bead while this screen is open.'),
          value: st.volumeKeys,
          onChanged: (v) {
            st.volumeKeys = v;
            Store.i.saveMala();
            _apply();
          },
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 30),
          child: Text('Counts are kept on this phone. The screen stays on while you count.', style: TextStyle(fontSize: 12, color: pal.muted)),
        ),
      ]),
    );
  }

  Widget _stat(String k, String v, Pal pal) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(color: pal.surface, border: Border.all(color: pal.line), borderRadius: BorderRadius.circular(10)),
          child: Column(children: [
            Text(k.toUpperCase(), style: TextStyle(fontSize: 11, letterSpacing: 0.6, color: pal.muted)),
            Text(v, style: serif(context, 20, weight: FontWeight.w600)),
          ]),
        ),
      );
}

class _Mantra {
  final String id, name, bo, ph;
  _Mantra(this.id, this.name, this.bo, this.ph);
}

class _BeadRing extends CustomPainter {
  final int round;
  final Pal pal;
  _BeadRing(this.round, this.pal);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 18;
    canvas.drawCircle(c, r - 22, Paint()..color = pal.surface);
    for (var i = 0; i < malaSize; i++) {
      final a = -math.pi / 2 + (i + 0.5) / malaSize * math.pi * 2;
      final p = c + Offset(r * math.cos(a), r * math.sin(a));
      final marker = (i + 1) % 27 == 0;
      canvas.drawCircle(p, marker ? 5.2 : 3.9, Paint()..color = i < round ? pal.maroon : pal.line);
      if (marker) {
        canvas.drawCircle(p, 5.2, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = pal.saffron);
      }
    }
    final top = c + Offset(0, -r - 2);
    canvas.drawCircle(top, 8, Paint()..color = pal.saffron);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: top + const Offset(0, -12), width: 8, height: 8), const Radius.circular(2)),
        Paint()..color = pal.saffron);
  }

  @override
  bool shouldRepaint(_BeadRing old) => old.round != round || old.pal != pal;
}
