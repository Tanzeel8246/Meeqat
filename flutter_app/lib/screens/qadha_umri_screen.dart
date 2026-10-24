import 'package:flutter/material.dart';
import '../core/app_locale.dart';
import '../core/app_theme.dart';
import '../core/salah_tracker_manager.dart';

class QadhaUmriScreen extends StatefulWidget {
  const QadhaUmriScreen({super.key});

  @override
  State<QadhaUmriScreen> createState() => _QadhaUmriScreenState();
}

class _QadhaUmriScreenState extends State<QadhaUmriScreen> {
  final SalahTrackerManager _manager = SalahTrackerManager();

  @override
  void initState() {
    super.initState();
    _manager.addListener(_onChanged);
  }

  @override
  void dispose() {
    _manager.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  void _showSetupWizardDialog() {
    final yearsCtrl = TextEditingController(text: '1');
    final monthsCtrl = TextEditingController(text: '0');
    final daysCtrl = TextEditingController(text: '0');

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: AppLocale.textDirection,
        child: AlertDialog(
          backgroundColor: AppTheme.surfaceElevated,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: Row(
            children: [
              Icon(Icons.calculate_rounded, color: AppTheme.gold, size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  AppLocale.t(ur: 'قضاءِ عمری کا تخمینہ کیلکولیٹر', en: 'Qadha-e-Umri Setup Calculator'),
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocale.t(
                  ur: 'سنِ بلوغت کے بعد سے جتنے سال، ماہ یا دن نمازیں قضاء ہوئی ہیں، ان کا محتاط تخمینہ درج کریں:',
                  en: 'Enter estimated missed duration after attaining puberty to set up your tracker:',
                ),
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12.5, height: 1.4),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: yearsCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: AppLocale.t(ur: 'سال (Years)', en: 'Years'),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: monthsCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: AppLocale.t(ur: 'ماہ (Months)', en: 'Months'),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: daysCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: AppLocale.t(ur: 'دن (Days)', en: 'Days'),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(AppLocale.t(ur: 'منسوخ', en: 'Cancel'), style: TextStyle(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.emerald,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                final y = int.tryParse(yearsCtrl.text.trim()) ?? 0;
                final m = int.tryParse(monthsCtrl.text.trim()) ?? 0;
                final d = int.tryParse(daysCtrl.text.trim()) ?? 0;
                _manager.setupQadhaBalances(years: y, months: m, days: d);
                Navigator.pop(ctx);
              },
              child: Text(AppLocale.t(ur: 'حساب کریں و محفوظ کریں', en: 'Calculate & Save')),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditPrayerCountDialog(String prayerKey, String prayerName, int currentCount) {
    final ctrl = TextEditingController(text: currentCount.toString());
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: AppLocale.textDirection,
        child: AlertDialog(
          backgroundColor: AppTheme.surfaceElevated,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            '$prayerName: ${AppLocale.t(ur: 'تعداد درست کریں', en: 'Edit Count')}',
            style: TextStyle(color: AppTheme.gold, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          content: TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: InputDecoration(
              labelText: AppLocale.t(ur: 'باقی قضاء نمازیں', en: 'Remaining Qadha'),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(AppLocale.t(ur: 'منسوخ', en: 'Cancel'), style: TextStyle(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.emerald,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                final val = int.tryParse(ctrl.text.trim()) ?? currentCount;
                _manager.setSingleQadhaBalance(prayerKey, val);
                Navigator.pop(ctx);
              },
              child: Text(AppLocale.t(ur: 'محفوظ کریں', en: 'Save')),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prayers = [
      {'key': 'fajr', 'name_ur': 'فجر (۲ فرض)', 'name_en': 'Fajr (2 Fard)', 'count': _manager.qadhaFajr, 'color': AppTheme.sky},
      {'key': 'dhuhr', 'name_ur': 'ظہر (۴ فرض)', 'name_en': 'Dhuhr (4 Fard)', 'count': _manager.qadhaDhuhr, 'color': AppTheme.gold},
      {'key': 'asr', 'name_ur': 'عصر (۴ فرض)', 'name_en': 'Asr (4 Fard)', 'count': _manager.qadhaAsr, 'color': AppTheme.emerald},
      {'key': 'maghrib', 'name_ur': 'مغرب (۳ فرض)', 'name_en': 'Maghrib (3 Fard)', 'count': _manager.qadhaMaghrib, 'color': const Color(0xFFF97316)},
      {'key': 'isha', 'name_ur': 'عشاء (۴ فرض)', 'name_en': 'Isha (4 Fard)', 'count': _manager.qadhaIsha, 'color': const Color(0xFF8B5CF6)},
      {'key': 'witr', 'name_ur': 'وتر واجب (۳ واجب)', 'name_en': 'Witr (3 Wajib)', 'count': _manager.qadhaWitr, 'color': const Color(0xFFEC4899)},
    ];

    final progress = _manager.completionPercentage;

    return Directionality(
      textDirection: AppLocale.textDirection,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            AppLocale.t(ur: 'قضاءِ عمری رجسٹر و محاسبہ', en: 'Qadha-e-Umri Ledger'),
            style: TextStyle(color: AppTheme.gold, fontWeight: FontWeight.bold, fontSize: 18),
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.calculate_outlined, color: AppTheme.emerald),
              tooltip: AppLocale.t(ur: 'تخمینہ لگائیں', en: 'Setup Calculator'),
              onPressed: _showSetupWizardDialog,
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          children: [
            // Hero Progress Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: AppTheme.isDark
                      ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                      : [const Color(0xFF065F46), const Color(0xFF047857)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.gold.withValues(alpha: 0.3)),
                boxShadow: AppTheme.cardShadow,
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppLocale.t(ur: 'کل باقی قضاء نمازیں', en: 'Total Remaining Qadha'),
                            style: TextStyle(color: AppTheme.isDark ? AppTheme.gold : Colors.white70, fontSize: 13),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_manager.currentTotalQadha}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 34,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${progress.toStringAsFixed(1)}%',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: (progress / 100.0).clamp(0.0, 1.0),
                      minHeight: 8,
                      backgroundColor: Colors.white.withValues(alpha: 0.15),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF34D399)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 6 Prayers Grid / Cards
            ...prayers.map((p) {
              final key = p['key'] as String;
              final name = AppLocale.t(ur: p['name_ur'] as String, en: p['name_en'] as String);
              final count = p['count'] as int;
              final color = p['color'] as Color;

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: color.withValues(alpha: 0.35), width: 1.2),
                  boxShadow: AppTheme.cardShadow,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 45,
                      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(5)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          const SizedBox(height: 2),
                          InkWell(
                            onTap: () => _showEditPrayerCountDialog(key, name, count),
                            child: Row(
                              children: [
                                Text(
                                  '$count ${AppLocale.t(ur: 'باقی', en: 'left')}',
                                  style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18),
                                ),
                                const SizedBox(width: 6),
                                Icon(Icons.edit, size: 14, color: AppTheme.textSecondary),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Action Buttons (+1 and +5)
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color.withValues(alpha: 0.18),
                        foregroundColor: color,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: color.withValues(alpha: 0.5)),
                        ),
                      ),
                      onPressed: count > 0 ? () => _manager.decrementQadha(key, 1) : null,
                      child: Text('+1 ${AppLocale.t(ur: 'پڑھی', en: 'done')}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                    const SizedBox(width: 6),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color,
                        foregroundColor: Colors.white,
                        elevation: 1,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: count > 0 ? () => _manager.decrementQadha(key, 5) : null,
                      child: const Text('+5', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ],
                ),
              );
            }),

            const SizedBox(height: 14),

            // Shar'i Guidance & Fatawa Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.surfaceElevated,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.menu_book, color: AppTheme.gold, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        AppLocale.t(ur: 'فقہی رہنمائی: قضاءِ عمری کی ادائیگی کا آسان طریقہ', en: 'Fiqh Guidance: Offering Qadha-e-Umri'),
                        style: TextStyle(color: AppTheme.gold, fontWeight: FontWeight.bold, fontSize: 13.5),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppLocale.t(
                      ur: '1. روزانہ ہر وقتی نماز کے ساتھ اسی وقت کی ایک یا دو قضاء نمازیں ادا کرنے کا معمول بنا لیں۔ مثلاً فجر کی وقتی نماز کے بعد فجر کی ایک قضاء، ظہر کے ساتھ ظہر کی ایک قضاء۔\n2. نیت کا طریقہ: "میری ذمے جو سب سے پہلی فجر قضاء ہے، وہ ادا کرتا ہوں"۔\n3. قضاء صرف فرائض اور وتر واجب کی ہوتی ہے، سنتوں کی قضاء نہیں۔',
                      en: '1. Establish a routine of praying 1 or 2 Qadha prayers with every daily prayer.\n2. Intention: "I intend to offer the earliest missed Fajr prayer due upon me".\n3. Qadha is obligatory only for the Fard prayers and Witr Wajib, not Sunnah prayers.',
                    ),
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
