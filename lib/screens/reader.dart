import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../data/prayers.dart';
import '../data/store.dart';
import '../main.dart' show Shell;
import '../theme.dart';

class ReaderScreen extends StatefulWidget {
  final Prayer p;
  const ReaderScreen(this.p, {super.key});
  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  Prayer get p => widget.p;
  final _scroll = ScrollController();
  late final List<GlobalKey> _keys = List.generate(p.lines.length, (_) => GlobalKey());
  Timer? _auto;
  final _player = AudioPlayer();
  StreamSubscription<Duration>? _posSub;
  Duration _pos = Duration.zero, _dur = Duration.zero;
  bool _playing = false, _loop = false;
  double _rate = 1;
  int _now = -1;
  List<double?>? _marking; // while marking line timing
  int _next = 0;
  String _msg = '';

  Recording? get rec => Store.i.recordings[p.id];

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    Store.i.addListener(_refresh);
    _player.playerStateStream.listen((s) {
      if (!mounted) return;
      setState(() => _playing = s.playing && s.processingState != ProcessingState.completed);
      if (s.processingState == ProcessingState.completed && !_loop) {
        _player.pause();
        _player.seek(Duration.zero);
      }
    });
    _player.durationStream.listen((d) {
      if (mounted) setState(() => _dur = d ?? Duration.zero);
    });
    _posSub = _player.positionStream.listen(_onPos);
    _loadAudio();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _loadAudio() async {
    final r = rec;
    if (r == null) return;
    try {
      if (!File(r.path).existsSync()) {
        setState(() => _msg = 'The recording file is missing. Please add it again.');
        return;
      }
      await _player.setFilePath(r.path);
    } catch (_) {
      if (mounted) setState(() => _msg = 'This recording can’t be played. Try an M4A or MP3 file.');
    }
  }

  void _onPos(Duration d) {
    if (!mounted) return;
    setState(() => _pos = d);
    final r = rec;
    if (_marking != null || r == null || !r.hasTimes) return;
    final t = d.inMilliseconds / 1000;
    var idx = -1;
    for (var i = 0; i < r.times.length; i++) {
      final ti = r.times[i];
      if (ti != null && ti <= t + 0.05) idx = i;
    }
    if (idx != _now) {
      setState(() => _now = idx);
      if (idx >= 0 && _playing) _showLine(idx);
    }
  }

  void _showLine(int i) {
    final c = _keys[i].currentContext;
    if (c != null) Scrollable.ensureVisible(c, alignment: 0.35, duration: const Duration(milliseconds: 400));
  }

  @override
  void dispose() {
    _auto?.cancel();
    _posSub?.cancel();
    _player.dispose();
    _scroll.dispose();
    Store.i.removeListener(_refresh);
    WakelockPlus.disable();
    super.dispose();
  }

