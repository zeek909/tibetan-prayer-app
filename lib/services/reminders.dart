import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:home_widget/home_widget.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../data/store.dart';
import '../data/tibcal.dart';
import '../data/prayers.dart';

/// Calendar reminders on the phone, and the data behind the home-screen widget.
class Reminders {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static Future<void> init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    const settings = InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher'));
    await _plugin.initialize(settings);
    _ready = true;
  }

  static Future<bool> requestPermission() async {
    await init();
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    final ok = await android?.requestNotificationsPermission();
    return ok ?? true;
  }

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'tibetan_calendar',
      'Tibetan calendar',
      channelDescription: 'Festivals, practice days, prayer-flag days and 49-day prayers',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    ),
  );

  /// Replace all scheduled reminders with the next 45 days.
  static Future<void> reschedule() async {
    try {
      await init();
      await _plugin.cancelAll();
      final s = Store.i.reminders;
      if (!s.any) return;
      final now = DateTime.now();
      var id = 1;
      for (var k = 0; k <= 45; k++) {
        final day = DateTime(now.year, now.month, now.day).add(Duration(days: k));
        final at = DateTime(day.year, day.month, day.day, s.hour, s.minute);
        if (!at.isAfter(now)) continue;
        final lines = <String>[];
        String? title;
        final t = TibCal.forDate(day);
        if (t != null) {
          for (final e in eventsFor(t)) {
            if (e.kind == EvKind.festival && s.festivals) {
              title ??= e.title;
              lines.add('${e.title}: ${e.sub}');
            } else if (e.kind == EvKind.practice && s.practiceDays) {
              title ??= e.title;
              lines.add(e.sub);
            } else if (e.kind == EvKind.flagDay && s.flagDays) {
              title ??= e.title;
              lines.add(e.sub);
            } else if (e.kind == EvKind.avoidFlags && s.flagDays) {
              lines.add('Not a day to hang prayer flags.');
            }
          }
        }
        if (s.guides) {
          for (final g in Store.i.guides) {
            if (!g.remind) continue;
            for (var w = 1; w <= 7; w++) {
              final wd = g.weekDate(w);
              if (wd.year == day.year && wd.month == day.month && wd.day == day.day) {
                final who = g.name.isEmpty ? 'your loved one' : g.name;
                title ??= w == 7 ? 'The 49th day for $who' : 'Week $w prayers for $who';
                lines.add(w == 7 ? 'The final day of the 49 days.' : 'Weekly prayers for $who.');
              }
            }
          }
        }
        if (title == null && lines.isEmpty) continue;
        title ??= 'Tibetan calendar';
        final body = lines.where((l) => l != title).join(' ');
        await _plugin.zonedSchedule(
          id++,
          title,
          body.isEmpty ? (t != null ? tibLabel(t).en : '') : body,
          tz.TZDateTime.from(at, tz.UTC),
          _details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        );
      }
    } catch (e) {
      debugPrint('reminders: $e');
    }
  }

  /// Save the next 40 days for the home-screen widget, so it stays right even if the app is not opened.
  static Future<void> updateWidget() async {
    try {
      final now = DateTime.now();
      final days = <String, dynamic>{};
      for (var k = 0; k < 40; k++) {
        final d = DateTime(now.year, now.month, now.day).add(Duration(days: k));
        final t = TibCal.forDate(d);
        if (t == null) continue;
        final ev = eventsFor(t);
        final main = ev.where((e) => e.kind == EvKind.festival || e.kind == EvKind.practice || e.kind == EvKind.flagDay).toList();
        final l = tibLabel(t);
        days[dayKey(d)] = {
          'bo': l.bo,
          'en': l.en,
          'ev': main.isEmpty ? '' : main.first.title,
          'flag': ev.any((e) => e.kind == EvKind.avoidFlags) ? 'Avoid hanging prayer flags' : 'No prayer-flag restriction',
        };
      }
      await HomeWidget.saveWidgetData<String>('days', jsonEncode(days));
      await HomeWidget.updateWidget(androidName: 'PrayerWidgetProvider');
    } catch (e) {
      debugPrint('widget: $e');
    }
  }

  static String? prayerTitle(String? id) => id == null ? null : Library.byId[id]?.en;
}
