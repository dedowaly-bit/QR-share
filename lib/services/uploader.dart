import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';

/// رفع الملفات على خدمات استضافة مجانية للحصول على رابط تحميل.
class Uploader {
  Uploader._();

  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(minutes: 10),
      sendTimeout: const Duration(minutes: 10),
    ),
  );

  /// tmpfiles.org : رابط مؤقت صالح لمدة ساعة تقريبًا (حتى ~100 ميجا).
  static Future<String> uploadTemp(
    String filePath,
    String fileName, {
    void Function(int sent, int? total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final form = FormData();
    form.files.add(MapEntry(
      'file',
      await MultipartFile.fromFile(filePath, filename: fileName),
    ));

    final res = await _dio.post<Object>(
      'https://tmpfiles.org/api/v1/upload',
      data: form,
      cancelToken: cancelToken,
      onSendProgress: onProgress,
      options: Options(responseType: ResponseType.plain),
    );

    final body = jsonDecode(res.data.toString()) as Map<String, dynamic>;
    if (body['status'] != 'success') {
      throw Exception('فشل الرفع على الخادم المؤقت');
    }
    final url = (body['data'] as Map<String, dynamic>)['url'] as String;
    // تحويل الرابط إلى رابط تحميل مباشر
    return url.replaceFirst('tmpfiles.org/', 'tmpfiles.org/dl/');
  }

  /// catbox.moe : رابط دائم (حتى ~200 ميجا).
  static Future<String> uploadPermanent(
    String filePath,
    String fileName, {
    void Function(int sent, int? total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final form = FormData.fromMap({
      'reqtype': 'fileupload',
    });
    form.files.add(MapEntry(
      'fileToUpload',
      await MultipartFile.fromFile(filePath, filename: fileName),
    ));

    final res = await _dio.post<String>(
      'https://catbox.moe/user/api.php',
      data: form,
      cancelToken: cancelToken,
      onSendProgress: onProgress,
      options: Options(
        responseType: ResponseType.plain,
        headers: {'User-Agent': 'Mozilla/5.0 (QRShareApp)'},
      ),
    );

    final url = res.data.toString().trim();
    if (!url.startsWith('http')) {
      throw Exception('فشل الرفع على الخادم الدائم');
    }
    return url;
  }

  /// رمز عشوائي قصير يُستخدم في روابط الوضع المحلي.
  static String randomToken([int length = 6]) {
    const chars = 'abcdefghjkmnpqrstuvwxyz23456789';
    final rnd = Random.secure();
    return List.generate(length, (_) => chars[rnd.nextInt(chars.length)]).join();
  }
}
