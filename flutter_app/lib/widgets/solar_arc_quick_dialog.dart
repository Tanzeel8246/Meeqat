import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/app_locale.dart';
import '../core/app_settings.dart';

class SolarArcQuickDialog extends StatefulWidget {
  final Map<String, dynamic> detailedTimes;
  final String nextPrayerName;
  final String nextPrayerTime;
  final String initialCountdown;

  const SolarArcQuickDialog({
    super.key,
    required this.detailedTimes,
    required this.nextPrayerName,
    required this.nextPrayerTime,
    required this.initialCountdown,
  });

  static Future<void> show(
    BuildContext context, {
    required Map<String, dynamic> detailedTimes,
    required String nextPrayerName,
    required String nextPrayerTime,
    required String initialCountdown,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (ctx) => SolarArcQuickDialog(
        detailedTimes: detailedTimes,
        nextPrayerName: nextPrayerName,
        nextPrayerTime: nextPrayerTime,
        initialCountdown: initialCountdown,
      ),
    );
  }

  @override
  State<SolarArcQuickDialog> createState() => _SolarArcQuickDialogState();
}

class _SolarArcQuickDialogState extends State<SolarArcQuickDialog> {
  late Timer _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _now = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  /// Strips seconds and AM/PM strictly as requested by user:
  /// "اور اس پر نمازوں کا ابتدائی وقت بغیر سیکنڈز کے اور بغیر اے ایم ، پی ایم کے قدرے نمایاں فونٹ میں ظاہر ہو"
  String _formatTimeWithoutSecondsAndAmPm(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '--:--';
    String clean = raw.replaceAll(RegExp(r'\s*(AM|PM|am|pm)', caseSensitive: false), '').trim();
    final parts = clean.split(':');
    if (parts.length >= 2) {
      final h = parts[0].padLeft(2, '0');
      final m = parts[1].padLeft(2, '0');
      return '$h:$m';
    }
    return clean;
  }

