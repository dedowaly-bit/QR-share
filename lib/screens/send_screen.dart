import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../services/local_server.dart';
import '../services/uploader.dart';
import '../theme.dart';

class PickedInfo {
  PickedInfo(this.path, this.name, this.size);

  final String path;
  final String name;
  final int size;

  String get sizeText {
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(0)} كيلوبايت';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} ميجابايت';
  }

  File toFile() => File(path);
}

enum ShareMode { online, wifi }
enum OnlineProvider { temp, permanent }
enum Phase { idle, working, ready }

class SendScreen extends StatefulWidget {
  const SendScreen({super.key});

  @override
  State<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends State<SendScreen> {
  PickedInfo? _picked;
  ShareMode _mode = ShareMode.online;
  OnlineProvider _provider = OnlineProvider.temp;
  Phase _phase = Phase.idle;
  double? _progress;
  String? _link;
  String? _error;

  LocalFileServer? _server;
  CancelToken? _cancelToken;

  static const _tempMaxBytes = 90 * 1024 * 1024; // ~100MB حد tmpfiles
  static const _permMaxBytes = 190 * 1024 * 1024; // ~200MB حد catbox

  Future<void> _pickFile() async {
    await _reset();
    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    final files = result?.files;
    if (files == null || files.isEmpty || files.first.path == null) return;
    final file = files.first;
    setState(() => _picked = PickedInfo(file.path!, file.name, file.size));
  }

  Future<void> _create() async {
    final picked = _picked;
    if (picked == null || _phase == Phase.working) return;

    if (_mode == ShareMode.online && _provider == OnlineProvider.temp &&
        picked.size > _tempMaxBytes) {
      _showError('الملف أكبر من 100 ميجا - استخدم الرابط الدائم أو وضع الواي فاي');
      return;
    }
    if (_mode == ShareMode.online && _provider == OnlineProvider.permanent &&
        picked.size > _permMaxBytes) {
      _showError('الرابط الدائم يدعم حتى 200 ميجا - استخدم وضع الواي فاي');
      return;
    }

    setState(() {
      _phase = Phase.working;
      _progress = null;
      _error = null;
      _link = null;
    });

    final token = _cancelToken = CancelToken();

    try {
      String link;
      if (_mode == ShareMode.wifi) {
        link = await _startWifiServer(picked);
      } else if (_provider == OnlineProvider.temp) {
        link = await Uploader.uploadTemp(picked.path, picked.name,
            onProgress: _onProgress, cancelToken: token);
      } else {
        link = await Uploader.uploadPermanent(picked.path, picked.name,
            onProgress: _onProgress, cancelToken: token);
      }
      setState(() {
        _link = link;
        _phase = Phase.ready;
        _progress = null;
      });
    } catch (e) {
      _server?.stop();
      _server = null;
      final cancelled = token.isCancelled;
      setState(() {
        _phase = Phase.idle;
        _error =
            cancelled ? null : e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _onProgress(int sent, int? total) {
    if (!mounted || total == null || total == 0) return;
    setState(() => _progress = sent / total);
  }

  Future<String> _startWifiServer(PickedInfo picked) async {
    _server?.stop();
    final server = LocalFileServer(picked.toFile());
    final link = await server.start();
    _server = server;
    return link;
  }

  Future<void> _reset() async {
    _server?.stop();
    _server = null;
    setState(() {
      _picked = null;
      _link = null;
      _error = null;
      _progress = null;
      _phase = Phase.idle;
    });
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.danger),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildPickCard(),
        if (_picked != null && _phase != Phase.ready) ...[
          const SizedBox(height: 16),
          _buildOptionsCard(),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _create,
            icon: const Icon(Icons.qr_code_2),
            label: const Text('إنشاء كود QR'),
          ),
        ],
        if (_phase == Phase.working) ...[
          const SizedBox(height: 20),
          _buildProgress(),
        ],
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.danger)),
        ],
        if (_phase == Phase.ready && _link != null) ...[
          const SizedBox(height: 20),
          _buildResult(),
        ],
      ],
    );
  }

  Widget _buildPickCard() {
    final picked = _picked;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: _pickFile,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
          child: Column(
            children: [
              Icon(
                picked == null ? Icons.upload_file_rounded : Icons.description,
                size: 56,
                color: AppColors.primaryLight,
              ),
              const SizedBox(height: 12),
              Text(
                picked == null
                    ? 'اضغط لاختيار أي ملف\n(فيديو، صورة، صوت، PDF، APK...)'
                    : picked.name,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: picked == null ? 15 : 17,
                  fontWeight: FontWeight.bold,
                  color: picked == null ? AppColors.textDim : Colors.white,
                ),
              ),
              if (picked != null) ...[
                const SizedBox(height: 6),
                Text(picked.sizeText, style: const TextStyle(color: AppColors.textDim)),
                const SizedBox(height: 8),
                Text('تغيير الملف',
                    style: TextStyle(color: AppColors.primaryLight)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SegmentedButton<ShareMode>(
              segments: const [
                ButtonSegment(
                  value: ShareMode.online,
                  icon: Icon(Icons.public),
                  label: Text('أونلاين'),
                ),
                ButtonSegment(
                  value: ShareMode.wifi,
                  icon: Icon(Icons.wifi),
                  label: Text('واي فاي محلي'),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (s) => setState(() => _mode = s.first),
            ),
            const SizedBox(height: 14),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _mode == ShareMode.online
                  ? Column(
                      key: const ValueKey('online'),
                      children: [
                        RadioListTile<OnlineProvider>(
                          value: OnlineProvider.temp,
                          groupValue: _provider,
                          onChanged: (v) => setState(() => _provider = v!),
                          title: const Text('رابط سريع (مؤقت)'),
                          subtitle: const Text('يشتغل من أي مكان - يصلاح لمدة ساعة'),
                        ),
                        RadioListTile<OnlineProvider>(
                          value: OnlineProvider.permanent,
                          groupValue: _provider,
                          onChanged: (v) => setState(() => _provider = v!),
                          title: const Text('رابط دائم'),
                          subtitle: const Text('مش بيمسح - لحد 200 ميجا'),
                        ),
                      ],
                    )
                  : Container(
                      key: const ValueKey('wifi'),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(children: [
                        const Icon(Icons.info_outline, color: AppColors.accent),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'اللي يمسح الكود لازم يكون على نفس شبكة الواي فاي (أو هوت سبوت موبايلك) - نقل فوري بدون إنترنت',
                            style: TextStyle(color: Colors.grey.shade300, fontSize: 13),
                          ),
                        ),
                      ]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgress() {
    final p = _progress;
    return Column(
      children: [
        p == null
            ? const LinearProgressIndicator(minHeight: 6)
            : LinearProgressIndicator(value: p, minHeight: 6),
        const SizedBox(height: 10),
        Text(
          p == null ? 'جاري التحضير...' : 'جاري الرفع... ${(p * 100).toStringAsFixed(0)}%',
          style: const TextStyle(color: AppColors.textDim),
        ),
        if (_mode == ShareMode.online)
          TextButton(
            onPressed: () {
              _cancelToken.cancel();
              setState(() => _phase = Phase.idle);
            },
            child: const Text('إلغاء'),
          ),
      ],
    );
  }

  Widget _buildResult() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _mode == ShareMode.online ? Icons.public : Icons.wifi,
                  color: AppColors.accent,
                ),
                const SizedBox(width: 8),
                Text(
                  _mode == ShareMode.online
                      ? 'امسح الكود وتحميل يبدأ'
                      : 'نفس الواي فاي؟ امسح وحمل فورًا',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: QrImageView(
                data: _link!,
                version: QrVersions.auto,
                size: 240,
                backgroundColor: Colors.white,
                errorCorrectionLevel: 'H',
              ),
            ),
            const SizedBox(height: 16),
            SelectableText(
              _link!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.textDim),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _copyLink,
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('نسخ'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _shareLink,
                    icon: const Icon(Icons.share, size: 18),
                    label: const Text('مشاركة'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: _reset,
              icon: const Icon(Icons.refresh),
              label: const Text('مشاركة ملف جديد'),
            ),
          ],
        ),
      ),
    );
  }

  void _copyLink() {
    Clipboard.setData(ClipboardData(text: _link!));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم نسخ الرابط ✅'), backgroundColor: AppColors.accent),
    );
  }

  void _shareLink() => Share.share(
        '📁 ${_picked?.name ?? 'ملف'}\n$_link',
        subject: _picked?.name,
      );

  @override
  void dispose() {
    _server?.stop();
    super.dispose();
  }
}
