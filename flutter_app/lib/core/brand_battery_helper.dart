import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_locale.dart';
import 'app_theme.dart';

class BrandBatteryHelper {
  static const MethodChannel _channel = MethodChannel('com.mindcraftsai.meeqat/widget_channel');

  static String? _cachedManufacturer;

  static Future<String> getManufacturer() async {
    if (_cachedManufacturer != null) return _cachedManufacturer!;
    try {
      final mfr = await _channel.invokeMethod<String>('getDeviceManufacturer');
      _cachedManufacturer = mfr ?? 'generic';
    } catch (_) {
      _cachedManufacturer = 'generic';
    }
    return _cachedManufacturer!;
  }

  static Future<bool> isAggressiveBrand() async {
    final m = await getManufacturer();
    final lower = m.toLowerCase();
    return lower.contains('xiaomi') ||
        lower.contains('redmi') ||
        lower.contains('poco') ||
        lower.contains('oppo') ||
        lower.contains('realme') ||
        lower.contains('oneplus') ||
        lower.contains('vivo') ||
        lower.contains('iqoo') ||
        lower.contains('huawei') ||
        lower.contains('honor');
  }

  static Future<bool> openAutostartSettings() async {
    try {
      final res = await _channel.invokeMethod<bool>('openBrandAutostartSettings');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  static String getBrandDisplayName(String mfr) {
    final lower = mfr.toLowerCase();
    if (lower.contains('xiaomi') || lower.contains('redmi') || lower.contains('poco')) return 'Xiaomi (MIUI / HyperOS)';
    if (lower.contains('oppo') || lower.contains('realme') || lower.contains('oneplus')) return 'Oppo / Realme (ColorOS)';
    if (lower.contains('vivo') || lower.contains('iqoo')) return 'Vivo / iQOO (Funtouch OS)';
    if (lower.contains('huawei') || lower.contains('honor')) return 'Huawei / Honor (EMUI)';
    if (lower.contains('samsung')) return 'Samsung (One UI)';
    return mfr.toUpperCase();
  }

  static String getBrandInstructions(String mfr) {
    final lower = mfr.toLowerCase();
    if (lower.contains('xiaomi') || lower.contains('redmi') || lower.contains('poco')) {
      return AppLocale.t(
        ur: '1. سیکیورٹی ایپ (Security App) کھولیں۔\n2. Permissions (اجازتیں) > Autostart پر جائیں۔\n3. "المیقات" تلاش کر کے فعال (ON) کریں۔\n4. بیٹری سیٹنگز میں "No restrictions" منتخب کریں۔',
        en: '1. Open Security App.\n2. Tap Permissions > Autostart.\n3. Enable "Al-Meeqat".\n4. Set Battery Saver to "No restrictions".',
      );
    }
    if (lower.contains('oppo') || lower.contains('realme') || lower.contains('oneplus')) {
      return AppLocale.t(
        ur: '1. فون سیٹنگز > App Management > Auto-launch پر جائیں۔\n2. "المیقات" کو فعال (Allow) کریں۔\n3. بیٹری سیٹنگز میں "Allow background activity" آن رکھیں۔',
        en: '1. Settings > App Management > Auto-launch.\n2. Enable "Al-Meeqat".\n3. Allow background activity in battery settings.',
      );
    }
    if (lower.contains('vivo') || lower.contains('iqoo')) {
      return AppLocale.t(
        ur: '1. i Manager ایپ کھولیں > Permission Management پر جائیں۔\n2. Autostart میں "المیقات" کو آن کریں۔\n3. High background power consumption کو اجازت دیں۔',
        en: '1. Open i Manager > Permission Management.\n2. Turn ON Autostart for "Al-Meeqat".\n3. Allow high background power consumption.',
      );
    }
    if (lower.contains('huawei') || lower.contains('honor')) {
      return AppLocale.t(
        ur: '1. فون مینیجر (Phone Manager) > App Launch کھولیں۔\n2. "المیقات" تلاش کر کے "Manage Manually" منتخب کریں۔\n3. Auto-launch، Secondary launch اور Run in background تینوں آن کریں۔',
        en: '1. Phone Manager > App Launch.\n2. Find "Al-Meeqat" & set to "Manage Manually".\n3. Enable Auto-launch, Secondary launch & Run in background.',
      );
    }
    return AppLocale.t(
      ur: '1. فون سیٹنگز میں "المیقات" کی ایپ انفارمیشن کھولیں۔\n2. Battery > Unrestricted پر سیٹ کریں۔\n3. تاکہ فون سلیپ موڈ میں بھی اذان کبھی مس نہ ہو۔',
      en: '1. Open App info for "Al-Meeqat" in Settings.\n2. Set Battery usage to "Unrestricted".\n3. Ensures alarms never miss even during deep sleep.',
    );
  }

  static Future<void> showBrandGuidanceDialog(BuildContext context, [String? mfr]) async {
    final effectiveMfr = mfr ?? await getManufacturer();
    final brandName = getBrandDisplayName(effectiveMfr);
    final instructions = getBrandInstructions(effectiveMfr);

    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: AppLocale.textDirection,
        child: AlertDialog(
          backgroundColor: AppTheme.surfaceElevated,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: Row(
            children: [
              Icon(Icons.battery_charging_full_rounded, color: AppTheme.gold, size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  AppLocale.t(
                    ur: 'بروقت اذان کیلئے بیٹری سیٹنگ',
                    en: 'Unrestricted Alarm Settings',
                  ),
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.emerald.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.emerald.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.phone_android, size: 18, color: Color(0xFF10B981)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'موبائل ماڈل: $brandName',
                        style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                AppLocale.t(
                  ur: 'چینی اور جدید اسمارٹ فونز میں بیٹری بچانے کا سسٹم بند اسکرین پر اذان کو کِل کر دیتا ہے۔ اس سے بچنے کے لیے درج ذیل ترتیبات آن رکھیں:',
                  en: 'Modern smartphones kill background alarms to save power. Please follow these steps to guarantee 100% timely Adhan:',
                ),
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12.5, height: 1.4),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Text(
                  instructions,
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 12.5, height: 1.5),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(AppLocale.t(ur: 'بعد میں', en: 'Later'), style: TextStyle(color: AppTheme.textSecondary)),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.emerald,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.settings, size: 18),
              label: Text(AppLocale.t(ur: 'سیٹنگز کھولیں', en: 'Open Settings')),
              onPressed: () {
                Navigator.pop(ctx);
                openAutostartSettings();
              },
            ),
          ],
        ),
      ),
    );
  }
}
