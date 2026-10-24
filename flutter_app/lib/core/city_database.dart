import 'app_locale.dart';

class CityModel {
  final String id;
  final String name;
  final String nameUr;
  final String country;
  final String countryUr;
  final String province;
  final String provinceUr;
  final double latitude;
  final double longitude;
  final double timezone;
  final double elevation;
  final String source;

  const CityModel({
    required this.id,
    required this.name,
    this.nameUr = '',
    required this.country,
    this.countryUr = '',
    required this.province,
    this.provinceUr = '',
    required this.latitude,
    required this.longitude,
    required this.timezone,
    this.elevation = 0.0,
    this.source = 'Map',
  });

  String get localizedName => (AppLocale.isUrdu && nameUr.isNotEmpty) ? nameUr : name;
  String get localizedCountry => (AppLocale.isUrdu && countryUr.isNotEmpty) ? countryUr : country;
  String get localizedProvince => (AppLocale.isUrdu && provinceUr.isNotEmpty) ? provinceUr : province;
  bool get isGoogleMaps => source == 'Google Maps' || id.startsWith('gm_');

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'nameUr': nameUr,
    'country': country,
    'countryUr': countryUr,
    'province': province,
    'provinceUr': provinceUr,
    'latitude': latitude,
    'longitude': longitude,
    'timezone': timezone,
    'elevation': elevation,
    'source': source,
  };

  factory CityModel.fromJson(Map<String, dynamic> json) => CityModel(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    nameUr: json['nameUr'] as String? ?? '',
    country: json['country'] as String? ?? '',
    countryUr: json['countryUr'] as String? ?? '',
    province: json['province'] as String? ?? '',
    provinceUr: json['provinceUr'] as String? ?? '',
    latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
    longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
    timezone: (json['timezone'] as num?)?.toDouble() ?? 5.0,
    elevation: (json['elevation'] as num?)?.toDouble() ?? 0.0,
    source: json['source'] as String? ?? 'Map',
  );
}

