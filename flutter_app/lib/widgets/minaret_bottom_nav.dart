import 'package:flutter/material.dart';
import '../core/city_database.dart';
import '../core/app_locale.dart';
import '../core/app_theme.dart';
import '../core/app_settings.dart';
import '../core/astronomical_engine.dart';
import '../core/hijri_calendar.dart';
import '../core/alarm_service.dart';
import '../screens/monthly_screen.dart';
import '../screens/qibla_screen.dart';
import '../screens/moon_sighting_screen.dart';
import '../screens/mosque_display_screen.dart';
import '../screens/gazetteer_screen.dart';
import '../screens/settings_screen.dart';

/// Persistent Sticky 5-Tab Bottom Navigation Bar for Meeqat (المیقات)
/// Conforms to Material 3 / iOS HIG: Exactly 5 evenly spaced, thumb-friendly tabs with zero horizontal scrolling.
class MinaretBottomNav extends StatelessWidget {
  final String currentScreen;
  final CityModel city;
  final Map<String, dynamic>? detailedTimes;
  final String? hijriDate;
  final Function(CityModel)? onCityChanged;

  const MinaretBottomNav({
    super.key,
    required this.currentScreen,
    required this.city,
    this.detailedTimes,
    this.hijriDate,
    this.onCityChanged,
  });

  Map<String, dynamic> _getOrComputeDetailedTimes() {
    if (detailedTimes != null &&
        detailedTimes!.isNotEmpty &&
        detailedTimes!['exact'] != null) {
      final exact = detailedTimes!['exact'] as Map<String, dynamic>?;
      if (exact != null && exact['fajr'] != null && exact['fajr'] != '--') {
        return detailedTimes!;
      }
    }
    final now = DateTime.now();
    final settings = AppSettings();
    final engine = AstronomicalEngine(
      latitude: city.latitude,
      longitude: city.longitude,
      timeZone: city.timezone,
      asrJuristic: settings.asrMethod,
      elevation: city.elevation,
      fajrMode: settings.fajrMode,
      fajrDegree: settings.fajrDegree,
      fajrIntervalMin: settings.fajrIntervalMin,
      ishaMode: settings.ishaMode,
      ishaDegree: settings.ishaDegree,
      ishaIntervalMin: settings.ishaIntervalMin,
      is12HourFormat: settings.is12HourFormat,
    );
    return engine.calculateDetailedTimes(now);
  }

  String _getOrComputeHijri() {
    if (hijriDate != null && hijriDate!.trim().isNotEmpty) {
      return hijriDate!;
    }
    final settings = AppSettings();
    final h = HijriCalendar.fromGregorian(DateTime.now().add(Duration(days: settings.hijriAdjustment)));
    return AppLocale.isUrdu ? (h['formatted_urdu'] ?? '') : (h['formatted_en'] ?? '');
  }

  void _showMoreMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Directionality(
        textDirection: AppLocale.textDirection,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    AppLocale.t(ur: 'مزید اختیارات و فیچرز', en: 'More Options & Features'),
                    style: TextStyle(
                      color: AppTheme.gold,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  // Theme Quick Switcher in Sheet
                  IconButton(
                    icon: Icon(
                      AppTheme.isDark ? Icons.light_mode : Icons.dark_mode,
                      color: AppTheme.gold,
                    ),
                    tooltip: AppLocale.t(ur: 'ڈارک / لائٹ موڈ', en: 'Dark / Light Mode'),
                    onPressed: () {
                      AppTheme.toggle();
                      Navigator.pop(ctx);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 1. Settings & Calculations
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppTheme.surfaceElevated,
                  child: Icon(Icons.tune, color: AppTheme.emerald),
                ),
                title: Text(
                  AppLocale.t(ur: 'عمومی ترتیبات و فقہی زاویے', en: 'General Settings & Jurisprudence'),
                  style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  AppLocale.t(ur: '15° و 18° زاویے، مسلک، وقت فارمیٹ اور مساجد', en: '15°/18° angles, juristic views, format & mosques'),
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (c) => SettingsScreen(
                        currentCity: city,
                        onCityChanged: (newCity) {
                          if (onCityChanged != null) onCityChanged!(newCity);
                        },
                      ),
                    ),
                  );
                },
              ),

