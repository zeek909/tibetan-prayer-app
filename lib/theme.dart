import 'package:flutter/material.dart';

/// Palette: maroon robes and saffron, on warm paper in light mode, butter-lamp dark at night.
class Pal {
  final Color bg, surface, ink, muted, line, maroon, saffron, chip, ok, okBg, fix, fixBg, warnBg;
  const Pal({
    required this.bg, required this.surface, required this.ink, required this.muted, required this.line,
    required this.maroon, required this.saffron, required this.chip, required this.ok, required this.okBg,
    required this.fix, required this.fixBg, required this.warnBg,
  });
  static const light = Pal(
    bg: Color(0xFFF6F4EF), surface: Color(0xFFFFFDF8), ink: Color(0xFF231C1A), muted: Color(0xFF6D625C),
    line: Color(0xFFE3DDD2), maroon: Color(0xFF7A1F2B), saffron: Color(0xFFC9850F), chip: Color(0xFFEFE9DD),
    ok: Color(0xFF2F7A48), okBg: Color(0xFFE3F1E6), fix: Color(0xFFB23A2C), fixBg: Color(0xFFF8E4E0), warnBg: Color(0xFFFBF1DC),
  );
  static const dark = Pal(
    bg: Color(0xFF17130F), surface: Color(0xFF211B16), ink: Color(0xFFEFE6D6), muted: Color(0xFFA89A88),
    line: Color(0xFF3A3128), maroon: Color(0xFFE08A8F), saffron: Color(0xFFF0B44A), chip: Color(0xFF2C241D),
    ok: Color(0xFF7FD19A), okBg: Color(0xFF1D3324), fix: Color(0xFFF19A8D), fixBg: Color(0xFF3A1F1A), warnBg: Color(0xFF33291A),
  );
  static Pal of(BuildContext c) => Theme.of(c).brightness == Brightness.dark ? dark : light;
}

const flagColors = [Color(0xFF2F5FA8), Color(0xFFF1EFE8), Color(0xFFB8322C), Color(0xFF2F8A4D), Color(0xFFE3B21C)];

TextStyle bo(BuildContext c, double size, {Color? color}) => TextStyle(
      fontFamily: 'Jomolhari',
      fontFamilyFallback: const ['NotoSerifTibetan'],
      fontSize: size,
      height: 1.65,
      color: color ?? Pal.of(c).ink,
    );

TextStyle serif(BuildContext c, double size, {Color? color, bool italic = false, FontWeight? weight}) => TextStyle(
      fontFamily: 'Spectral',
      fontSize: size,
      height: 1.4,
      fontStyle: italic ? FontStyle.italic : FontStyle.normal,
      fontWeight: weight,
      color: color ?? Pal.of(c).ink,
    );

ThemeData buildTheme(Brightness b) {
  final p = b == Brightness.dark ? Pal.dark : Pal.light;
  final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF7A1F2B), brightness: b).copyWith(
    primary: p.maroon,
    secondary: p.saffron,
    surface: p.surface,
    onSurface: p.ink,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: p.bg,
    appBarTheme: AppBarTheme(backgroundColor: p.bg, foregroundColor: p.ink, elevation: 0, scrolledUnderElevation: 0),
    dividerColor: p.line,
    chipTheme: ChipThemeData(backgroundColor: p.chip, selectedColor: p.maroon, side: BorderSide.none),
    navigationBarTheme: NavigationBarThemeData(backgroundColor: p.surface, indicatorColor: p.chip),
  );
}

/// Thin prayer-flag stripe used at the top of each screen.
class FlagStripe extends StatelessWidget {
  const FlagStripe({super.key});
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 4,
        child: Row(children: [for (final c in flagColors) Expanded(child: ColoredBox(color: c))]),
      );
}
