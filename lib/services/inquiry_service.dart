import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../state/app_state.dart';

/// 내 문의 한 건 (서버 응답)
class MyInquiry {
  final int id;
  final String content;
  final String status; // pending | replied
  final String? reply;
  final DateTime? createdAt;

  const MyInquiry({
    required this.id,
    required this.content,
    required this.status,
    this.reply,
    this.createdAt,
  });

  bool get replied => status == 'replied';

  factory MyInquiry.fromJson(Map<String, dynamic> j) => MyInquiry(
        id: j['id'] as int,
        content: j['content'] as String? ?? '',
        status: j['status'] as String? ?? 'pending',
        reply: j['reply'] as String?,
        createdAt: j['created_at'] != null
            ? DateTime.tryParse(j['created_at'].toString())
            : null,
      );
}

/// 문의 전송/조회. 로그인 없이 익명 deviceId 기반 (Minigame 서버 /api/mathforadults).
class InquiryService {
  static const _base = 'https://duo.jiny.shop/api/mathforadults';
  static const _deviceKey = 'mfa_device_id';

  final SharedPreferences _prefs;
  InquiryService(this._prefs);

  String get deviceId {
    var id = _prefs.getString(_deviceKey);
    if (id == null || id.isEmpty) {
      final r = Random.secure();
      final rand =
          List.generate(10, (_) => r.nextInt(36).toRadixString(36)).join();
      id = 'mfa_${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}$rand';
      _prefs.setString(_deviceKey, id);
    }
    return id;
  }

  Future<void> submit(String content, {String? nickname}) async {
    final res = await http
        .post(
          Uri.parse('$_base/inquiries'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'deviceId': deviceId,
            'content': content.trim(),
            if (nickname != null && nickname.trim().isNotEmpty)
              'nickname': nickname.trim(),
          }),
        )
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw Exception('전송 실패 (${res.statusCode})');
    }
  }

  Future<List<MyInquiry>> fetchMine() async {
    final res = await http
        .get(Uri.parse(
            '$_base/inquiries?deviceId=${Uri.encodeQueryComponent(deviceId)}'))
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw Exception('불러오기 실패 (${res.statusCode})');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return (data['inquiries'] as List<dynamic>? ?? [])
        .map((e) => MyInquiry.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

final inquiryServiceProvider = Provider<InquiryService>(
  (ref) => InquiryService(ref.watch(sharedPreferencesProvider)),
);
