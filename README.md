# QR Share 📱

تطبيق أندرويد لمشاركة أي ملف (فيديو، صور، صوت، PDF، APK...) عن طريق كود QR.

## الفكرة

1. تختار ملف من جهازك
2. التطبيق يطلعلك كود QR فيه رابط تحميل مباشر
3. أي حد يمسح الكود بكاميراه → الملف ينزل على جهازه على طول

## وضعان للمشاركة

| الوضع | إزاي بيشتغل | امتى تستخدمه |
|---|---|---|
| **أونلاين** | الملف يترفع على سيرفر والـ QR يحمل رابط تحميل يشتغل من أي مكان في العالم | مشاركة مع حد بعيد عنك |
| **واي فاي محلي** | موبايلك يبقى خادم صغير على الشبكة والـ QR يحمل عنوانه | نقل فوري بين أجهزة قريبة (مش محتاج إنترنت) |

خيارات الرفع الأونلاين:
- **رابط سريع (مؤقت):** يصلاح حوالي ساعة - حتى ~100 ميجا
- **رابط دائم:** مش بيمسح - حتى 200 ميجا

التطبيق فيه كمان **ماسح QR مدمج** في تبويب "استقبال".

---

## بناء الـ APK من GitHub (بدون تسطيب أي حاجة على جهازك)

### الطريقة الأسهل: GitHub Desktop

1. اعمل حساب على github.com
2. نزّل GitHub Desktop من desktop.github.com وسطّبه وادخل بحسابك
3. File → Add local repository → اختار مجلد المشروع ده → "Create a repository here"
4. دوس Publish repository (خليه Public عشان تقدر تحمّل الـ APK من الموبايل بدون تسجيل دخول)
5. افتح تبويب Actions في المستودع واستنى البناء يخلص بعلامة ✅
6. حمّل الـ APK من:
   `https://github.com/<اسم-حسابك>/qr-share/releases/latest`
   أو اللينك المباشر:
   `https://github.com/<اسم-حسابك>/qr-share/releases/latest/download/qr-share.apk`

كل مرة تعمل تعديل وتعمل publish تاني، الـ APK بيتحدث تلقائيًا على نفس اللينك.

### الطريقة البديلة: سطر الأوامر

```bash
git init
git add .
git commit -m "QR Share app"
git branch -M main
git remote add origin https://github.com/<اسم-حسابك>/qr-share.git
git push -u origin main
```

2. افتح المستودع على GitHub → تبويب **Actions**
   - أول ما الـ push يوصل هيبدأ build تلقائيًا (ياخد 5-10 دقايق)
3. بعد ما الـ build يخلص بنجاح:
   - ادخل على الـ workflow run → قسم **Artifacts** → نزّل **qr-share-apk**
4. انقل الـ APK لموبايلك وسطّبه (سمح بتثبيت من مصادر غير معروفة)

### نسخة Release عامة (اختياري)

لو عايز تحمّل الـ APK بدون حساب GitHub، اعمل tag واعمله push:

```bash
git tag v1.0.0
git push origin v1.0.0
```

الـ APK هيتحط تلقائيًا في صفحة **Releases** في المستودع.

---

## البناء محليًا (لو سطّبت Flutter بعدين)

```bash
flutter create --org com.qrshareapp --project-name qr_share --platforms android .
cp tools/AndroidManifest.xml android/app/src/main/AndroidManifest.xml
flutter pub get
flutter build apk --release
```

الـ APK النهائي: `build/app/outputs/flutter-apk/app-release.apk`

---

## التقنيات المستخدمة

- **Flutter / Dart**
- `file_picker` — اختيار أي نوع ملف
- `dio` — رفع الملفات مع شريط تقدم حقيقي
- `qr_flutter` — توليد كود QR
- `mobile_scanner` — مسح الأكواد بالكاميرا
- `dart:io HttpServer` — خادم ملفات محلي بيدعم استكمال التحميل (Range) للوضع المحلي