  // ---- auto-scroll ----
  void _toggleAuto() {
    if (_auto != null) return _stopAuto();
    _auto = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!_scroll.hasClients) return;
      final px = 0.1 + Store.i.scrollSpeed * 0.1;
      final max = _scroll.position.maxScrollExtent;
      final next = math.min(_scroll.offset + px, max);
      _scroll.jumpTo(next);
      if (next >= max) _stopAuto();
    });
    setState(() {});
  }

  void _stopAuto() {
    _auto?.cancel();
    _auto = null;
    if (mounted) setState(() {});
  }

  // ---- recordings ----
  Future<void> _pickRecording() async {
    try {
      final res = await FilePicker.platform.pickFiles(type: FileType.audio);
      final f = res?.files.single;
      if (f == null || f.path == null) return;
      final dir = await getApplicationDocumentsDirectory();
      final folder = Directory('${dir.path}/recordings');
      await folder.create(recursive: true);
      final ext = f.name.contains('.') ? f.name.split('.').last : 'm4a';
      final dest = '${folder.path}/${p.id}-${DateTime.now().millisecondsSinceEpoch}.$ext';
      await File(f.path!).copy(dest);
      final old = rec;
      Store.i.setRecording(p.id, Recording(dest, f.name, const []));
      if (old != null && old.path != dest) {
        try {
          File(old.path).deleteSync();
        } catch (_) {}
      }
      setState(() {
        _msg = 'Recording added.';
        _now = -1;
      });
      await _loadAudio();
    } catch (e) {
      setState(() => _msg = 'Couldn’t add that file. Please try another recording.');
    }
  }

  Future<void> _removeRecording() async {
    final r = rec;
    if (r == null) return;
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Remove recording?'),
        content: const Text('The recording and its line timing will be removed from this prayer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Remove')),
        ],
      ),
    );
    if (yes != true) return;
    await _player.stop();
    try {
      File(r.path).deleteSync();
    } catch (_) {}
    Store.i.setRecording(p.id, null);
    setState(() {
      _msg = 'Recording removed.';
      _now = -1;
    });
  }

  void _startMarking() {
    _stopAuto();
    setState(() {
      _marking = List<double?>.filled(p.lines.length, null);
      _next = 0;
      _now = -1;
    });
    _player.seek(Duration.zero);
    _player.play();
    _scroll.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  void _markLine(int i) {
    final m = _marking!;
    m[i] = (_player.position.inMilliseconds / 1000);
    for (var k = i + 1; k < m.length; k++) {
      m[k] = null;
    }
    setState(() {
      _next = i + 1;
      _now = i;
    });
    if (i + 1 < p.lines.length) _showLine(i + 1);
  }

  void _undoMark() {
    final m = _marking!;
    final k = _next - 1;
    if (k < 0) return;
    m[k] = null;
    final prev = k > 0 ? m[k - 1] : 0.0;
    _player.seek(Duration(milliseconds: ((prev ?? 0) * 1000).round()));
    setState(() => _next = k);
  }

  void _endMarking(bool save) {
    final m = _marking;
    _player.pause();
    setState(() {
      _marking = null;
      _now = -1;
    });
    if (save && m != null && rec != null) {
      Store.i.setRecording(p.id, rec!.withTimes(m));
      setState(() => _msg = 'Timing saved. Lines will light up as the recording plays.');
    }
  }

  String _fmt(Duration d) => '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final pal = Pal.of(context);
    final s = Store.i;
    final saved = s.saved.contains(p.id);
    final scale = s.textScale;
    var vn = 0;
    String numberOf(int i) {
      if (p.verse) return p.lines[i].bo.contains('\n') ? '${++vn}' : '';
      return p.lines.length > 1 ? '${i + 1}' : '';
    }

    final trads = [...p.occ, ...p.deity.where((d) => d != 'Buddha'), ...p.trad];
    return Scaffold(
      appBar: AppBar(
        title: Text(p.en, overflow: TextOverflow.ellipsis, style: serif(context, 18, weight: FontWeight.w600)),
        actions: [
          IconButton(
            tooltip: saved ? 'Remove from saved' : 'Save',
            icon: Icon(saved ? Icons.bookmark : Icons.bookmark_border, color: saved ? pal.maroon : null),
            onPressed: () => s.toggleSaved(p.id),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Row(children: [
              _toggle('བོད', s.showBo, () => s.setLayers(bo: !s.showBo), tibetan: true),
              _toggle('Phonetic', s.showPh, () => s.setLayers(ph: !s.showPh)),
              _toggle('English', s.showEn, () => s.setLayers(en: !s.showEn)),
              const SizedBox(width: 10),
              IconButton.outlined(tooltip: 'Smaller text', onPressed: () => s.setTextScale(scale - 0.1), icon: const Text('A−')),
              IconButton.outlined(tooltip: 'Larger text', onPressed: () => s.setTextScale(scale + 0.1), icon: const Text('A+')),
            ]),
          ),
        ),
      ),
      body: NotificationListener<UserScrollNotification>(
        onNotification: (n) {
          if (_auto != null && n.direction != ScrollDirection.idle) _stopAuto();
          return false;
        },
        child: SingleChildScrollView(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 160),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.bo, style: bo(context, 28 * scale, color: pal.maroon)),
            Text(p.en, style: serif(context, 22, weight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(p.about, style: serif(context, 15, color: pal.muted)),
            const SizedBox(height: 10),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final t in trads)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(color: pal.chip, borderRadius: BorderRadius.circular(99)),
                  child: Text(t, style: const TextStyle(fontSize: 12)),
                ),
            ]),
            const SizedBox(height: 12),
            _recordingRow(pal),
            if (p.isMantra)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.blur_circular, size: 18),
                  label: const Text('Count on mala'),
                  onPressed: () {
                    s.mala.current = p.id;
                    s.saveMala();
                    Shell.tab.value = 2;
                    Navigator.of(context).popUntil((r) => r.isFirst);
                  },
                ),
              ),
            const SizedBox(height: 16),
            for (var i = 0; i < p.lines.length; i++) _line(context, i, numberOf(i), pal, scale),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(border: Border.all(color: pal.line), borderRadius: BorderRadius.circular(8)),
              child: Text(
                p.src != null
                    ? 'Tibetan text from the ${p.src}. The phonetics and English are drafts to be checked.'
                    : 'Draft text for checking. Please compare the Tibetan, phonetics and translation with a trusted printed edition.',
                style: TextStyle(fontSize: 13, color: pal.muted),
              ),
            ),
          ]),
        ),
      ),
      bottomNavigationBar: _dock(pal),
    );
  }

  Widget _toggle(String label, bool on, VoidCallback tap, {bool tibetan = false}) => Padding(
        padding: const EdgeInsets.only(right: 6),
        child: FilterChip(
          label: Text(label, style: tibetan ? const TextStyle(fontFamily: 'Jomolhari') : null),
          selected: on,
          showCheckmark: false,
          onSelected: (_) => tap(),
        ),
      );

  Widget _recordingRow(Pal pal) {
    final r = rec;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
        Text(r == null ? 'No recording yet.' : 'Recording: ${r.name}', style: TextStyle(color: pal.muted, fontSize: 13)),
        OutlinedButton(onPressed: _marking == null ? _pickRecording : null, child: Text(r == null ? '+ Add recording' : 'Replace')),
        if (r != null) OutlinedButton(onPressed: _marking == null ? _removeRecording : null, child: const Text('Remove')),
        if (r != null && _marking == null)
          OutlinedButton(onPressed: _startMarking, child: Text(r.hasTimes ? 'Redo line timing' : 'Mark line timing')),
      ]),
      if (_msg.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(_msg, style: TextStyle(color: pal.muted, fontSize: 13))),
    ]);
  }

  Widget _line(BuildContext context, int i, String n, Pal pal, double scale) {
    final l = p.lines[i];
    final s = Store.i;
    final now = i == _now;
    final isNext = _marking != null && i == _next;
    final mt = _marking?[i];
    final r = rec;
    return GestureDetector(
      key: _keys[i],
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (_marking != null) return _markLine(i);
        final t = (r != null && r.hasTimes && i < r.times.length) ? r.times[i] : null;
        if (t != null) {
          _player.seek(Duration(milliseconds: (t * 1000).round()));
          _player.play();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: now ? pal.saffron.withOpacity(0.14) : null,
          borderRadius: BorderRadius.circular(6),
          border: isNext ? Border.all(color: pal.saffron, width: 2) : Border(top: BorderSide(color: pal.line)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 30,
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(children: [
                Text(n, style: TextStyle(fontSize: 12, color: now ? pal.maroon : pal.muted, fontWeight: now ? FontWeight.w600 : null)),
                if (mt != null) Text(_fmt(Duration(milliseconds: (mt * 1000).round())), style: TextStyle(fontSize: 10, color: pal.saffron)),
              ]),
            ),
          ),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (s.showBo) Text(l.bo, style: bo(context, (p.isMantra ? 32 : 26) * scale)),
              if (s.showPh) Text(l.ph, style: serif(context, 17 * scale, italic: true, color: pal.saffron)),
              if (s.showEn) Text(l.en, style: serif(context, 16 * scale, color: pal.muted)),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _dock(Pal pal) {
    final r = rec;
    final s = Store.i;
    return Material(
      color: pal.surface,
      elevation: 6,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (r != null && _marking == null)
              Row(children: [
                FilledButton(
                  onPressed: () => _playing ? _player.pause() : _player.play(),
                  child: Text(_playing ? '❚❚ Pause' : '▶ Listen'),
                ),
                Expanded(
                  child: Slider(
                    value: _dur.inMilliseconds == 0 ? 0 : (_pos.inMilliseconds / _dur.inMilliseconds).clamp(0.0, 1.0),
                    onChanged: _dur.inMilliseconds == 0
                        ? null
                        : (v) => _player.seek(Duration(milliseconds: (v * _dur.inMilliseconds).round())),
                  ),
                ),
                Text('${_fmt(_pos)} / ${_fmt(_dur)}', style: TextStyle(fontSize: 12, color: pal.muted)),
                TextButton(
                  onPressed: () {
                    const rates = [0.75, 1.0, 1.25, 1.5];
                    _rate = rates[(rates.indexOf(_rate) + 1) % rates.length];
                    _player.setSpeed(_rate);
                    setState(() {});
                  },
                  child: Text('${_rate}×'),
                ),
                IconButton(
                  tooltip: 'Repeat',
                  isSelected: _loop,
                  icon: const Icon(Icons.repeat),
                  selectedIcon: Icon(Icons.repeat_on, color: pal.maroon),
                  onPressed: () {
                    _loop = !_loop;
                    _player.setLoopMode(_loop ? LoopMode.one : LoopMode.off);
                    setState(() {});
                  },
                ),
              ]),
            if (_marking != null)
              Row(children: [
                Expanded(
                  child: Text(
                    _next == 0 ? 'Tap each line the moment it starts.' : 'Marked $_next of ${p.lines.length}. Tap each line as it starts.',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                TextButton(onPressed: _undoMark, child: const Text('Undo')),
                TextButton(onPressed: () => _endMarking(false), child: const Text('Cancel')),
                FilledButton(onPressed: () => _endMarking(true), child: const Text('Save')),
              ])
            else
              Row(children: [
                Text('Auto-scroll', style: TextStyle(color: pal.muted, fontSize: 13)),
                const Spacer(),
                IconButton(tooltip: 'Slower', onPressed: () => s.setScrollSpeed(s.scrollSpeed - 1), icon: const Icon(Icons.remove)),
                Text('Speed ${s.scrollSpeed}', style: TextStyle(fontSize: 12, color: pal.muted)),
                IconButton(tooltip: 'Faster', onPressed: () => s.setScrollSpeed(s.scrollSpeed + 1), icon: const Icon(Icons.add)),
                FilledButton.tonal(onPressed: _toggleAuto, child: Text(_auto != null ? '❚❚ Pause' : '▶ Scroll')),
              ]),
          ]),
        ),
      ),
    );
  }
}
