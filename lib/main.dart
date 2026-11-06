import 'package:flutter/material.dart';
import 'data/prayers.dart';
import 'data/store.dart';
import 'services/reminders.dart';
import 'theme.dart';
import 'screens/home.dart';
import 'screens/calendar.dart';
import 'screens/mala.dart';
import 'screens/more.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Library.load();
  await Store.i.init();
  runApp(const PrayerApp());
  // Refresh reminders and the home-screen widget each time the app starts.
  Reminders.reschedule();
  Reminders.updateWidget();
}

class PrayerApp extends StatelessWidget {
  const PrayerApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Tibetan Prayers',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        themeMode: ThemeMode.system,
        home: const Shell(),
      );
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  static final tab = ValueNotifier<int>(0);
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: Shell.tab,
      builder: (context, i, _) => Scaffold(
        body: IndexedStack(index: i, children: [
          const PrayersScreen(),
          const CalendarScreen(),
          MalaScreen(active: i == 2),
          const MoreScreen(),
        ]),
        bottomNavigationBar: NavigationBar(
          selectedIndex: i,
          onDestinationSelected: (v) => Shell.tab.value = v,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book), label: 'Prayers'),
            NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: 'Calendar'),
            NavigationDestination(icon: Icon(Icons.blur_circular_outlined), selectedIcon: Icon(Icons.blur_circular), label: 'Mala'),
            NavigationDestination(icon: Icon(Icons.more_horiz), label: 'More'),
          ],
        ),
      ),
    );
  }
}
