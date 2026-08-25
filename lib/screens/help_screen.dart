import 'package:flutter/material.dart';

import '../theme.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _step('1', 'اختر ملفك',
            'من تبويب "إرسال" اضغط واختر أي ملف: فيديو، صورة، صوت، PDF، APK... أي حاجة.'),
        _step('2', 'اختار طريقة المشاركة',
            'أونلاين: الملف يترفع ويطلع لينك يشتغل من أي مكان في العالم.\nواي فاي محلي: نقل فوري بين أجهزة على نفس الشبكة بدون إنترنت.'),
        _step('3', 'اعرض الكود',
            'الطرف التاني يمسح كود QR بكاميراه (أو من داخل التطبيق بتبويب "استقبال") والتحميل يبدأ على طول.'),
        const SizedBox(height: 10),
        Card(
          color: AppColors.card,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: const [
                  Icon(Icons.lightbulb, color: AppColors.accent),
                  SizedBox(width: 8),
                  Text('نصايح سريعة',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ]),
                const SizedBox(height: 10),
                _tip('الرابط السريع المؤقت يصلاح حوالي ساعة - مناسب للتحويل الفوري'),
                _tip('الرابط الدائم مش بيمسح لكن الحد الأقصى 200 ميجا'),
                _tip('في وضع الواي فاي خلي موبايلك هو الهوت سبوت لو مفيش راوتر'),
                _tip('الكود بيشتغل بأي كاميرا أو قارئ QR حتى من واتساب'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _step(String num, String title, String body) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: AppColors.primary,
              child: Text(num, style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 6),
                  Text(body, style: TextStyle(color: Colors.grey.shade400, height: 1.5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tip(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(color: AppColors.accent)),
          Expanded(child: Text(text, style: TextStyle(color: Colors.grey.shade300))),
        ],
      ),
    );
  }
}
