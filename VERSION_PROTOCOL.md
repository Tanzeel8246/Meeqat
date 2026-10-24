# Version Management & Release Protocol

This document defines the strict version control and release lifecycle rules for **Minaret Modern** across Mobile, Windows, and Web.

## Semantic Versioning Standard
Version format: `MAJOR.MINOR.PATCH+BUILD` (e.g. `1.1.0+2`)

1. **MAJOR (`1.x.x`)**: Complete architectural redesign or breaking schema changes.
2. **MINOR (`x.1.x`)**: New user-facing features (e.g. Moon Sighting screen, Solar Qibla, Live GPS Auto-detect).
3. **PATCH (`x.x.1`)**: Bug fixes, formula optimizations, and UI polish.
4. **BUILD (`+BUILD`)**: Integer incrementing with every compiled release build (e.g. `+1` -> `+2`).

---

## Release Checklist (Mandatory for Every Update)

Before producing any release build or concluding an update task:

- [ ] **1. Pubspec Version Bump**:
  - Update `version: X.Y.Z+B` in `flutter_app/pubspec.yaml`.
- [ ] **2. Android Manifest & Gradle Sync**:
  - Verify `versionName` and `versionCode` in `android/app/build.gradle.kts`.
  - Verify app label (`Minaret Modern - فلکیاتی اوقاتِ نماز`) in `AndroidManifest.xml`.
- [ ] **3. Professional App Icon & Launch Screen**:
  - Vector/Adaptive icon configured in `android/app/src/main/res/`.
  - Seamless dark splash background in `drawable/launch_background.xml` and `drawable-v21/launch_background.xml`.
- [ ] **4. Web & PHP Version Sync**:
  - Update version badge in `backend/public/index.php` and `standalone_web/index.html`.
- [ ] **5. Verification Matrix Execution**:
  - Run `flutter analyze` (Zero errors, zero warnings).
  - Run `flutter test` (All tests passing).
  - Run `flutter build apk` (Clean release build).
- [ ] **6. Production Artifact Copy**:
  - Copy release APK with versioned naming to project root (e.g. `Minaret_Modern_v1.1.0.apk` and `Minaret_Modern.apk`).
- [ ] **7. Changelog Update**:
  - Document all additions, modifications, and fixes in `CHANGELOG.md`.

---

## Version History
- **v1.5.1 (Build 10)**: 
  - **Menu Navigation & Directionality Fix**: Resolved menu tab reversal bug by wrapping `MaterialApp.builder` and every top-level screen with `Directionality(textDirection: AppLocale.textDirection)` and securing `MinaretBottomNav`.
  - **Mosque Display Beginning Times Self-Healing**: Completely solved blank beginning prayer times when navigating from sub-screens by computing daily detailed astronomical times dynamically when missing, plus passing active calculated times from `MinaretBottomNav`.
  - **Global City Geocoding & Bilingual Search Overhaul**: Integrated multi-source parallel geocoding engine (Open-Meteo with 3M+ global cities + Photon OpenStreetMap + Nominatim) with 350ms debounce, keyboard search action (`onSubmitted`), Urdu-to-English transliteration map, 70+ built-in Pakistani and world cities with full Urdu/English names, and integrated saved locations.
  - **Real Native File Exports**: Overhauled Monthly Timetable export into real downloadable and savable files directly in mobile/desktop Downloads folder:
    - **PDF (.pdf)**: Real multi-page landscape PDF file generation via `package:pdf` with complete prayer table and headers.
    - **CSV (.csv)**: Real spreadsheet file with UTF-8 BOM for Microsoft Excel and Google Sheets without Urdu character corruption.
    - **Document (.doc)**: Real Microsoft Word document file with formatted HTML table and Word namespaces.
    - **Plain Text (.txt)**: Universal monospace text file download.
    - **WhatsApp & Social Share**: Direct native share sheet via `package:share_plus` (`Share.shareXFiles` and `Share.share`).