class CityDatabase {
  // Transliteration / alias map for Urdu input to English
  static const Map<String, String> urduToEnglishMap = {
    'فروکہ': 'Farooka',
    'سرگودھا': 'Sargodha',
    'لاہور': 'Lahore',
    'کراچی': 'Karachi',
    'اسلام آباد': 'Islamabad',
    'اسلام اباد': 'Islamabad',
    'راولپنڈی': 'Rawalpindi',
    'پنڈی': 'Rawalpindi',
    'فیصل آباد': 'Faisalabad',
    'فیصل اباد': 'Faisalabad',
    'ملتان': 'Multan',
    'پشاور': 'Peshawar',
    'کوئٹہ': 'Quetta',
    'گوجرانوالہ': 'Gujranwala',
    'سیالکوٹ': 'Sialkot',
    'گجرات': 'Gujrat',
    'بہاولپور': 'Bahawalpur',
    'رحیم یار خان': 'Rahim Yar Khan',
    'جھنگ': 'Jhang',
    'چنیوٹ': 'Chiniot',
    'بھکر': 'Bhakkar',
    'میانوالی': 'Mianwali',
    'خوشاب': 'Khushab',
    'جوہرآباد': 'Jauharabad',
    'بھلوال': 'Bhalwal',
    'شاہ پور': 'Shahpur',
    'کوٹ مومن': 'Kot Momin',
    'سلانوالی': 'Sillanwali',
    'ساہیوال': 'Sahiwal',
    'اوکاڑہ': 'Okara',
    'پاکپتن': 'Pakpattan',
    'قصور': 'Kasur',
    'شیخوپورہ': 'Sheikhupura',
    'ننکانہ صاحب': 'Nankana Sahib',
    'حافظ آباد': 'Hafizabad',
    'وزیرآباد': 'Wazirabad',
    'منڈی بہاؤالدین': 'Mandi Bahauddin',
    'ڈیرہ غازی خان': 'Dera Ghazi Khan',
    'ڈی جی خان': 'Dera Ghazi Khan',
    'مظفر گڑھ': 'Muzaffargarh',
    'لیہ': 'Layyah',
    'راجن پور': 'Rajanpur',
    'حیدرآباد': 'Hyderabad',
    'سکھر': 'Sukkur',
    'لاڑکانہ': 'Larkana',
    'نواب شاہ': 'Nawabshah',
    'میرپور خاص': 'Mirpur Khas',
    'ایبٹ آباد': 'Abbottabad',
    'مردان': 'Mardan',
    'سوات': 'Swat',
    'مانسہرہ': 'Mansehra',
    'ڈیرہ اسماعیل خان': 'Dera Ismail Khan',
    'ڈی آئی خان': 'Dera Ismail Khan',
    'کوہاٹ': 'Kohat',
    'بنوں': 'Bannu',
    'مظفرآباد': 'Muzaffarabad',
    'میرپور': 'Mirpur',
    'راولاکوٹ': 'Rawalakot',
    'کوٹلی': 'Kotli',
    'گلگت': 'Gilgit',
    'سکردو': 'Skardu',
    'ہنزہ': 'Hunza',
    'چلاس': 'Chilas',
    'گوادر': 'Gwadar',
    'تربت': 'Turbat',
    'خضدار': 'Khuzdar',
    'سبی': 'Sibi',
    'مکہ': 'Makkah',
    'مکہ مکرمہ': 'Makkah al-Mukarramah',
    'مدینہ': 'Madinah',
    'مدینہ منورہ': 'Madinah al-Munawwarah',
    'ریاض': 'Riyadh',
    'جدہ': 'Jeddah',
    'دمام': 'Dammam',
    'طائف': 'Taif',
    'دبئی': 'Dubai',
    'ابوظہبی': 'Abu Dhabi',
    'شارجہ': 'Sharjah',
    'دوحہ': 'Doha',
    'کویت': 'Kuwait City',
    'منامہ': 'Manama',
    'مسقط': 'Muscat',
    'لندن': 'London',
    'برمنگھم': 'Birmingham',
    'مانچسٹر': 'Manchester',
    'نیویارک': 'New York',
    'شکاگو': 'Chicago',
    'ہیوسٹن': 'Houston',
    'لاس اینجلس': 'Los Angeles',
    'ٹورنٹو': 'Toronto',
    'استنبول': 'Istanbul',
    'انقرہ': 'Ankara',
    'قاہرہ': 'Cairo',
    'القدس': 'Jerusalem',
    'بیت المقدس': 'Jerusalem',
    'عمان': 'Amman',
    'دمشق': 'Damascus',
    'بیروت': 'Beirut',
    'بغداد': 'Baghdad',
    'نجف': 'Najaf',
    'کربلا': 'Karbala',
    'تہران': 'Tehran',
    'مشہد': 'Mashhad',
    'کابل': 'Kabul',
    'دہلی': 'Delhi',
    'نئی دہلی': 'New Delhi',
    'ممبئی': 'Mumbai',
    'کولکتہ': 'Kolkata',
    'ڈھاکہ': 'Dhaka',
    'کولمبو': 'Colombo',
    'بیجنگ': 'Beijing',
    'ٹوکیو': 'Tokyo',
    'پیرس': 'Paris',
    'برلن': 'Berlin',
    'سڈنی': 'Sydney',
    'میلبورن': 'Melbourne',
  };

  // Sole Default Baseline City (As requested: only Farooka is hardcoded)
  static const List<CityModel> defaultCities = [
    CityModel(
      id: 'farooka_pk',
      name: 'Farooka',
      nameUr: 'فروکہ',
      country: 'Pakistan',
      countryUr: 'پاکستان',
      province: 'Punjab',
      provinceUr: 'پنجاب',
      latitude: 31.8878,
      longitude: 72.4125,
      timezone: 5.0,
      elevation: 188,
    ),
  ];

  static List<CityModel> search(String query) {
    if (query.trim().isEmpty) return defaultCities;
    final q = query.toLowerCase().trim();

    // Check transliterated English equivalent
    final transliterated = urduToEnglishMap[query.trim()]?.toLowerCase();

    return defaultCities.where((c) {
      final nameEn = c.name.toLowerCase();
      final nameUr = c.nameUr.toLowerCase();
      final provEn = c.province.toLowerCase();
      final provUr = c.provinceUr.toLowerCase();
      final countryEn = c.country.toLowerCase();
      final countryUr = c.countryUr.toLowerCase();

      return nameEn.contains(q) ||
          nameUr.contains(q) ||
          provEn.contains(q) ||
          provUr.contains(q) ||
          countryEn.contains(q) ||
          countryUr.contains(q) ||
          (transliterated != null && nameEn.contains(transliterated));
    }).toList();
  }
}
