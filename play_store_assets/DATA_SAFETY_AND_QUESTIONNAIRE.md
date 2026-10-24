# Google Play Console - Data Safety & Content Rating Guide
### رہنمائی برائے گوگل پلے کنسول سوالات (Data Safety & Questionnaire)

جب آپ گوگل پلے کنسول (Google Play Console) پر ایپ جمع کروائیں گے، تو درج ذیل فارمز اور سوالنامے آئیں گے۔ ان کے جوابات بالکل اسی طرح منتخب فرمائیں:

---

### ۱. اشتہارات (Ads Questionnaire)
- **سوال:** Does your app contain ads? (کیا آپ کی ایپ میں اشتہارات ہیں؟)
- **جواب:** **No, my app does not contain ads** (منتخب کریں)۔

---

### ۲. ایپ تک رسائی (App Access)
- **سوال:** All or some functionality in my app is restricted?
- **جواب:** **All functionality is available without special access** (تمام فیچرز بغیر کسی لاگ ان یا پابندی کے دستیاب ہیں)۔

---

### ۳. مواد کی درجہ بندی (Content Rating)
- کیٹیگری: **Utility, Productivity, Communication or Other**
- Violence / Blood: **No**
- Sexuality: **No**
- Offensive Language: **No**
- Controlled Substance: **No**
- Miscellaneous: Does the app share the user's current precise physical location with other users? -> **No** (صرف یوزر کے اپنے ڈیوائس پر اوقات اور قبلہ کے لیے ہے)۔
- نتیجہ: ایپ کو **Everyone (3+) / PEGI 3** کلین سرٹیفکیٹ ملے گا۔

---

### ۴. ٹارگٹ سامعین (Target Audience & Content)
- عمر کے گروپ (Target age groups): **13-15, 16-17, 18 and over** (13 سال اور زائد)۔
- Appeal to Children: **No** (ایپ بچوں کے لیے خاص طور پر ڈیزائن نہیں کی گئی، عام افادیت کی ایپ ہے)۔

---

### ۵. ڈیٹا سیفٹی سیکشن (Data Safety Section - انتہائی اہم)
- **Does your app collect or share any of the required user data types?**
  - جواب: **Yes** (کیونکہ لوکیشن استعمال ہوتی ہے)۔
- **Is all of the user data collected by your app encrypted in transit?**
  - جواب: **Yes** (HTTPS کنکشن استعمال ہوتا ہے)۔
- **Do you provide a way for users to request that their data be deleted?**
  - جواب: **Yes** (یوزر ایپ ڈیٹا یا کیش کلیئر کر کے تمام ڈیٹا فوری مٹا سکتا ہے کیونکہ سارا ڈیٹا صرف موبائل پر رہتا ہے)۔

#### لوکیشن کا تفصیلی سوالنامہ (Location Data Details):
1. **Approximate Location (تقریبی لوکیشن):**
   - Collected: **Yes**
   - Shared: **No** (کسی تیسری پارٹی سے شیئر نہیں ہوتا)
   - Processed Ephemerally: **Yes** (صرف حساب لگا کر فوری استعمال ہوتا ہے)
   - Is this data required or optional: **Optional** (یوزر دستی نام بھی لکھ سکتا ہے)
   - Purpose: **App functionality** (اوقاتِ نماز اور سمتِ قبلہ کے حساب کے لیے)
2. **Precise Location (درست GPS لوکیشن):**
   - Collected: **Yes**
   - Shared: **No**
   - Processed Ephemerally: **Yes**
   - Purpose: **App functionality**

---

### ۶. پرائیویسی پالیسی کا لنک (Privacy Policy URL)
- کنسول کے **Policy > App Content > Privacy Policy** میں اپنی پرائیویسی پالیسی کا یو آر ایل درج کریں۔
- آپ ہمارے تیار کردہ `play_store_assets/privacy_policy.html` کو کسی بھی ہوسٹنگ، اپنی ویب سائٹ، یا مفت GitHub Pages پر رکھ کر اس کا لنک دے سکتے ہیں۔
  - مثال: `https://yourusername.github.io/meeqat-privacy/` یا `https://minaret.al-aqsa.org/privacy.html`
