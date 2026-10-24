import 'package:flutter/material.dart';
import '../core/hijri_calendar.dart';
import '../core/city_database.dart';
import '../core/app_locale.dart';
import '../core/app_theme.dart';
import '../widgets/minaret_bottom_nav.dart';

class MoonSightingScreen extends StatefulWidget {
  final CityModel city;

  const MoonSightingScreen({super.key, required this.city});

  @override
  State<MoonSightingScreen> createState() => _MoonSightingScreenState();
}

class _MoonSightingScreenState extends State<MoonSightingScreen> {
  DateTime _selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final moonInfo = HijriCalendar.getMoonSightingInfo(_selectedDate, tz: widget.city.timezone);
    final hijri = HijriCalendar.fromGregorian(_selectedDate);

    final statusText = AppLocale.isUrdu ? moonInfo['visibility_status_ur'] : moonInfo['visibility_status_en'];
    final descText = AppLocale.isUrdu ? moonInfo['visibility_desc_ur'] : moonInfo['visibility_desc_en'];
    final bestWindow = AppLocale.isUrdu ? moonInfo['best_sighting_window_ur'] : moonInfo['best_sighting_window_en'];
    final hijriDate = AppLocale.isUrdu ? hijri['formatted_urdu'] : hijri['formatted_en'];

    return Directionality(
      textDirection: AppLocale.textDirection,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            AppLocale.t(ur: 'چاند کی پیدائش و رویتِ ہلال', en: 'Crescent Moon Sighting Prediction'),
            style: TextStyle(color: AppTheme.gold, fontWeight: FontWeight.bold),
          ),
          iconTheme: IconThemeData(color: AppTheme.textPrimary),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Moon Visual Header
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: AppTheme.isDark
                        ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                        : [const Color(0xFFFEF3C7), const Color(0xFFF1F5F9)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.border),
                  boxShadow: AppTheme.elevatedShadow,
                ),
                child: Column(
                  children: [
                    const Text('🌙', style: TextStyle(fontSize: 64)),
                    const SizedBox(height: 10),
                    Text(
                      AppLocale.t(ur: 'پیدائشِ ہلال و رویت تخمینہ', en: 'New Moon Conjunction & Visibility'),
                      style: TextStyle(
                        color: AppTheme.gold,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${AppLocale.t(ur: 'مقام', en: 'Location')}: ${widget.city.name} | ${AppLocale.t(ur: 'تاریخ', en: 'Date')}: ${_selectedDate.day}-${_selectedDate.month}-${_selectedDate.year}',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${AppLocale.t(ur: 'ہجری تقویم', en: 'Hijri Date')}: $hijriDate',
                      style: TextStyle(color: AppTheme.emerald, fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Date Picker Button
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.surfaceElevated,
                  foregroundColor: AppTheme.emerald,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  side: BorderSide(color: AppTheme.emerald.withValues(alpha: 0.5)),
                ),
                icon: const Icon(Icons.date_range),
                label: Text(
                  AppLocale.t(ur: 'تاریخ تبدیل کریں (رویت کا دن منتخب کریں)', en: 'Change Date (Select Observation Day)'),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2035),
                  );
                  if (picked != null) {
                    setState(() => _selectedDate = picked);
                  }
                },
              ),
              const SizedBox(height: 20),

              // Visibility Status Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.emerald.withValues(alpha: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.visibility, color: AppTheme.emerald),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            statusText,
                            style: TextStyle(
                              color: AppTheme.emerald,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      descText,
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 14, height: 1.4),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.emerald.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.access_time, color: AppTheme.gold, size: 18),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${AppLocale.t(ur: 'بہترین وقت', en: 'Best Window')}: $bestWindow',
                              style: TextStyle(color: AppTheme.gold, fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Moon Metrics Grid
              Row(
                children: [
                  Expanded(
                    child: _buildMetricTile(
                      AppLocale.t(ur: 'چاند کی عمر', en: 'Moon Age'),
                      AppLocale.t(ur: '${moonInfo['moon_age_hours']} گھنٹے', en: '${moonInfo['moon_age_hours']} Hours'),
                      AppLocale.t(ur: '(${moonInfo['moon_age_days']} دن)', en: '(${moonInfo['moon_age_days']} Days)'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricTile(
                      AppLocale.t(ur: 'روشن سطح', en: 'Illumination'),
                      '${moonInfo['illumination_percent']}%',
                      AppLocale.t(ur: 'روشنی کا تناسب', en: 'Crescent Surface'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Conjunction Timings
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  children: [
                    _buildRowItem(
                      AppLocale.t(ur: 'پیدائشِ ہلال (ملاپ / Conjunction):', en: 'Moon Birth (Astronomical Conjunction):'),
                      AppLocale.isUrdu
                          ? (moonInfo['conjunction_birth_str_ur'] ?? moonInfo['conjunction_birth_str'])
                          : (moonInfo['conjunction_birth_str_en'] ?? moonInfo['conjunction_birth_str']),
                    ),
                    Divider(color: AppTheme.border, height: 20),
                    _buildRowItem(
                      AppLocale.t(ur: 'اگلے ماہ کی متوقع پیدائش:', en: 'Next Month Conjunction:'),
                      AppLocale.isUrdu
                          ? (moonInfo['next_conjunction_str_ur'] ?? moonInfo['next_conjunction_str'])
                          : (moonInfo['next_conjunction_str_en'] ?? moonInfo['next_conjunction_str']),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: MinaretBottomNav(
          currentScreen: 'moon',
          city: widget.city,
        ),
      ),
    );
  }

  Widget _buildMetricTile(String title, String val, String sub) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          Text(title, style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
          const SizedBox(height: 6),
          Text(val, style: TextStyle(color: AppTheme.gold, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(sub, style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildRowItem(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: Text(label, style: TextStyle(color: AppTheme.textPrimary, fontSize: 14))),
        Text(value, style: TextStyle(color: AppTheme.emerald, fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }
}