              // 2. Moon Sighting Guide
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppTheme.surfaceElevated,
                  child: Icon(Icons.nightlight_round, color: AppTheme.gold),
                ),
                title: Text(
                  AppLocale.t(ur: 'رویتِ ہلال و قمری کیلنڈر', en: 'Moon Sighting & Lunar Guide'),
                  style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  AppLocale.t(ur: 'چاند کی عمر، بلندی، غروب اور رویت کے امکانات', en: 'Moon altitude, lag time, age and visibility forecast'),
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (c) => MoonSightingScreen(city: city)),
                  );
                },
              ),

              // 3. Adhan Reminders & Alarms
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppTheme.surfaceElevated,
                  child: Icon(Icons.notifications_active, color: AppTheme.sky),
                ),
                title: Text(
                  AppLocale.t(ur: 'نماز اذان و اوقات الارمز', en: 'Adhan & Prayer Reminders'),
                  style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  AppLocale.t(ur: '5 مستند اذانیں، مکہ، مدینہ، اقصی اور آف لائن الرٹس', en: '5 authentic adhans (Makkah, Madinah, Aqsa) & offline alarms'),
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  AlarmService.showAlarmDialog(context, () {});
                },
              ),

              // 4. Cities Directory
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppTheme.surfaceElevated,
                  child: Icon(Icons.location_city, color: AppTheme.emerald),
                ),
                title: Text(
                  AppLocale.t(ur: 'دنیا بھر کے شہروں کی فہرست', en: 'Worldwide Cities Gazetteer'),
                  style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  AppLocale.t(ur: 'گوگل میپس API و پبلک سرچ، عرض و طول بلد کے ساتھ', en: 'Google Maps API, coordinates and global search'),
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  final selected = await Navigator.push<CityModel>(
                    context,
                    MaterialPageRoute(builder: (c) => const GazetteerScreen()),
                  );
                  if (selected != null && onCityChanged != null) {
                    onCityChanged!(selected);
                  }
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: AppLocale.textDirection,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.navBackground,
          border: Border(
            top: BorderSide(color: AppTheme.navBorder, width: 1.2),
          ),
          boxShadow: AppTheme.cardShadow,
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
            child: Row(
              children: [
                // 1. Home Tab
                Expanded(
                  child: _buildNavTab(
                    context: context,
                    screenKey: 'home',
                    icon: Icons.home_rounded,
                    labelUr: 'ہوم',
                    labelEn: 'Home',
                    onTap: () {
                      if (currentScreen == 'home') return;
                      Navigator.popUntil(context, (r) => r.isFirst);
                    },
                  ),
                ),

                // 2. Timetable Tab
                Expanded(
                  child: _buildNavTab(
                    context: context,
                    screenKey: 'timetable',
                    icon: Icons.calendar_month_rounded,
                    labelUr: 'جدول',
                    labelEn: 'Timetable',
                    onTap: () {
                      if (currentScreen == 'timetable') return;
                      final target = MonthlyScreen(city: city);
                      if (currentScreen != 'home') {
                        Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => target));
                      } else {
                        Navigator.push(context, MaterialPageRoute(builder: (c) => target));
                      }
                    },
                  ),
                ),

                // 3. Qibla Tab
                Expanded(
                  child: _buildNavTab(
                    context: context,
                    screenKey: 'qibla',
                    icon: Icons.explore_rounded,
                    labelUr: 'قبلہ',
                    labelEn: 'Qibla',
                    onTap: () {
                      if (currentScreen == 'qibla') return;
                      final target = QiblaScreen(city: city);
                      if (currentScreen != 'home') {
                        Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => target));
                      } else {
                        Navigator.push(context, MaterialPageRoute(builder: (c) => target));
                      }
                    },
                  ),
                ),

                // 4. Mosque Display Tab
                Expanded(
                  child: _buildNavTab(
                    context: context,
                    screenKey: 'display',
                    icon: Icons.tv_rounded,
                    labelUr: 'ڈسپلے',
                    labelEn: 'Display',
                    onTap: () {
                      if (currentScreen == 'display') return;
                      final effDetailed = _getOrComputeDetailedTimes();
                      final exact = effDetailed['exact'] as Map<String, dynamic>? ?? {};
                      final effHijri = _getOrComputeHijri();
                      final displayWidget = MosqueDisplayScreen(
                        city: city,
                        prayerTimes: {
                          'fajr': exact['fajr'] ?? '--',
                          'dhuhr': exact['dhuhr'] ?? '--',
                          'asr': exact['asr'] ?? '--',
                          'maghrib': exact['maghrib'] ?? '--',
                          'isha': exact['isha'] ?? '--',
                        },
                        hijriDate: effHijri,
                        detailedTimes: effDetailed,
                      );

                      if (currentScreen != 'home') {
                        Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => displayWidget));
                      } else {
                        Navigator.push(context, MaterialPageRoute(builder: (c) => displayWidget));
                      }
                    },
                  ),
                ),

                // 5. More / Settings Tab
                Expanded(
                  child: _buildNavTab(
                    context: context,
                    screenKey: 'more',
                    icon: Icons.widgets_rounded,
                    labelUr: 'مزید',
                    labelEn: 'More',
                    onTap: () => _showMoreMenu(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavTab({
    required BuildContext context,
    required String screenKey,
    required IconData icon,
    required String labelUr,
    required String labelEn,
    required VoidCallback onTap,
  }) {
    final bool isActive = currentScreen == screenKey || (screenKey == 'more' && (currentScreen == 'settings' || currentScreen == 'moon'));

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.emerald.withValues(alpha: 0.16) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 23,
              color: isActive ? AppTheme.emerald : AppTheme.textSecondary,
            ),
            const SizedBox(height: 3),
            Text(
              AppLocale.t(ur: labelUr, en: labelEn),
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                color: isActive ? AppTheme.emerald : AppTheme.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