- **v1.5.0 (Build 9)**: Fully automated dynamic Jama'at schedule for default mosque "جامع مسجد طوبیٰ (ارائیواں والی مسجد) فروکہ (سرگودھا)" (Fajr 30-35m window before sunrise in 5m discrete steps, Zuhr 1:30 PM all year round, Asr and Isha in 15m discrete quantized slots, Maghrib exactly 3m after Adhan, Friday Jumu'ah 1:45 PM). Overhauled Mosque TV/LED Display Screen with two primary tabs (Beginning & Jama'at), bold prominent fonts, strict RTL/LTR. Added persistent sticky bottom navigation bar across all screens with active tab glow. Bundled offline Adhan recordings for 5 holy mosques with individual preview listen buttons in alarm settings. Added global Google Maps / OSM geocoding search in City Gazetteer with timetable view, location saving, and default city assignment. Fully eradicated hardcoded Urdu in Solar Qibla and Moon Sighting screens.
- **v1.4.2 (Build 8)**: 100% exact conformity with Mufti Sahib's reference astronomical app down to the second across all 25 milestones. Updated Farooka coordinates to match Google Plus Code `VCQ7+444` (`31.794° N, 72.430° E`). Implemented exact Istiwa interval (`transit - 2m 40s` to `transit + 2m 24s`) and synchronized Zuhr start (`11:58:42 am`). Added dual Ishraq rows (`اشراق` + `ابتداء اشراق`), `اذان عصر شافعی`, exact Asr Makrooh (14m 58s before sunset), and Tahajjud last 6th milestone (`02:59:45 am`).
- **v1.4.1 (Build 7)**: 100% astronomical timetable parity restored with standard authentic Islamic apps and Pakistani calendars (eliminated elevation dip distortion by standardizing sea-level 0.8333° horizon; restored Dhuhr start to 1 min after true solar noon transit; eliminated artificial padding on Asr and Isha beginnings). Overhauled Determination of Isha & Fajr settings: eliminated 17° option completely, and added clear scholarly designations (18° مسلکِ جمہور علماء vs 15° خلافِ جمہور علماء - مفتی طیب سلیم صاحب سرگودھا) across Flutter, PHP backend, web admin panel, and standalone web.
- **v1.4.0 (Build 6)**: Reference-aligned Qibla compass sensor overhaul (`atan2(-x, y)` + WMM magnetic declination + low-pass angular smoothing), 12-hour AM/PM format application-wide, Mosque Jama'at congregation times (with Friday Jumu'ah) and display mode switcher, Determination of Fajr & Determination of Isha dialogs (18° vs 15° vs minute intervals), authentic online Adhans streaming with offline chime fallback, resilient Solar Qibla scanning (0°, 90°, 135°, 180°), 100 Saved Locations manager, Islamic Events countdown gallery, FAQ section, and About section with CodeHub & Mindcrafts AI branding and direct WhatsApp link (+923023448246).
- **v1.3.0 (Build 5)**: Comprehensive Shar'i prayer milestones redesign (Nisf-un-Nahar Shar'i, Zawal interval, Ishraq, Shafi'i & Hanafi Asr, Asr & Isha Makrooh, Tahajjud 1/3 and 1/6 milestones), silent safety margins, next prayer top countdown card, timetable multi-format exports (.doc, .pdf, .txt), 100% full bilingual Urdu & English localization with zero hardcoding, aesthetic header with scrollable bottom bar tabs, and full audioplayers alarm library with repeatable snooze reminder.
- **v1.2.1 (Build 4)**: Removed indiscriminate Adhan highlights and updated prayer cards with clear labels (`اختتام [پچھلی نماز]`, `ابتداء [نماز]`, `اذان [نماز]`), engineered ultra-sensitive 3D tilt-compensated Qibla compass using combined magnetometer & accelerometer streams with Kaaba locking, added Monthly Timetable export to CSV & copy/share feature, and eradicated horizontal scrolling from the Mosque TV Display board for a seamless non-scrolling layout.
- **v1.2.0 (Build 3)**: Added hardware magnetometer sensor-based auto-rotating Qibla compass needle, full Urdu & English bilingual support with official `Jameel Noori Nastaleeq` font, solved 0°, 90°, 135°, and 180° Solar Qibla calculations with robust astronomical bisection solver, redesigned home screen prayer cards with 3 distinct rows (اختتام، ابتداء، اذان) and highlighted Adhan row.
- **v1.1.0 (Build 2)**: Added Live Interactive Qibla Compass, Solar Qibla Tab with educational guide popup, Moon Sighting prediction screen, Sehar/Iftar cards, Date navigation, Adhan alarm selection with famous mosque tones, professional dark splash screen, and custom vector launcher icons.
- **v1.0.0 (Build 1)**: Initial Full-Stack Suite (PHP Backend + REST APIs + Flutter Cross-Platform App + Standalone Offline Web).
