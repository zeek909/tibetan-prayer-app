# Tibetan Prayers (Android)

A free Tibetan Buddhist prayer app, developed by Tenzing Tsewang.

- **Prayers:** 38 texts from the Gelug, Nyingma, Kagyu, Sakya and Bon traditions, in Tibetan script with phonetics and English. Search in Tibetan, phonetics or English; browse by occasion, deity or tradition; save your daily prayers.
- **Reading:** switch each layer on or off, change the text size, auto-scroll at chanting speed. The screen stays on while you read.
- **Recordings:** add a recording from your phone to any prayer, then tap through once to mark when each line starts, so the lines light up as it plays.
- **Tibetan calendar:** Phugpa dates (as used by Men-Tsee-Khang), festivals, monthly practice days and prayer-flag days, with reminders on your phone.
- **Home-screen widget:** today's Tibetan date and the prayer-flag rule.
- **Mala counter:** tap or use the volume buttons; counts per mantra, today's total and a goal.
- **49 days of prayers:** a day counter and weekly days after someone passes away, with suggested prayers and reminders.

Everything works offline. Texts, settings and counts stay on the phone.

## Getting the APK

Every push to `main` builds the app on GitHub. Open the **Actions** tab, choose the latest **Build Android APK** run, and download **tibetan-prayers-apk** at the bottom. Unzip it and install `app-release.apk` on your phone (allow installing from this source when asked).

## Building on your own PC

Install Flutter 3.24 and Android Studio, then in this folder run:

```
flutter create --platforms=android --org com.tenzingtsewang --project-name tibetan_prayer_app .
dart run tool/setup_android.dart
flutter pub get
flutter run
```

`flutter create` makes the standard Android folder; `tool/setup_android.dart` adds this app's volume-button code, home-screen widget, notification receivers and Gradle settings from `android_overlay/`.

## Sources

The Tibetan text of each prayer comes from the printed book named on its page: the Gaden Jangtse Library *Rinchen Bumzang* (2019), the Larung Gar Daily Chant Book (2021), the Kagyu Monlam book from Shri Diwakar Publications (2016) and the Sachen Foundation Sakya prayer book. Permission from these publishers is still being requested, so keep this repository private for now. Phonetics and English are drafts.

Fonts: Jomolhari (Christopher J. Fynn), Noto Serif Tibetan (Google) and Spectral (Production Type), under the SIL Open Font License; licence files are in `assets/fonts/`.
