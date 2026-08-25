import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme.dart';

class ReceiveScreen extends StatefulWidget {
  const ReceiveScreen({super.key});

  @override
  State<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends State<ReceiveScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _handling = false;

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handling || !mounted) return;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue ?? barcode.url?.toString();
      if (value == null || value.isEmpty) continue;
      _handling = true;
      HapticFeedback.mediumImpact();
      await _showResult(value);
      _handling = false;
      break;
    }
  }

  Future<void> _showResult(String value) async {
    final isUrl = value.startsWith('http://') || value.startsWith('https://');
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                isUrl ? Icons.download_rounded : Icons.qr_code,
                size: 48,
                color: AppColors.accent,
              ),
              const SizedBox(height: 12),
              Text(
                isUrl ? 'تم العثور على رابط تحميل!' : 'محتوى الكود',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SelectableText(
                  value,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade300, fontSize: 13),
                ),
              ),
              const SizedBox(height: 16),
              if (isUrl)
                FilledButton.icon(
                  onPressed: () => _openLink(value),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('فتح وتحميل'),
                ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: value));
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(content: Text('تم النسخ ✅')),
                  );
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('نسخ'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openLink(String value) async {
    Navigator.pop(context);
    final uri = Uri.parse(value);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر فتح الرابط'), backgroundColor: AppColors.danger),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        MobileScanner(controller: _controller, onDetect: _onDetect),
        CustomPaint(painter: _FramePainter(), child: const SizedBox.expand()),
        Positioned.fill(
          child: IgnorePointer(
            ignoring: false,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                margin: const EdgeInsets.all(20),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  'وجّه الكاميرا ناحية كود QR',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 16,
          left: 16,
          child: CircleAvatar(
            backgroundColor: Colors.black.withOpacity(0.5),
            child: IconButton(
              icon: const Icon(Icons.flash_on, color: Colors.white),
              onPressed: () => _controller.toggleTorch(),
            ),
          ),
        ),
        Positioned(
          top: 16,
          right: 16,
          child: CircleAvatar(
            backgroundColor: Colors.black.withOpacity(0.5),
            child: IconButton(
              icon: const Icon(Icons.cameraswitch, color: Colors.white),
              onPressed: () => _controller.switchCamera(),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class _FramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const side = 110.0;
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCenter(
      center: center,
      width: side * 2.2,
      height: side * 2.2,
    );

    final paint = Paint()
      ..color = AppColors.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    // تعتيم باقي الشاشة
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.black.withOpacity(0.35));

    const corner = 34.0;
    final path = Path()
      // أعلى يمين
      ..moveTo(rect.right - corner, rect.top)
      ..lineTo(rect.right - corner / 2.4, rect.top)
      ..arcToPoint(Offset(rect.right, rect.top + corner / 2.4),
          radius: const Radius.circular(corner))
      ..lineTo(rect.right, rect.top + corner)
      // أسفل يمين
      ..moveTo(rect.right, rect.bottom - corner)
      ..lineTo(rect.right, rect.bottom - corner / 2.4)
      ..arcToPoint(Offset(rect.right - corner / 2.4, rect.bottom),
          radius: const Radius.circular(corner))
      ..lineTo(rect.right - corner, rect.bottom)
      // أسفل يسار
      ..moveTo(rect.left + corner, rect.bottom)
      ..lineTo(rect.left + corner / 2.4, rect.bottom)
      ..arcToPoint(Offset(rect.left, rect.bottom - corner / 2.4),
          radius: const Radius.circular(corner))
      ..lineTo(rect.left, rect.bottom - corner)
      // أعلى يسار
      ..moveTo(rect.left, rect.top + corner)
      ..lineTo(rect.left, rect.top + corner / 2.4)
      ..arcToPoint(Offset(rect.left + corner / 2.4, rect.top),
          radius: const Radius.circular(corner))
      ..lineTo(rect.left + corner, rect.top);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
