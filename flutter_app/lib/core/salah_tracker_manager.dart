import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

enum SalahStatus { none, jamaat, individual, qadha }

class SalahTrackerManager extends ChangeNotifier {
  static final SalahTrackerManager _instance = SalahTrackerManager._internal();
  factory SalahTrackerManager() => _instance;
  SalahTrackerManager._internal() {
    init();
  }

  bool _isLoaded = false;
  bool get isLoaded => _isLoaded;

  // Daily tracker storage: Map of 'YYYY_MM_DD' -> Map<String, String>
  // Values: 'NONE', 'JAMAAT', 'INDIVIDUAL', 'QADHA'
  Map<String, Map<String, String>> _dailyLogs = {};

  // Qadha-e-Umri balances
  int _qadhaFajr = 0;
  int _qadhaDhuhr = 0;
  int _qadhaAsr = 0;
  int _qadhaMaghrib = 0;
  int _qadhaIsha = 0;
  int _qadhaWitr = 0;
  int _initialTotalQadha = 0;

  int get qadhaFajr => _qadhaFajr;
  int get qadhaDhuhr => _qadhaDhuhr;
  int get qadhaAsr => _qadhaAsr;
  int get qadhaMaghrib => _qadhaMaghrib;
  int get qadhaIsha => _qadhaIsha;
  int get qadhaWitr => _qadhaWitr;
  int get currentTotalQadha => _qadhaFajr + _qadhaDhuhr + _qadhaAsr + _qadhaMaghrib + _qadhaIsha + _qadhaWitr;
  int get initialTotalQadha => _initialTotalQadha > 0 ? _initialTotalQadha : currentTotalQadha;

  double get completionPercentage {
    if (initialTotalQadha <= 0) return 0.0;
    final completed = (initialTotalQadha - currentTotalQadha).clamp(0, initialTotalQadha);
    return (completed / initialTotalQadha) * 100.0;
  }

  Future<File> _getFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/salah_tracker_data.json');
  }

  Future<void> init() async {
    if (_isLoaded) return;
    try {
      final file = await _getFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        final Map<String, dynamic> data = jsonDecode(content);
        if (data.containsKey('dailyLogs')) {
          final rawDaily = data['dailyLogs'] as Map<String, dynamic>;
          _dailyLogs = rawDaily.map((k, v) => MapEntry(k, Map<String, String>.from(v as Map)));
        }
        _qadhaFajr = data['qadhaFajr'] as int? ?? 0;
        _qadhaDhuhr = data['qadhaDhuhr'] as int? ?? 0;
        _qadhaAsr = data['qadhaAsr'] as int? ?? 0;
        _qadhaMaghrib = data['qadhaMaghrib'] as int? ?? 0;
        _qadhaIsha = data['qadhaIsha'] as int? ?? 0;
        _qadhaWitr = data['qadhaWitr'] as int? ?? 0;
        _initialTotalQadha = data['initialTotalQadha'] as int? ?? currentTotalQadha;
      }
    } catch (e) {
      debugPrint('SalahTrackerManager init error: $e');
    }
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> _save() async {
    try {
      final file = await _getFile();
      final data = {
        'dailyLogs': _dailyLogs,
        'qadhaFajr': _qadhaFajr,
        'qadhaDhuhr': _qadhaDhuhr,
        'qadhaAsr': _qadhaAsr,
        'qadhaMaghrib': _qadhaMaghrib,
        'qadhaIsha': _qadhaIsha,
        'qadhaWitr': _qadhaWitr,
        'initialTotalQadha': _initialTotalQadha,
      };
      await file.writeAsString(jsonEncode(data));
    } catch (e) {
      debugPrint('SalahTrackerManager save error: $e');
    }
    notifyListeners();
  }

  String _dateKey(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}_${date.month.toString().padLeft(2, '0')}_${date.day.toString().padLeft(2, '0')}';
  }

  String getPrayerStatus(DateTime date, String prayerKey) {
    final key = _dateKey(date);
    return _dailyLogs[key]?[prayerKey] ?? 'NONE';
  }

  SalahStatus getStatus(DateTime date, String prayerKey) {
    final s = getPrayerStatus(date, prayerKey);
    switch (s) {
      case 'JAMAAT': return SalahStatus.jamaat;
      case 'INDIVIDUAL': return SalahStatus.individual;
      case 'QADHA': return SalahStatus.qadha;
      default: return SalahStatus.none;
    }
  }

  Future<void> cycleStatus(DateTime date, String prayerKey) async {
    togglePrayerStatus(date, prayerKey);
  }

  int getCompletedCountForDate(DateTime date) {
    final key = _dateKey(date);
    final map = _dailyLogs[key];
    if (map == null) return 0;
    int count = 0;
    for (final p in ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha']) {
      final s = map[p];
      if (s == 'JAMAAT' || s == 'INDIVIDUAL') {
        count++;
      }
    }
    return count;
  }

  void togglePrayerStatus(DateTime date, String prayerKey) {
    final key = _dateKey(date);
    final current = getPrayerStatus(date, prayerKey);
    String next;
    switch (current) {
      case 'NONE':
        next = 'JAMAAT';
        break;
      case 'JAMAAT':
        next = 'INDIVIDUAL';
        break;
      case 'INDIVIDUAL':
        next = 'QADHA';
        break;
      case 'QADHA':
      default:
        next = 'NONE';
        break;
    }
    _dailyLogs.putIfAbsent(key, () => {});
    _dailyLogs[key]![prayerKey] = next;
    _save();
  }

  void setupQadhaBalances({required int years, int months = 0, int days = 0}) {
    final totalDays = (years * 365) + (months * 30) + days;
    _qadhaFajr = totalDays;
    _qadhaDhuhr = totalDays;
    _qadhaAsr = totalDays;
    _qadhaMaghrib = totalDays;
    _qadhaIsha = totalDays;
    _qadhaWitr = totalDays;
    _initialTotalQadha = totalDays * 6;
    _save();
  }

  void setSingleQadhaBalance(String prayerKey, int count) {
    final safeCount = count < 0 ? 0 : count;
    switch (prayerKey) {
      case 'fajr': _qadhaFajr = safeCount; break;
      case 'dhuhr': _qadhaDhuhr = safeCount; break;
      case 'asr': _qadhaAsr = safeCount; break;
      case 'maghrib': _qadhaMaghrib = safeCount; break;
      case 'isha': _qadhaIsha = safeCount; break;
      case 'witr': _qadhaWitr = safeCount; break;
    }
    if (_initialTotalQadha < currentTotalQadha) {
      _initialTotalQadha = currentTotalQadha;
    }
    _save();
  }

  void decrementQadha(String prayerKey, [int count = 1]) {
    switch (prayerKey) {
      case 'fajr': _qadhaFajr = (_qadhaFajr - count).clamp(0, 999999); break;
      case 'dhuhr': _qadhaDhuhr = (_qadhaDhuhr - count).clamp(0, 999999); break;
      case 'asr': _qadhaAsr = (_qadhaAsr - count).clamp(0, 999999); break;
      case 'maghrib': _qadhaMaghrib = (_qadhaMaghrib - count).clamp(0, 999999); break;
      case 'isha': _qadhaIsha = (_qadhaIsha - count).clamp(0, 999999); break;
      case 'witr': _qadhaWitr = (_qadhaWitr - count).clamp(0, 999999); break;
    }
    _save();
  }
}
