// Adds this app's Android pieces to the folder made by `flutter create`.
// Run from the project folder:  dart run tool/setup_android.dart
import 'dart:io';

const pkgPath = 'com/tenzingtsewang/tibetan_prayer_app';

void main() {
  final app = Directory('android/app');
  if (!app.existsSync()) {
    stderr.writeln('android/ not found. Run first: flutter create --platforms=android --org com.tenzingtsewang --project-name tibetan_prayer_app .');
    exit(1);
  }
  // 1. Kotlin code
  final kt = Directory('android/app/src/main/kotlin/$pkgPath')..createSync(recursive: true);
  for (final f in Directory('android_overlay/kotlin').listSync().whereType<File>()) {
    f.copySync('${kt.path}/${f.uri.pathSegments.last}');
  }
  // 2. Resources
  for (final sub in ['layout', 'xml', 'drawable', 'values']) {
    final from = Directory('android_overlay/res/$sub');
    if (!from.existsSync()) continue;
    final to = Directory('android/app/src/main/res/$sub')..createSync(recursive: true);
    for (final f in from.listSync().whereType<File>()) {
      f.copySync('${to.path}/${f.uri.pathSegments.last}');
    }
  }
  // 3. Manifest
  final mf = File('android/app/src/main/AndroidManifest.xml');
  var m = mf.readAsStringSync();
  if (!m.contains('POST_NOTIFICATIONS')) {
    final open = RegExp(r'<manifest[^>]*>').firstMatch(m)!;
    m = m.replaceRange(open.end, open.end, '''

    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
    <uses-permission android:name="android.permission.VIBRATE"/>''');
    m = m.replaceFirst(RegExp(r'android:label="[^"]*"'), 'android:label="Tibetan Prayers"');
    m = m.replaceFirst('</application>', '''
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
                <action android:name="android.intent.action.QUICKBOOT_POWERON" />
                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
            </intent-filter>
        </receiver>
        <receiver android:name=".PrayerWidgetProvider" android:exported="true">
            <intent-filter>
                <action android:name="android.appwidget.action.APPWIDGET_UPDATE" />
            </intent-filter>
            <meta-data android:name="android.appwidget.provider" android:resource="@xml/prayer_widget_info" />
        </receiver>
    </application>''');
    mf.writeAsStringSync(m);
  }
  // 4. Gradle: core library desugaring, needed by scheduled notifications
  final groovy = File('android/app/build.gradle'), kts = File('android/app/build.gradle.kts');
  if (groovy.existsSync()) {
    var g = groovy.readAsStringSync();
    if (!g.contains('coreLibraryDesugaringEnabled')) {
      g = g.replaceFirst('compileOptions {', 'compileOptions {\n        coreLibraryDesugaringEnabled true');
      g += "\ndependencies {\n    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.0.4'\n}\n";
      groovy.writeAsStringSync(g);
    }
  } else if (kts.existsSync()) {
    var g = kts.readAsStringSync();
    if (!g.contains('isCoreLibraryDesugaringEnabled')) {
      g = g.replaceFirst('compileOptions {', 'compileOptions {\n        isCoreLibraryDesugaringEnabled = true');
      g += '\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")\n}\n';
      kts.writeAsStringSync(g);
    }
  }
  stdout.writeln('Android setup done.');
}