  @override
  Widget build(BuildContext context) {
    final fajr = widget.detailedTimes['fajr_card'] as Map<String, dynamic>? ?? {};
    final sunrise = widget.detailedTimes['sunrise_card'] as Map<String, dynamic>? ?? {};
    final dhuhr = widget.detailedTimes['dhuhr_card'] as Map<String, dynamic>? ?? {};
    final asr = widget.detailedTimes['asr_card'] as Map<String, dynamic>? ?? {};
    final maghrib = widget.detailedTimes['maghrib_card'] as Map<String, dynamic>? ?? {};
    final isha = widget.detailedTimes['isha_card'] as Map<String, dynamic>? ?? {};

    final isHanafi = AppSettings().asrMethod == 2;
    final asrStartTime = isHanafi ? (asr['hanafi_start'] ?? '') : (asr['shafi_start'] ?? '');

    final prayers = [
      {
        'key': 'fajr',
        'nameUr': 'فجر',
        'nameEn': 'Fajr',
        'icon': Icons.nightlight_round,
        'time': _formatTimeWithoutSecondsAndAmPm(fajr['start'] ?? fajr['adhan']),
        'color': const Color(0xFF38BDF8),
      },
      {
        'key': 'sunrise',
        'nameUr': 'طلوعِ آفتاب',
        'nameEn': 'Sunrise',
        'icon': Icons.wb_sunny_outlined,
        'time': _formatTimeWithoutSecondsAndAmPm(sunrise['sunrise']),
        'color': const Color(0xFFFBBF24),
      },
      {
        'key': 'dhuhr',
        'nameUr': 'ظہر',
        'nameEn': 'Dhuhr',
        'icon': Icons.wb_sunny,
        'time': _formatTimeWithoutSecondsAndAmPm(dhuhr['start'] ?? dhuhr['adhan']),
        'color': const Color(0xFFF59E0B),
      },
      {
        'key': 'asr',
        'nameUr': isHanafi ? 'عصر (حنفی)' : 'عصر (شافعی)',
        'nameEn': isHanafi ? 'Asr (Hanafi)' : 'Asr (Shafi\'i)',
        'icon': Icons.cloud,
        'time': _formatTimeWithoutSecondsAndAmPm(asrStartTime),
        'color': const Color(0xFF34D399),
      },
      {
        'key': 'maghrib',
        'nameUr': 'مغرب',
        'nameEn': 'Maghrib',
        'icon': Icons.wb_twilight,
        'time': _formatTimeWithoutSecondsAndAmPm(maghrib['sunset']),
        'color': const Color(0xFFFB923C),
      },
      {
        'key': 'isha',
        'nameUr': 'عشاء',
        'nameEn': 'Isha',
        'icon': Icons.bedtime,
        'time': _formatTimeWithoutSecondsAndAmPm(isha['start'] ?? isha['adhan']),
        'color': const Color(0xFFA78BFA),
      },
    ];

    final rawH = _now.hour;
    final is12h = AppSettings().is12HourFormat;
    final int h12Num = (rawH % 12 == 0) ? 12 : rawH % 12;
    final hStr = (is12h ? h12Num : rawH).toString().padLeft(2, '0');
    final mStr = _now.minute.toString().padLeft(2, '0');
    final sStr = _now.second.toString().padLeft(2, '0');
    final period = rawH >= 12 ? 'PM' : 'AM';
    final liveClock = is12h ? '$hStr:$mStr:$sStr $period' : '$hStr:$mStr:$sStr';

    final cleanNextPrayerTime = _formatTimeWithoutSecondsAndAmPm(widget.nextPrayerTime);

    return Directionality(
      textDirection: AppLocale.textDirection,
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
        backgroundColor: Colors.transparent,
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 480),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F172A), Color(0xFF020617)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFD4AF37), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFD4AF37).withValues(alpha: 0.25),
                blurRadius: 25,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Tappable Clock Card (Tapping closes the overlay)
                InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF1E293B),
                          Color(0xFF0F172A),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: const Color(0xFF10B981).withValues(alpha: 0.6),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.access_time_filled, color: Color(0xFF10B981), size: 20),
                            const SizedBox(width: 8),
                            Text(
                              liveClock,
                              textDirection: TextDirection.ltr,
                              style: const TextStyle(
                                color: Color(0xFF10B981),
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // Subtitle row with Next prayer start time and Countdown in distinct colors
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFF59E0B), width: 1),
                              ),
                              child: Text(
                                '${AppLocale.t(ur: 'اگلی نماز:', en: 'Next:')} ${widget.nextPrayerName} ($cleanNextPrayerTime)',
                                style: const TextStyle(
                                  color: Color(0xFFF59E0B),
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFF38BDF8), width: 1),
                              ),
                              child: Text(
                                '${AppLocale.t(ur: 'باقی:', en: 'Left:')} \u200E${widget.initialCountdown}\u200E',
                                style: const TextStyle(
                                  color: Color(0xFF38BDF8),
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // 2. Solar Day Arc Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.wb_sunny, color: Color(0xFFD4AF37), size: 18),
                    const SizedBox(width: 6),
                    Text(
                      AppLocale.t(
                        ur: 'سورج کا بصری راستہ (اوقاتِ ابتداء صلوٰۃ)',
                        en: 'Solar Day Arc (Prayer Start Times)',
                      ),
                      style: const TextStyle(
                        color: Color(0xFFF8FAFC),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // 3. The 6 Prayer Phases Cards (Strictly fits without scrolling)
                ...prayers.map((p) {
                  final bool isNext = widget.nextPrayerName.toLowerCase().contains((p['key'] as String).toLowerCase()) ||
                      ((p['key'] == 'dhuhr') && widget.nextPrayerName.contains('ظہر')) ||
                      ((p['key'] == 'fajr') && widget.nextPrayerName.contains('فجر')) ||
                      ((p['key'] == 'asr') && widget.nextPrayerName.contains('عصر')) ||
                      ((p['key'] == 'maghrib') && widget.nextPrayerName.contains('مغرب')) ||
                      ((p['key'] == 'isha') && widget.nextPrayerName.contains('عشاء'));

                  final color = p['color'] as Color;

                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 3.5),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isNext ? color.withValues(alpha: 0.18) : const Color(0xFF1E293B).withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isNext ? color : const Color(0xFF334155),
                        width: isNext ? 1.6 : 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(p['icon'] as IconData, color: color, size: 20),
                            const SizedBox(width: 10),
                            Text(
                              AppLocale.isUrdu ? (p['nameUr'] as String) : (p['nameEn'] as String),
                              style: TextStyle(
                                color: isNext ? Colors.white : const Color(0xFFE2E8F0),
                                fontSize: 14,
                                fontWeight: isNext ? FontWeight.bold : FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        // Prominent prayer start time without seconds and without AM/PM
                        Text(
                          p['time'] as String,
                          textDirection: TextDirection.ltr,
                          style: TextStyle(
                            color: isNext ? color : const Color(0xFFF1F5F9),
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  );
                }),

                const SizedBox(height: 10),
                // 3.5 Pin to Mobile Home Screen Button
                InkWell(
                  onTap: () async {
                    try {
                      const channel = MethodChannel('com.mindcraftsai.meeqat/widget_channel');
                      final bool? pinned = await channel.invokeMethod<bool>('pinWidgetToHomeScreen');
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: const Color(0xFF10B981),
                            content: Text(
                              pinned == true
                                  ? AppLocale.t(
                                      ur: '✅ ہوم اسکرین پر کلاک لگانے کا سسٹم پاپ اپ کھل گیا۔ Add پر کلک کریں۔',
                                      en: '✅ System popup opened. Tap Add to place widget on Home Screen.',
                                    )
                                  : AppLocale.t(
                                      ur: 'موبائل کی خالی اسکرین پر 2 سیکنڈ انگلی دبا کر رکھیں اور Widgets سے المیقات شامل کریں۔',
                                      en: 'Long-press on empty home screen, tap Widgets and select Meeqat.',
                                    ),
                            ),
                          ),
                        );
                      }
                    } catch (_) {}
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF10B981)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.add_to_home_screen, color: Color(0xFF10B981), size: 18),
                        const SizedBox(width: 8),
                        Text(
                          AppLocale.t(
                            ur: 'موبائل ہوم اسکرین پر کلاک وزٹ لگائیں 📲',
                            en: 'Add Clock Widget to Home Screen 📲',
                          ),
                          style: const TextStyle(
                            color: Color(0xFF10B981),
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 8),
                // 4. Tap-to-Close Dismiss Bar
                InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFF334155).withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF475569)),
                    ),
                    child: Text(
                      AppLocale.t(
                        ur: '✕ بند کرنے کے لیے کلاک یا یہاں کلک کریں',
                        en: '✕ Tap clock or here to close',
                      ),
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
