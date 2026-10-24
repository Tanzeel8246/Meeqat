# Minaret Modern (فلکیاتی اوقاتِ نماز و سمتِ قبلہ سویٹ)

A complete Full-Stack Islamic Astronomical Suite for **Mobile (Android/iOS)**, **Windows Desktop**, and **Web**, retaining the exact high-precision astronomical algorithms of Dr. S. Kamal Abdali's Minaret software with modern UI/UX.

---

## 📁 پروجیکٹ کا ڈھانچہ (Project Structure)

```
minaret_modern/
├── standalone_web/
│   └── index.html             <-- فوری ڈبل کلک کر کے چلنے والی آف لائن جدید ایپ (کوئی سرور درکار نہیں)
├── backend/                    <-- پی ایچ پی ویب ایڈمن پینل اور REST API
│   ├── src/
│   │   ├── AstronomicalCore.php <-- ڈاکٹر کمال عبدلی کے فلکیاتی حسابی فارمولے
│   │   ├── QiblaCalculator.php  <-- کروی تکونیاتی سمتِ قبلہ (Spherical Trigonometry)
│   │   ├── HijriCalendar.php    <-- ہجری تقویم و چاند کی رویت
│   │   └── CityDatabase.php     <-- دنیا اور پاکستان کے شہروں کا ڈیٹا بیس
│   ├── api/
│   │   ├── prayer-times.php     <-- یومیہ اوقاتِ نماز کی REST API
│   │   ├── calendar.php         <-- ماہانہ و سالانہ دائمی جنتری API
│   │   ├── qibla.php            <-- سمتِ قبلہ و فاصلہ API
│   │   └── cities.php           <-- شہروں کی تلاش کی API
│   └── public/
│       ├── index.php            <-- ماڈرن ویب ڈیش بورڈ مع لائیو گھڑی و کاؤنٹ ڈاؤن
│       ├── display.php          <-- مسجد ٹی وی اسکرین موڈ (Mosque TV Digital Display)
│       ├── monthly.php          <-- پرنٹ ایبل دائمی جنتری (Printable PDF Table)
│       └── gazetteer.php        <-- شہروں کا جغرافیائی مینیجر
└── flutter_app/                <-- فلٹر کراس پلیٹ فارم ایپ (موبائل، ونڈوز اور ویب)
    ├── lib/
    │   ├── core/
    │   │   ├── astronomical_engine.dart <-- خالص Dart فلکیاتی حسابی انجن
    │   │   ├── qibla_calculator.dart
    │   │   ├── hijri_calendar.dart
    │   │   └── city_database.dart
    │   ├── screens/
    │   │   ├── home_screen.dart          <-- ہوم اسکرین، لائیو کاؤنٹ ڈاؤن، کارڈز
    │   │   ├── qibla_screen.dart         <-- متحرک قبلہ کمپاس
    │   │   ├── monthly_screen.dart       <-- ماہانہ ٹیبل (جمعہ ہائی لائٹ)
    │   │   ├── mosque_display_screen.dart<-- مسجد اسکرین موڈ
    │   │   └── gazetteer_screen.dart     <-- شہروں کی تلاش و کسٹم کوآرڈینیٹس
    │   └── main.dart
    └── pubspec.yaml
```

---

## 🚀 فوری چلانے کے طریقے (How to Run)

### ۱. فوری اور بغیر کسی سرور کے (Standalone Web):
* `e:\minaret\minaret_modern\standalone_web\index.html` فائل پر ڈبل کلک کریں۔
* یہ آپ کے کمپیوٹر کے گوگل کروم یا مائیکروسافٹ ایج میں فوری کھل جائے گی اور انٹرنیٹ کے بغیر بھی 100٪ آف لائن کام کرے گی۔

### ۲. پی ایچ پی ویب پینل اور REST API چلانا:
* اپنے ٹرمینل میں `backend/public` فولڈر کو پی ایچ پی پر رن کریں:
  ```bash
  cd e:\minaret\minaret_modern\backend\public
  php -S localhost:8080
  ```
* براؤزر میں کھولیں: `http://localhost:8080`

### ۳. فلٹر موبائل، ونڈوز اور ویب ایپ چلانا:
* `flutter_app` فولڈر میں جا کر:
  ```bash
  cd e:\minaret\minaret_modern\flutter_app
  flutter pub get
  flutter run -d windows   # ونڈوز کے لیے
  flutter run -d chrome    # ویب کے لیے
  flutter run              # اینڈرائیڈ موبائل کے لیے
  ```

---

## 🧮 حسابی خصوصیات (Mathematical Integrity)
* **عرض و طول بلد برائے فروکہ، سرگودھا:** `31.8878° N`, `72.4125° E` (ٹائم زون: GMT+5)
* **فلکیاتی درستگی:** فجر اور عشاء 18° زاویہ، زوال نصف النہار، عصر حنفی مثلِ ثانی ($m = 2$) اور شافعی مثلِ اول ($m = 1$)۔
* **سمتِ قبلہ:** 259° (شمال سے مغرب و جنوب کی سمت) اور مکہ مکرمہ سے فاصلہ تقریباً 3,467 کلومیٹر۔
